# Secrets Manager — Wazuh Secrets
#
# TODO: This is a placeholder. Create the Secrets Manager Terragrunt stack
# to provision the `generic/infra/wazuh` secret containing:
#   - indexer-admin-password
#   - dashboard-password
#   - api-username / api-password
#   - authd-pass
#   - cluster-key
#   - SAML exchange key (Phase 3)
#
# The user will set up External Secrets Operator + SecretStore in the shared
# namespace separately.

include {
  path = find_in_parent_folders()
}

# TODO: Replace with actual secret-manager module source
# terraform {
#   source = "../../../../../..//infrastructure-modules/secret-manager/"
# }

# inputs = {
#   secrets = {
#     "generic/infra/wazuh" = {
#       description = "Wazuh SIEM stack secrets (indexer, dashboard, manager API, authd, cluster key, SAML SSO)"
#       secret_string = jsonencode({
#         "indexer-admin-password" = "<GENERATE>"
#         "dashboard-password"    = "<GENERATE>"
#         "api-username"          = "wazuh-wui"
#         "api-password"          = "<GENERATE>"
#         "authd-pass"            = "<GENERATE>"
#         "cluster-key"           = "<GENERATE>"
#         "saml-idp-name"         = "google"
#         "saml-idp-entity-id"    = "https://accounts.google.com/o/saml2?idpid=C0123456"
#         "saml-idp-metadata-url" = "https://accounts.google.com/o/saml2?idpid=C0123456"
#         "saml-exchange-key"     = "<GENERATE_64_CHAR_HEX>"
#         "saml-sp-entity-id"     = "https://wazuh.int.generic.com"
#         "saml-dashboard-url"    = "https://wazuh.int.generic.com"
#         "saml-subject-key"      = "email"
#         "saml-roles-key"        = "groups"
#         "saml-admin-group"      = "WazuhAdmins"
#         "saml-security-group"   = "SecurityEngineers"
#         "saml-readonly-group"   = "LogsReadOnly"
#       })
#     }
#   }
# }
