# Grafana + Keycloak SSO — Production guide

How identity is wired today, what stays for production, and **exactly what to change where** when moving from port-forward (`localhost:3000`) to a real domain (`https://grafana.jatinog.com`).

Related: [Grafana-SSO-Arch.md](./Grafana-SSO-Arch.md) (architecture & deployment flow).  
Official Grafana Keycloak auth: [Configure Keycloak OAuth2](https://grafana.com/docs/grafana/latest/setup-grafana/configure-access/configure-authentication/keycloak/).

---

## 1. Current production posture

Configs in this repo are set for **production HTTPS**:

| Item | Production value |
|------|------------------|
| Grafana public URL | `https://grafana.jatinog.com` |
| Keycloak | `https://keycloak.jatinog.com` |
| OIDC client ID | `grafana-oauth` |
| PKCE | `S256` (Keycloak + Grafana `use_pkce`) |
| Localhost redirects | **Disabled** (`enable_local_oauth_redirects = false`) |
| Direct access grants | **Disabled** |
| Role attribute strict | **Enabled** |

---

## 2. What to change where (cheat sheet)

| What | File | Production setting |
|------|------|--------------------|
| Grafana `root_url` | `kube-prometheus-stack/prometheus-values-template.yaml` → rendered as `prometheus-override-values.rendered.yaml` | `https://grafana.jatinog.com/` |
| Grafana OIDC / PKCE / roles | Same Grafana values files | Keep OIDC URLs on Keycloak; `use_pkce: true`; `role_attribute_strict: true` |
| Keycloak client root / redirects / CORS | `terragrunt/.../keycloak/grafana/terragrunt.hcl` | `grafana_root_url = "https://grafana.jatinog.com"`; local redirects off |
| Keycloak password grant | Same Terragrunt `inputs` | `direct_access_grants_enabled = false` |
| Client secret → AWS | `terragrunt/.../secrets/grafana-auth/terragrunt.hcl` | Publishes `dependency.grafana_keycloak.outputs.client_secret` |
| Secret → cluster | `external-secrets/externalsecret-grafana-auth.yaml` | Key `GRAFANA_OAUTH_CLIENT_SECRET` → env `GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET` |

Do **not** hardcode the client secret in Helm values.

---

## 3. File-by-file detail

### 3.1 Keycloak client (Terragrunt)

**Path:** `terragrunt/infrastructure-live/accounts/mlops/us-east-2/keycloak/grafana/terragrunt.hcl`

| Input / local | Purpose | Prod |
|---------------|---------|------|
| `grafana_root_url` | Keycloak `root_url` / `base_url` / `admin_url` | `https://grafana.jatinog.com` |
| `enable_local_oauth_redirects` | Adds localhost / 127.0.0.1 redirect URIs | `false` |
| `valid_redirect_uris` | Must match Grafana callback exactly | `…/login/generic_oauth` only (prod URL) |
| `web_origins` | CORS for browser | Prod URL only (no `+`, no localhost) |
| `pkce_code_challenge_method` | Authorization code + PKCE | `S256` |
| `direct_access_grants_enabled` | Resource-owner password grant | `false` |
| `default_scopes` | Keycloak **client** scopes | `email`, `profile`, `roles` — **never** `openid` as a client scope |
| `oidc_mappers.client_roles` | Flat `roles` claim for Grafana | Keep |
| `roles` / `groups` | RBAC source of truth | `admin` / `editor` / `viewer` + group maps |

Apply:

```bash
cd terragrunt/infrastructure-live/accounts/mlops/us-east-2/keycloak/grafana
terragrunt apply
```

### 3.2 Grafana Helm values

**Template (source of truth for rendering):**  
`kube-prometheus-stack/prometheus-values-template.yaml`

**Rendered (what Helm installs today):**  
`kube-prometheus-stack/prometheus-override-values.rendered.yaml`

| Key | Purpose | Prod |
|-----|---------|------|
| `grafana.ini.server.root_url` | Builds `redirect_uri` | `https://grafana.jatinog.com/` |
| `auth.generic_oauth.*_url` | Auth/token/userinfo/logout | `https://keycloak.jatinog.com/realms/grafana/protocol/openid-connect/…` |
| `use_pkce` | Must match Keycloak S256 | `true` |
| `use_refresh_token` | Needs `offline_access` scope | `true` |
| `role_attribute_strict` | Deny login if role cannot be derived | `true` |
| `role_attribute_path` | Maps Keycloak roles → Grafana | See values file (client + flat `roles`) |
| `envValueFrom.GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET` | Client secret | From `grafana-auth-secrets` |

After editing the template, re-render (if you use the render script) and upgrade:

```bash
# if using render pipeline:
make render-helm-values

aws eks update-kubeconfig --name <cluster> --region us-east-2
make install-kube-prometheus-stack
kubectl rollout restart deploy/kube-prometheus-stack-grafana -n monitoring
```

### 3.3 Secret pipeline

1. `terragrunt apply` in `…/secrets/grafana-auth` — writes AWS SM `observability-hub/grafana-auth`.
2. `make eso-apply` (or ExternalSecret refresh) — syncs into K8s `grafana-auth-secrets`.
3. Grafana reads `GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET`.

If the Keycloak client secret is rotated, re-apply **both** Keycloak (if regenerated) and `secrets/grafana-auth`, then restart Grafana.

---

## 4. Production checklist (apply in order)

- [ ] DNS + TLS ingress for `https://grafana.jatinog.com` (and Keycloak already on HTTPS).
- [ ] `grafana_root_url` / Grafana `root_url` = `https://grafana.jatinog.com/` (trailing slash on Grafana `root_url` is fine).
- [ ] `enable_local_oauth_redirects = false` (no localhost in Keycloak redirect URIs).
- [ ] `direct_access_grants_enabled = false`.
- [ ] `use_pkce: true` on Grafana; Keycloak `pkce_code_challenge_method = "S256"`.
- [ ] `role_attribute_strict: true` after confirming role mapping for a test user.
- [ ] Users/groups in Keycloak: `grafana-admins` / `grafana-editors` / `grafana-viewers` (or direct client roles).
- [ ] `terragrunt apply` Keycloak Grafana client → `terragrunt apply` secrets → ESO sync → Helm upgrade / rollout.
- [ ] Browser test: open **only** `https://grafana.jatinog.com` → Sign in with Keycloak → land back on Grafana with expected role.
- [ ] Logout clears Keycloak session (optional: verify `signout_redirect_url`).

---

## 5. Temporary local port-forward (dev only)

SSO via `make pf-grafana` needs matching `root_url` + Keycloak redirect URIs.

1. In `keycloak/grafana/terragrunt.hcl` set:

   ```hcl
   enable_local_oauth_redirects = true
   ```

2. `terragrunt apply` that stack.

3. Temporarily set Grafana `server.root_url` to `http://localhost:3000/` in the override values, upgrade/restart Grafana.

4. Use `http://localhost:3000` (not `127.0.0.1` unless that URI is also allowed).

5. **Revert** `enable_local_oauth_redirects = false`, restore prod `root_url`, re-apply / upgrade before calling the environment production-ready.

---

## 6. Role mapping reference

| Keycloak client role | Grafana result (current JMESPath) |
|----------------------|-----------------------------------|
| `admin` | `GrafanaAdmin` |
| `editor` | `Editor` |
| else (when strict=false) / viewer | `Viewer` |

With `role_attribute_strict: true`, login fails if the path does not yield a valid Grafana role. Ensure the user has `admin`, `editor`, or `viewer` (via group or direct assignment). The `client_roles` mapper also emits a flat `roles` claim.

---

## 7. Common failures

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `Invalid parameter: redirect_uri` | Callback URL ≠ Keycloak Valid Redirect URIs | Align `root_url` and `valid_redirect_uris` (scheme/host/port/path) |
| `Login provider denied login request` | Bad secret, PKCE mismatch, or strict role mapping | Check secret sync; `use_pkce`; user roles; Grafana logs |
| `scope openid does not exist` (Terraform) | `openid` in Keycloak `default_scopes` | Remove it; keep `openid` only in Grafana `scopes` string |
| Helm → `localhost:8080` | No kubeconfig | `aws eks update-kubeconfig …` |

Logs:

```bash
kubectl logs -n monitoring deploy/kube-prometheus-stack-grafana --tail=100 | grep -iE 'oauth|oidc|login|denied|pkce|token'
```

---

## 8. Rollback

1. Set `auth.generic_oauth.enabled: false` (or remove override) and `make install-kube-prometheus-stack`.
2. Optional: destroy `secrets/grafana-auth` and/or `keycloak/grafana` Terragrunt stacks.
