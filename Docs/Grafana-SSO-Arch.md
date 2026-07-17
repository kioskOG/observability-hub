# Grafana Keycloak OIDC Integration Architecture

## 1. Architecture Diagram

```mermaid
graph TD
    subgraph "Identity Provider"
        KC[Keycloak]
    end

    subgraph "Terragrunt Live Layer"
        TG_KC[Terragrunt: Keycloak Client]
        TG_SEC[Terragrunt: Secrets Publisher]
    end

    subgraph "AWS Infrastructure"
        ASM[AWS Secrets Manager]
    end

    subgraph "Kubernetes Cluster"
        ESO[External Secrets Operator]
        K8S_SEC[K8s Secret: grafana-auth-secrets]
        subgraph "Monitoring Namespace"
            GF[Grafana Pods]
        end
    end

    KC <-->|Provisions OIDC Client| TG_KC
    TG_KC -->|Outputs client_secret| TG_SEC
    TG_SEC -->|Publishes| ASM
    ASM -->|Syncs| ESO
    ESO -->|Creates| K8S_SEC
    K8S_SEC -->|Mounts envValueFrom| GF
    GF <-->|OIDC Auth Flow| KC
```

## 2. Authentication Sequence Diagram (OIDC Flow & Role Mapping)

```mermaid
sequenceDiagram
    participant U as User
    participant G as Grafana
    participant K as Keycloak

    U->>G: Access Grafana (No active session)
    G->>U: Redirect to Keycloak Auth URL
    U->>K: Authenticates (Credentials / SSO)
    K->>U: Redirect to Grafana Callback with Auth Code
    U->>G: Submit Auth Code
    G->>K: Exchange Auth Code for Tokens (via client_secret)
    K->>G: Return ID Token & Access Token (includes `roles` and `groups`)
    Note over G: Grafana extracts Keycloak `roles` claim
    Note over G: Evaluates JMESPath role_attribute_path
    Note over G: Maps Keycloak 'admin' -> GrafanaAdmin
    G->>U: Grant Access to Dashboard
```

## 3. Secret Publication Flow

```mermaid
sequenceDiagram
    participant KC as Keycloak
    participant TF as Terraform (Keycloak Module)
    participant TG as Terragrunt (Dependency)
    participant SM as AWS Secrets Manager
    participant ESO as External Secrets Operator
    participant GF as Grafana

    KC->>TF: Auto-generates OAuth Client Secret
    TF->>TG: Outputs client_secret in Terraform State
    TG->>SM: Module publishes secret to `observability-hub/grafana-auth`
    SM->>ESO: Periodic Sync (every 1h or triggered)
    ESO->>GF: Injects GRAFANA_OAUTH_CLIENT_SECRET as Environment Variable
```

## 4. Deployment Flow

1. **Identity Provisioning**: Run `terragrunt apply` on `us-east-2/keycloak/grafana` to create the OIDC client in Keycloak.
2. **Secret Publication**: Run `terragrunt apply` on `us-east-2/secrets/grafana-auth` to publish the generated secret to AWS Secrets Manager.
3. **Secret Synchronization**: Run `make eso-apply` to apply the `ExternalSecret` manifest, which syncs the AWS Secret to Kubernetes.
4. **Helm Rendering**: Run `make render-helm-values`. The script uses `terragrunt output` to extract the `oidc` endpoints and injects them dynamically into `prometheus-override-values.rendered.yaml`.
5. **Grafana Rollout**: Run `make install-kube-prometheus-stack` to upgrade the Grafana Helm chart, injecting the secrets and endpoints.

## 5. Validation Checklist

- [x] `terraform validate` and `terragrunt validate` pass cleanly.
- [x] `terragrunt run-all plan` across `keycloak` and `secrets` yields expected creations.
- [x] Wazuh SAML client reports `No changes. Your infrastructure matches the configuration.`
- [x] Grafana OIDC Login flow redirects successfully to Keycloak.
- [x] PKCE code challenge verification succeeds (no insecure legacy implicit flows).
- [x] Logout successfully invalidates the Keycloak session and redirects to Grafana login.
- [x] User with Keycloak `viewer` role gets `Viewer` in Grafana.
- [x] User with Keycloak `admin` role gets `GrafanaAdmin` in Grafana.
- [x] User with no mapped roles gets default `Viewer` or is denied based on strict mapping.

## 6. Rollback Procedure

If the Grafana OIDC integration fails in production:
1. Revert `auth.generic_oauth.enabled` to `false` in `prometheus-values.yaml` (or remove the override).
2. Run `make install-kube-prometheus-stack` to restore the previous authentication configuration (e.g. basic auth).
3. (Optional) Run `terragrunt destroy` on the `secrets/grafana-auth` component to remove the secret from AWS.
4. (Optional) Run `terragrunt destroy` on the `keycloak/grafana` component to remove the Keycloak client.

## 7. Production Readiness Review

- **Security**: The OAuth client secret is authoritative to Keycloak, never hardcoded, encrypted at rest via AWS KMS, and mapped strictly via ESO memory variables (no plaintext files). PKCE is enabled.
- **Idempotency**: The entire pipeline relies exclusively on Terraform and Helm declarative state. `make render-helm-values` relies on live `terragrunt outputs` (not hardcoded cache).
- **Separation of Concerns**: `keycloak-client` only handles identity. `secrets` module only handles cloud publication. `Grafana Helm` only handles application role mapping (JMESPath). 
- **Trade-off Acknowledged**: The `client_secret` exists in both Keycloak and Secrets Terraform states. This is mitigated by enforcing encrypted remote S3 backends for state files.

**Production cutover (URLs, redirects, hardening):** see [Grafana-SSO-Production.md](./Grafana-SSO-Production.md).
