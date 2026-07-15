# Testing Guide: keycloak-saml-client Module

This guide details the procedures to locally test, verify, troubleshoot, and validate the `keycloak-saml-client` module and its enterprise extensions.

---

## 1. Local Development Setup

To test the module locally, run a local Keycloak instance backed by PostgreSQL using the following `docker-compose.yml`.

### Docker Compose Configuration
Save this file as `docker-compose.yml` in your testing directory:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

  keycloak:
    image: quay.io/keycloak/keycloak:24.0.2
    command: start-dev
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: password
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: password
    ports:
      - "8080:8080"
    depends_on:
      - postgres

volumes:
  pgdata:
```

Start the local stack:
```bash
docker compose up -d
```

Keycloak will be accessible at [http://localhost:8080](http://localhost:8080) with credentials `admin` / `password`.

---

## 2. Testing Flow

### Step 1: Initialize Terraform
Navigate to the directory of the example configuration (e.g. `examples/wazuh`) and initialize:
```bash
terraform init
```

### Step 2: Validate configuration
Run validation to check for syntax errors or invalid declarations:
```bash
terraform validate
```

### Step 3: Run Plan
Verify that resources would be created as expected:
```bash
terraform plan
```

### Step 4: Apply Changes
Provision the resources on your local Keycloak instance:
```bash
terraform apply -auto-approve
```

---

## 3. Backward Compatibility Verification

The module has a strict contract of zero impact on existing deployments.

### Scenario: Existing Wazuh Deployment
To confirm compatibility:
1. Navigate to the existing live terragrunt configuration:
   ```bash
   cd live/prod/keycloak/wazuh
   ```
2. Run the plan command:
   ```bash
   terragrunt plan
   ```
3. **Success Criteria**: The output must display:
   ```text
   No changes. Your infrastructure matches the configuration.
   ```
If any changes to existing resources are shown (except explicitly enabled new feature inputs), the changes violate backward compatibility and must be reverted.

---

## 4. Feature Testing Scenarios

Use these scenarios to validate each individual enterprise extension:

### Scenario A: SMTP Configuration
* **Input**:
  ```hcl
  create_realm = true
  smtp = {
    host = "smtp.mailtrap.io"
    port = "2525"
    from = "no-reply@company.com"
  }
  smtp_password = "mailtrap-secret"
  ```
* **Expected Output**: `keycloak_realm.this` configuration block will show 1 SMTP server block added, with username/password nested inside the auth block.
* **Verification**: Log into the Keycloak Admin Console, go to Realm Settings -> Email, and verify the settings are active and the password is encrypted.

### Scenario B: Password Policies
* **Input**:
  ```hcl
  create_realm = true
  password_policy = {
    length       = 12
    digits       = 1
    not_username = true
  }
  ```
* **Expected Output**: The `password_policy` field on `keycloak_realm.this` will be provisioned with value `"length(12) and digits(1) and notUsername()"`.
* **Verification**: Verify in Keycloak Admin Console under Realm Settings -> Policies -> Password Policy.

### Scenario C: LDAP / User Federation
* **Input**:
  ```hcl
  ldap_federation = {
    enabled         = true
    connection_url  = "ldap://127.0.0.1:389"
    users_dn        = "ou=users,dc=example,dc=org"
    bind_dn         = "cn=admin,dc=example,dc=org"
    bind_credential = "admin-password"
  }
  ```
* **Expected Output**: 1 `keycloak_ldap_user_federation.this` resource created.
* **Verification**: Check User Federation under Keycloak Admin Console; verify the LDAP provider is visible.

### Scenario D: Multi-Factor Authentication (MFA)
* **Input**:
  ```hcl
  mfa = {
    enabled      = true
    methods      = ["totp"]
    required_for = ["all"]
  }
  ```
* **Expected Output**: `keycloak_required_action.totp` resource will be created, with `default_action = true`.
* **Verification**: Create a user and log in. The user should be immediately forced to scan a QR code to configure Google Authenticator / FreeOTP.

---

## 5. Troubleshooting Guide

### Issue 1: `Error: Invalid for_each argument: var.external_identity_providers has a sensitive value`
* **Cause**: The `external_identity_providers` variable was marked as `sensitive = true`, which prevents Terraform from using its keys in a `for_each` loop.
* **Solution**: Ensure you have removed the `sensitive = true` modifier from the variable in `variables.tf`. The provider already protects nested sensitive arguments (like client secrets) from appearing in the output/plan.

### Issue 2: `Error: Missing required argument: entity_id is required`
* **Cause**: Configuring a SAML identity provider (`keycloak_saml_identity_provider`) without specifying the IdP's Entity ID.
* **Solution**: Add the `entity_id` attribute inside the `external_identity_providers` block of your inputs (e.g. `entity_id = "https://idp.example.com"`).

### Issue 3: SMTP password is not changing on update
* **Cause**: A known Keycloak provider issue where updates to the nested `smtp_server.auth.password` field in Terraform are occasionally ignored by the Keycloak Admin API after initial creation.
* **Solution**: If the password change is not detected, manually trigger a refresh by updating another text field in the SMTP settings, or update it directly via the Keycloak console.

### Issue 4: Local Terragrunt runs fail with `network-outbound` permission denied (Sandbox)
* **Cause**: Terragrunt tries to fetch the Terraform S3 remote state backend and AWS/Keycloak endpoints, which are restricted outside the execution environment.
* **Solution**: Use mock states or run inside the approved CI environment with valid AWS credentials.
