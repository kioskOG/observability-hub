# Secrets

All credentials live in **AWS Secrets Manager** under the prefix `observability-hub/`, which `ESO_SECRET_PREFIX` can change. The **External Secrets Operator** syncs them into Kubernetes. Nothing secret is committed to git or written to disk.

> **Rotate any password copied from an earlier version of this page.** It used to contain example passwords and htpasswd hashes. Anyone who seeded Secrets Manager from those examples should run `make eso-seed` (below) to replace them.

## Creating and rotating

```bash
make eso-seed ENVIRONMENT=<prod|stage|dev>   # create or rotate every gateway credential
make eso-apply                               # sync to Kubernetes now (ESO also refreshes hourly)
```

`external-secrets/seed-aws-secrets.sh`:
- generates a random password for every gateway user;
- writes the htpasswd files and the client credentials listed below;
- gives the collectors (Alloy, Prometheus, Tempo) the writer users for `ENVIRONMENT`;
- prints the Alloy and Mimir writer passwords once.

Every run rotates **all** passwords, the Grafana admin included. Afterwards, restart the clients so they pick up the new values, and run `make grafana-admin-reset`; the steps are in the README under [Rotate credentials](../README.md#rotate-credentials).

## Gateway users

The Loki and Mimir gateways map each user to a tenant (environment). See the README section [Multi-tenancy](../README.md#multi-tenancy-loki-and-mimir).

| User | Gateway | Tenant |
|------|---------|--------|
| `loki-writer-prod` / `-stage` / `-dev` | Loki | `prod` / `stage` / `dev` |
| `loki-canary` | Loki | `canary` |
| `grafana-reader` | Loki | env tenants (single or `prod\|stage\|dev`) |
| `mimir-writer-prod` / `-stage` / `-dev` | Mimir | `prod` / `stage` / `dev` |
| `loki-ruler` | Mimir | one env tenant (the rule's tenant) |
| `grafana-reader` | Mimir | env tenants, `prod\|stage\|dev`, or `anonymous` |

`grafana-reader` has a **different password** on each gateway.

## Secrets Manager entries

| Key (`observability-hub/…`) | JSON shape | Synced to (namespace / Secret / keys) | Used by |
|-----------------------------|------------|---------------------------------------|---------|
| `loki-basic-auth` | `{"htpasswd": "<one line per Loki user>"}` | `loki` / `loki-basic-auth` / `.htpasswd` | Loki gateway |
| `mimir-basic-auth` | `{"htpasswd": "<one line per Mimir user>"}` | `mimir` / `mimir-basic-auth` / `.htpasswd` | mimir-nginx |
| `loki-canary` | `{"username","password"}` | `loki` / `canary-basic-auth` | Loki canary |
| `alloy-remote-credentials` | `{"loki_gateway_username","loki_gateway_password","mimir_remote_write_username","mimir_remote_write_password"}` | `alloy-logs` / `alloy-remote-credentials` | Alloy DaemonSet + events (`loki-writer-<env>`, `mimir-writer-<env>`) |
| `mimir-remote-write` | `{"username","password"}` | `monitoring` / `mimir-remote-write-credentials`; `tempo` / `tempo-mimir-remote-write` | Prometheus, Tempo metrics-generator (`mimir-writer-<env>`) |
| `mimir-loki-ruler` | `{"username","password"}` | `loki` / `loki-ruler-mimir-remote-write` | Loki ruler → Mimir (`loki-ruler`) |
| `loki-grafana-reader` | `{"username","password"}` | `monitoring` / `grafana-auth-secrets` / `LOKI_PASSWORD` | Grafana Loki datasources |
| `mimir-grafana-reader` | `{"username","password"}` | `monitoring` / `grafana-auth-secrets` / `MIMIR_PASSWORD` | Grafana Mimir datasources |
| `grafana-admin` | `{"username":"admin","password"}` | `monitoring` / `grafana-admin-credentials` / `admin-user`, `admin-password` | Grafana local admin (break-glass login next to SSO). Grafana applies it only when its DB is created: run `make grafana-admin-reset` after seeding or rotating |
| `grafana-auth` | `{"GRAFANA_OAUTH_CLIENT_SECRET"}` | `monitoring` / `grafana-auth-secrets` / `GRAFANA_OAUTH_CLIENT_SECRET` | Grafana SSO (written by Terragrunt `secrets/grafana-auth`, not by `eso-seed`) |
| `loki-writer-<env>`, `mimir-writer-<env>` | `{"username","password"}` | not synced | Credentials for each environment's collectors, for clusters shipping to a shared hub |

The ExternalSecret manifests are in `external-secrets/`. The ClusterSecretStore `aws-secrets-manager` authenticates with the ESO IRSA role from `terragrunt/.../global/iam/role`.

## Seeding by hand (without the script)

If you create entries manually, for example in the AWS console as "Other type of secret" → Plaintext:
- Build each htpasswd line with `htpasswd -nb <user> <password>` (apr1). Join the lines with `\n` inside the JSON string.
- Use the exact usernames from the table above: the gateways map **usernames** to tenants, so any other name is rejected.
- Keep `alloy-remote-credentials` and `mimir-remote-write` on the writer users of the cluster's own environment.

## Checking

```bash
make eso-check-store                          # every ExternalSecret should be SecretSynced
kubectl -n loki get secret loki-basic-auth -o jsonpath='{.data.\.htpasswd}' | base64 -d | cut -d: -f1   # usernames only
```
