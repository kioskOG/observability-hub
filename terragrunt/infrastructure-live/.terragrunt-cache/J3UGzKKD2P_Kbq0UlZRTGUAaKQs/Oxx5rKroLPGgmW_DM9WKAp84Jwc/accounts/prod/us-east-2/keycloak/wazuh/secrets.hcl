# Secrets file for Keycloak SAML Client integration
# In production, sensitive variables should be fetched dynamically from Vault or Secrets Manager.
# e.g., using: `aws_secretsmanager` or sops decryption.

locals {
  # Example: Injecting custom cert if certificate_strategy is "existing"
  # saml_signing_certificate = get_env("SAML_SIGNING_CERTIFICATE", "")
  # saml_private_key         = get_env("SAML_PRIVATE_KEY", "")
}
