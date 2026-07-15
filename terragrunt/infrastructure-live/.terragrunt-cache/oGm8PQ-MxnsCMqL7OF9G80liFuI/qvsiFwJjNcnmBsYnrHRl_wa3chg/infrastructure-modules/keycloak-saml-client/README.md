# Keycloak SAML Client Platform Module

This Terraform module provisions Keycloak resources to integrate SAML 2.0 Service Providers (applications) with Keycloak as an Identity Provider (IdP). It dynamically configures SAML clients, client-level and realm-level roles, groups, group-to-role mappings, and standard/custom SAML protocol mappers.

It also supports optional enterprise features such as External Identity Providers (OIDC/SAML), LDAP user federation, MFA policies, password policies, SMTP configuration, and secure secret retrieval via AWS Secrets Manager.

---

## 1. Overview

The `keycloak-saml-client` module acts as a cloud-agnostic, reusable platform component to onboard any SAML-compliant application (such as Wazuh, Grafana, ArgoCD, Jenkins, and Backstage) into Keycloak without modifying the module's core code.

### Supported Use Cases
* **SAML Client Provisioning**: Creates and configures SAML SPs in Keycloak.
* **Role-Based Access Control (RBAC)**: Maps Keycloak users and groups to client or realm-level roles.
* **Enterprise User Sync**: Authenticates users against external directories (Active Directory/LDAP) or OIDC/SAML federated identity providers (Google Workspace, Azure AD, GitHub OIDC).
* **Outgoing Email Management**: Configures SMTP connections for email verification and password resets.
* **Security Hardening**: Enforces MFA requirements and password policies at the realm level.

---

## 2. Architecture

The module operates as a generic building block in a secure, multi-tier identity architecture:

```
                  ┌────────────────────────┐
                  │  AWS Secrets Manager  │
                  └───────────┬────────────┘
                              │
                              ▼ (Sensitive Inputs)
                  ┌────────────────────────┐
                  │       Terragrunt       │
                  └───────────┬────────────┘
                              │
                              ▼ (Generic Variables)
                  ┌────────────────────────┐
                  │    Terraform Module    │
                  └───────────┬────────────┘
                              │
                              ▼ (API Calls)
                  ┌────────────────────────┐
                  │      Keycloak IdP      │
                  └───────────┬────────────┘
                              │
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                 ▼
     ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
     │    Wazuh    │   │   Grafana   │   │   ArgoCD    │
     └─────────────┘   └─────────────┘   └─────────────┘
```

### Realm Ownership Boundaries
The module supports two modes of operation:
1. **Dedicated Realm Mode (`create_realm = true`)**: The module owns and configures the realm itself. In this mode, realm-wide settings like SMTP, Password Policies, and OTP Policies are fully managed by the module.
2. **Shared Realm Mode (`create_realm = false`)**: The module performs a data lookup on an existing realm. Realm-wide configurations are skipped entirely, ensuring the module does not overwrite settings managed by other platform tools.

---

## 3. Repository Structure

```
├── main.tf                 # Realm creation/lookup and SAML client resource definition
├── variables.tf            # Standard inputs with types, defaults, and validation rules
├── locals.tf               # Processes inputs and formats password policy strings
├── providers.tf            # Declares required provider inheritance
├── versions.tf             # Pinning for Terraform (>= 1.7.0) and providers
├── outputs.tf              # Exposes integration parameters (descriptor URLs, certs)
│
├── roles.tf                # Provisions client or realm-scoped roles
├── groups.tf               # Provisions groups and group-to-role mappings
├── certificates.tf         # Manages self-signed certificate generation
├── mappers.tf              # Provisions standard SAML protocol mappers
│
├── idp.tf                  # [Optional] External identity providers (Google, Azure AD, etc.)
├── user_federation.tf      # [Optional] LDAP/Active Directory synchronization
├── mfa.tf                  # [Optional] Default MFA required actions (TOTP, WebAuthn)
├── advanced_mappers.tf     # [Optional] Extensible custom SAML attribute mappers
│
├── README.md               # Main usage and configuration reference
└── TESTING.md              # Local testing setups, test cases, and troubleshooting
```

---

## 4. Prerequisites

* **Terraform**: `>= 1.7.0`
* **Terragrunt**: `>= 0.55.0`
* **Keycloak**: `20.x` to `26.x`
* **AWS CLI**: Required if pulling secrets dynamically from AWS Secrets Manager
* **Docker / Docker Compose**: Required for running the local testing environment

---

## 5. Provider Configuration

The module uses the official `keycloak/keycloak` provider. The provider credentials must be supplied via the calling module or environment variables:

```hcl
# providers.tf
provider "keycloak" {
  client_id     = "admin-cli"
  username      = var.keycloak_username
  password      = var.keycloak_password
  url           = var.keycloak_base_url
  initial_login = false
}
```

Ensure the administrative service account used by Terraform has `realm-admin` privileges in the target Keycloak realm.

---

## 6. Core Usage Examples

### Wazuh SAML Integration
Add this configuration to your `terragrunt.hcl` inputs to integrate Wazuh Dashboard:

```hcl
inputs = {
  keycloak_base_url  = "https://keycloak.company.com"
  realm_name         = "Wazuh-Realm"
  create_realm       = true
  
  client_id                  = "wazuh-saml"
  client_name                = "Wazuh SSO Dashboard"
  valid_redirect_uris        = ["https://wazuh.company.com/*"]
  idp_initiated_sso_url_name = "wazuh-dashboard"
  name_id_format             = "username"
  force_name_id_format       = false
  use_realm_roles            = true

  roles = [
    "wazuh-admins",
    "wazuh-readonly"
  ]

  groups = {
    "Wazuh-admins" = {
      roles = ["wazuh-admins"]
    }
    "Wazuh-viewers" = {
      roles = ["wazuh-readonly"]
    }
  }

  groups_attribute_name = "Roles"
  roles_attribute_name  = "Roles"
}
```

---

## 7. Enterprise Feature Examples

### External Identity Providers (IdPs)
To federate Keycloak authentication to Google Workspace OIDC:

```hcl
external_identity_providers = {
  google = {
    enabled           = true
    type              = "oidc"
    client_id         = "your-google-client-id.apps.googleusercontent.com"
    client_secret     = "your-google-client-secret"
    authorization_url = "https://accounts.google.com/o/oauth2/auth"
    token_url         = "https://oauth2.googleapis.com/token"
    user_info_url     = "https://openidconnect.googleapis.com/v1/userinfo"
  }
}
```

### LDAP / Active Directory Integration
To synchronize users and group memberships from Active Directory:

```hcl
ldap_federation = {
  enabled            = true
  connection_url     = "ldap://ldap.company.com:389"
  users_dn           = "OU=Users,DC=company,DC=com"
  bind_dn            = "CN=Keycloak-Svc,OU=ServiceAccounts,DC=company,DC=com"
  bind_credential    = "bind-password"
  vendor             = "ad"
  sync_registrations = false
  edit_mode          = "READ_ONLY"
}
```

### Multi-Factor Authentication (MFA)
To enforce Time-Based One-Time Passwords (TOTP) for users:

```hcl
mfa = {
  enabled      = true
  methods      = ["totp"]
  required_for = ["all"]
}
```

### Password Policies & SMTP Configurations
Add these configurations when `create_realm = true` to secure and manage notifications:

```hcl
password_policy = {
  length               = 14
  digits               = 1
  special_chars        = 1
  upper_case           = 1
  lower_case           = 1
  password_history     = 5
  not_username         = true
  force_expired_change = true
}

smtp = {
  host      = "smtp.sendgrid.net"
  port      = "587"
  from      = "security@company.com"
  from_name = "Company Auth Portal"
  starttls  = true
  username  = "apikey"
}
# smtp_password is passed separately as a sensitive variable
```

### Advanced SAML Protocol Mappers
Map custom fields like user departments or cost centers into SAML assertions:

```hcl
advanced_saml_mappers = {
  department = {
    mapper_type    = "user_attribute"
    user_attribute = "department"
    saml_attribute = "department"
  }
  cost_center = {
    mapper_type    = "user_attribute"
    user_attribute = "costCenter"
    saml_attribute = "costCenter"
  }
  static_label = {
    mapper_type     = "hardcoded_attribute"
    attribute_value = "prod-env"
    saml_attribute  = "environment"
  }
}
```

---

## 8. AWS Secrets Manager Integration

Sensitive parameters must never be committed to repository files or hardcoded in Terragrunt configuration. The module supports a **native dynamic mapping pattern** using AWS Secrets Manager.

Only secret metadata (Secret Name/ARN and the corresponding JSON key) is defined in Terragrunt inputs under `secret_mappings`. The module then retrieves the secret payloads at runtime via Terraform's `aws_secretsmanager_secret_version` data source.

### Example Configuration

Add this mapping to your `terragrunt.hcl` inputs:

```hcl
inputs = {
  keycloak_base_url   = "https://keycloak.company.com"
  keycloak_username   = "admin"

  # Dynamic mapping of module inputs to AWS Secrets Manager
  secret_mappings = {
    keycloak_password = {
      secret_arn = "platform/keycloak"
      secret_key = "keycloak_password"
    }
    smtp_password = {
      secret_arn = "platform/keycloak"
      secret_key = "smtp_password"
    }
    smtp_host = {
      secret_arn = "platform/keycloak"
      secret_key = "host"
    }
    smtp_port = {
      secret_arn = "platform/keycloak"
      secret_key = "port"
    }
    smtp_from = {
      secret_arn = "platform/keycloak"
      secret_key = "from"
    }
    smtp_username = {
      secret_arn = "platform/keycloak"
      secret_key = "username"
    }
  }
}
```

This keeps your configurations entirely free of secrets, while preventing any credentials from leaking to terminal tracebacks during deployment runs.

---

## 9. Input Variables

| Name | Type | Description | Default | Required |
| :--- | :--- | :--- | :--- | :--- |
| `keycloak_base_url` | `string` | Base URL of Keycloak server | n/a | **Yes** |
| `keycloak_username` | `string` | Administrator username | `"admin"` | No |
| `keycloak_password` | `string` | Administrator password (sensitive) | `null` | No (Required if not resolved via `secret_mappings`) |
| `create_realm` | `bool` | Toggle realm creation | `false` | No |
| `realm_name` | `string` | Target realm name | `"master"` | No |
| `client_id` | `string` | Unique SAML Client ID | n/a | **Yes** |
| `client_name` | `string` | Display name of the client | `null` | No |
| `valid_redirect_uris` | `list(string)` | Valid redirect destinations | n/a | **Yes** |
| `idp_initiated_sso_url_name` | `string` | Name of IdP-initiated SSO URL | `""` | No |
| `master_saml_processing_url` | `string` | ACS Endpoint URL | `""` | No |
| `certificate_strategy` | `string` | Certificate strategy (`existing`, `generate`, `vault`) | `"generate"` | No |
| `use_realm_roles` | `bool` | Create realm-level roles instead of client-level roles | `false` | No |
| `roles` | `list(string)` | List of roles to create | `[]` | No |
| `groups` | `map(object)` | Map of groups to roles mappings | `{}` | No |
| `users` | `map(object)` | Map of users to provision in the realm | `{}` | No |
| `external_identity_providers` | `map(object)` | Map of external identity providers | `{}` | No |
| `ldap_federation` | `object` | LDAP user federation configuration | `{enabled = false}` | No |
| `mfa` | `object` | MFA configuration | `{enabled = false}` | No |
| `password_policy` | `object` | Realm password policy configuration | `null` | No |
| `smtp` | `object` | SMTP server configurations | `null` | No |
| `smtp_password` | `string` | SMTP password (sensitive) | `null` | No (Required if not resolved via `secret_mappings`) |
| `secret_mappings` | `map(object)` | Map of input keys to AWS Secrets Manager secret ARNs and JSON keys | `{}` | No |
| `advanced_saml_mappers` | `map(object)` | Custom SAML protocol mappers | `{}` | No |

---

## 10. Outputs

* `idp_metadata_url`: The XML Metadata URL of the Keycloak Identity Provider (IdP).
* `idp_entity_id`: The Entity ID of the Keycloak Identity Provider (IdP).
* `sp_entity_id`: The Entity ID of the Service Provider (SP), which is the client ID in Keycloak.
* `realm_name`: Resolved Realm name.
* `signing_certificate`: Current SAML signing certificate (PEM format, sensitive).
* `client_roles`: List of created client/realm roles.
* `groups`: List of created realm groups.
* `users`: List of created realm users.

---

## 11. Security Best Practices

1. **State Protection**: Mark state backend buckets as private, configure encryption at rest, and protect state locks.
2. **Read-Only LDAP Mappings**: Configure `edit_mode = "READ_ONLY"` for LDAP user federation to prevent Keycloak from modifying Active Directory records.
3. **Redact secrets in logs**: Always use the `sensitive = true` modifier on input variables.

---

## 12. Backward Compatibility Guarantees

* **Zero modifications**: Existing deployments using old inputs require no changes.
* **No Resource Drift**: Running `terragrunt plan` on pre-existing environments produces **no changes**. All new modules/features are protected by feature flags defaulting to `false` or `null`.

---

## 13. Future Roadmap

* **HashiCorp Vault Integration**: Automate certificate retrieval and SMTP secrets lookup directly via Vault.
* **Passkeys Support**: Native WebAuthn passkey policy configuration.
* **CI/CD Integration**: Automatic unit testing with Local Keycloak instances in GitHub Actions.
