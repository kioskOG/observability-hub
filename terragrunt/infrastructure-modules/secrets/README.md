# Generic Secrets Publisher Module

This module abstracts the concept of "publishing application secrets". Its sole responsibility is accepting Terraform-generated secrets and publishing them to a secret store. 

It currently supports **AWS Secrets Manager**, but is designed to be cloud-agnostic in interface so it can be extended to support Vault, Kubernetes Secrets, or Azure Key Vault without changing the inputs.

## Architectural Reasoning
This module preserves the separation of concerns. Instead of coupling identity modules (like `keycloak-client`) with cloud-specific logic (like AWS Secrets Manager), this module allows the Terragrunt live layer to orchestrate them together.

## Usage

```hcl
module "secrets" {
  source = "../../infrastructure-modules/secrets"

  secrets = {
    "observability-hub/grafana-auth" = {
      description = "Grafana OIDC Client Secret"
      values = {
        GRAFANA_OAUTH_CLIENT_SECRET = "supersecret"
      }
    }
  }
}
```

## Security Implications
- Secrets are encrypted at rest using AWS KMS.
- Secrets are managed in Terraform state. When orchestrated across multiple Terragrunt components (e.g. passing a secret from Keycloak via `dependency`), the secret will exist in multiple Terraform state files.
- **Accepted Trade-off**: This state duplication is accepted to preserve the 1:1 Terragrunt component mapping without resorting to brittle, overly-specific wrapper modules.
- Ensure all Terraform states are stored in an encrypted remote backend (like S3 with KMS encryption) with strict IAM access controls.

## Secret Rotation Process
When an OAuth client secret is intentionally regenerated:
1. **Keycloak**: Rotates the secret.
2. **Terraform**: Detects the change during the next `terragrunt apply` on the Keycloak component.
3. **Secrets Publisher**: `terragrunt apply` on the Secrets component republishes the updated secret to AWS Secrets Manager.
4. **External Secrets**: ESO automatically synchronizes the new secret to the `monitoring` namespace in Kubernetes.
5. **Grafana**: A deployment rollout restart (or config reloader) triggers Grafana to mount the new environment variable.

## Failure Recovery
- **Keycloak apply succeeds, Secrets apply fails**: The secret is rotated in Keycloak but not in AWS. Grafana will fail to authenticate. Re-run `terragrunt apply` on the Secrets component to force convergence.
- **Secrets apply succeeds, ESO sync fails**: ESO may be down or lacking IAM permissions. Restart the ESO pod. Grafana continues to use the old secret (which will fail auth) until ESO syncs.
- **ESO sync succeeds, Grafana rollout fails**: The old Grafana pod remains running with the old secret. Kill the pod to force a restart and load the new secret.
