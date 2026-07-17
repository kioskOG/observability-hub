# Keycloak Client Module

Generic Terraform module for provisioning Keycloak clients over **SAML 2.0** or **OpenID Connect**. Application-specific behavior (Wazuh, Grafana, ArgoCD, …) belongs in Terragrunt inputs — nothing app-specific is hardcoded in the module.

See [MIGRATION.md](./MIGRATION.md) if you are moving from `keycloak-saml-client`.

---

## Architecture

```
main.tf              Realm create / lookup
saml.tf              keycloak_saml_client (+ default scopes)
oidc.tf              keycloak_openid_client (+ default/optional scopes)
mappers_saml.tf      Built-in SAML property + role-list mappers
mappers_saml_extra.tf Extensible SAML mappers (var.saml_mappers)
mappers_oidc.tf      Extensible OIDC mappers (var.oidc_mappers)
roles.tf / groups.tf / users.tf
certificates.tf      SAML signing cert generation
locals.tf            Protocol flags, client UUID, centralized endpoints
moved.tf             State migrations for SAML count/renames
outputs.tf           Structured client / endpoints (+ flat SAML aliases)
```

`client_protocol` selects the active client path (`saml` default, or `openid-connect`). Shared resources (roles, groups, users, realm options) use `local.client_uuid`.

---

## Quick start

### SAML (Wazuh — default)

```hcl
module "wazuh" {
  source = "../keycloak-client"

  keycloak_base_url   = "https://keycloak.example.com"
  realm_name          = "Wazuh"
  create_realm        = true
  client_id           = "wazuh-saml"
  valid_redirect_uris = ["https://wazuh.example.com/*"]
  # client_protocol defaults to "saml"
  use_realm_roles     = true
  roles               = ["wazuh-admins", "wazuh-readonly"]
  # ...
}
```

### OIDC (Grafana — Keycloak-centric inputs)

```hcl
module "grafana" {
  source = "../keycloak-client"

  client_protocol              = "openid-connect"
  client_id                    = "grafana-oauth"
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  direct_access_grants_enabled = true
  pkce_code_challenge_method   = "S256"
  root_url                     = "https://grafana.example.com"
  valid_redirect_uris          = ["https://grafana.example.com/login/generic_oauth"]
  web_origins                  = ["https://grafana.example.com"]
  default_scopes               = ["email", "profile", "roles"]
  optional_scopes              = ["offline_access"]
  roles                        = ["admin", "editor", "viewer"]
  oidc_mappers = {
    groups = {
      mapper_type         = "group_membership"
      claim_name          = "groups"
      add_to_id_token     = true
      add_to_access_token = false
      add_to_userinfo     = true
    }
  }
}
```

Examples: `examples/wazuh`, `examples/grafana`, `examples/argocd`.

---

## Endpoints (centralized)

Built once in `locals` from `keycloak_base_url` + realm:

| Protocol | Keys on `endpoints` / `oidc` / `saml` |
|----------|----------------------------------------|
| OIDC | `issuer`, `authorization_endpoint`, `token_endpoint`, `userinfo_endpoint`, `end_session_endpoint`, `jwks_uri`, `openid_configuration_url` |
| SAML | `idp_entity_id`, `idp_metadata_url`, `sp_entity_id` |

```hcl
output "auth_url" { value = module.x.endpoints.authorization_endpoint }
```

---

## Protocol mappers

### Typed shortcuts

**SAML** (`saml_mappers`): `user_attribute`, `user_property`, `group`, `role`, `hardcoded_attribute`

**OIDC** (`oidc_mappers`): `user_attribute`, `user_property`, `group_membership`, `audience`, `hardcoded_claim`, `realm_role`, `client_role`

### Fully extensible

Set `protocol_mapper` (Keycloak provider id) + `config` map. Typed fields are ignored when `protocol_mapper` is set.

Deprecated: `advanced_saml_mappers` (merged into `saml_mappers`).

---

## Outputs

| Output | Description |
|--------|-------------|
| `client` | `{ protocol, client_id, client_uuid, name, realm }` |
| `client_secret` | OIDC secret (sensitive); `null` for SAML/public |
| `endpoints` | Active protocol endpoint bundle |
| `oidc` / `saml` | Protocol-specific bundle or `null` |
| `realm_name`, `client_roles`, `groups`, `users` | Inventory |
| `signing_certificate` | SAML PEM (sensitive); `null` for OIDC |
| `idp_metadata_url`, `idp_entity_id`, `sp_entity_id` | Deprecated flat SAML aliases |

---

## Notable variables

| Variable | Default | Notes |
|----------|---------|-------|
| `client_protocol` | `"saml"` | `saml` \| `openid-connect` |
| `access_type` | `CONFIDENTIAL` | OIDC |
| `pkce_code_challenge_method` | `S256` | OIDC; `""` disables |
| `default_scopes` / `optional_scopes` | see variables.tf | OIDC |
| `saml_mappers` / `oidc_mappers` | `{}` | Extensible |
| `roles_mapper_name` | `wazuhRoleKey` | Keep for Wazuh zero-drift |
| `advanced_saml_mappers` | `{}` | Deprecated |

Full list with types and validations: `variables.tf`.

---

## Realm ownership

- `create_realm = true` — module owns realm (SMTP, password policy, MFA OTP policy, etc.)
- `create_realm = false` — looks up existing realm; skips realm-wide writes

---

## Prerequisites

- Terraform `>= 1.7.0`, Terragrunt `>= 0.55.0`
- Keycloak `20.x`–`26.x`
- Provider `keycloak/keycloak` `>= 5.8.0`

Local testing: [TESTING.md](./TESTING.md).
