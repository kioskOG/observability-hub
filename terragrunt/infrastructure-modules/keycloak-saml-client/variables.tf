variable "keycloak_base_url" {
  type        = string
  description = "The base URL of the Keycloak server (e.g., https://keycloak.company.com)"
}

variable "keycloak_username" {
  type        = string
  description = "The username of the Keycloak admin user"
}

variable "keycloak_password" {
  type        = string
  description = "The password of the Keycloak admin user"
  sensitive   = true
  default     = null
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "create_realm" {
  type        = bool
  description = "Whether to create a new realm or use an existing one"
  default     = false
}

variable "realm_name" {
  type        = string
  description = "The name of the realm to create or use"
  default     = "master"
}

variable "client_id" {
  type        = string
  description = "The unique Client ID for the SAML Client (SP Entity ID)"
}

variable "client_name" {
  type        = string
  description = "The display name of the SAML Client in the Keycloak GUI"
  default     = null
}

variable "enabled" {
  type        = bool
  description = "When false, this client will not be able to initiate a login or obtain access tokens. Defaults to true."
  default     = true
}

variable "consent_required" {
  type        = bool
  description = "When true, this client will require user consent before initiating a login or obtaining access tokens. Defaults to false."
  default     = false
}

variable "login_theme" {
  type        = string
  description = "The login theme for the SAML client. choose from keyclaok, keycloak.v2"
  default     = ""
}

variable "root_url" {
  type        = string
  description = "The root URL of the SAML client application"
  default     = ""
}

variable "base_url" {
  type        = string
  description = "The base URL of the SAML client application"
  default     = ""
}

variable "valid_redirect_uris" {
  type        = list(string)
  description = "List of valid redirect URIs for the SAML client"

  validation {
    condition     = length(var.valid_redirect_uris) > 0
    error_message = "At least one valid redirect URI must be specified."
  }
}

variable "idp_initiated_sso_url_name" {
  type        = string
  description = "The name of the IdP-initiated SSO URL"
  default     = ""
}

variable "master_saml_processing_url" {
  type        = string
  description = "The Assertion Consumer Service (ACS) URL for processing SAML assertions"
  default     = ""
}

variable "sign_assertions" {
  type        = bool
  description = "Whether assertions in the SAML response should be signed"
  default     = true
}

variable "sign_documents" {
  type        = bool
  description = "Whether SAML documents (responses) should be signed"
  default     = true
}

variable "force_name_id_format" {
  type        = bool
  description = "Whether to force a specific Name ID format"
  default     = false
}

variable "force_post_binding" {
  type        = bool
  description = "Whether to force POST binding"
  default     = true
}

variable "include_authn_statement" {
  type        = bool
  description = "Whether to include AuthnStatement in the SAML response"
  default     = true
}


variable "name_id_format" {
  type        = string
  description = "The SAML Name ID format (e.g., email, username, persistent, transient)"
  default     = "email"
}

variable "signature_algorithm" {
  type        = string
  description = "The signature algorithm used to sign documents. Should be one of RSA_SHA1, RSA_SHA256, RSA_SHA256_MGF1, RSA_SHA512, RSA_SHA512_MGF1 or DSA_SHA1."
  default     = "RSA_SHA256"

  validation {
    condition     = contains(["RSA_SHA1", "RSA_SHA256", "RSA_SHA256_MGF1", "RSA_SHA512", "RSA_SHA512_MGF1", "DSA_SHA1"], var.signature_algorithm)
    error_message = "The signature_algorithm must be one of: RSA_SHA1, RSA_SHA256, RSA_SHA256_MGF1, RSA_SHA512, RSA_SHA512_MGF1 or DSA_SHA1."
  }
}

variable "signature_key_name" {
  type        = string
  description = "The value of the KeyName element within the signed SAML document. Should be one of NONE, KEY_ID, or CERT_SUBJECT. Defaults to KEY_ID."
  default     = "KEY_ID"

  validation {
    condition     = contains(["NONE", "KEY_ID", "CERT_SUBJECT"], var.signature_key_name)
    error_message = "The signature_key_name must be one of: NONE, KEY_ID, or CERT_SUBJECT."
  }
}

variable "canonicalization_method" {
  type        = string
  description = "The Canonicalization Method for XML signatures. Should be one of EXCLUSIVE, EXCLUSIVE_WITH_COMMENTS, INCLUSIVE, or INCLUSIVE_WITH_COMMENTS. Defaults to EXCLUSIVE."
  default     = "EXCLUSIVE"

  validation {
    condition     = contains(["EXCLUSIVE", "EXCLUSIVE_WITH_COMMENTS", "INCLUSIVE", "INCLUSIVE_WITH_COMMENTS"], var.canonicalization_method)
    error_message = "The canonicalization_method must be one of: EXCLUSIVE, EXCLUSIVE_WITH_COMMENTS, INCLUSIVE, or INCLUSIVE_WITH_COMMENTS."
  }
}

variable "front_channel_logout" {
  type        = bool
  default     = true
  description = "When true, this client will require a browser redirect in order to perform a logout. Defaults to true."
}

variable "encrypt_assertions" {
  type        = bool
  description = "Whether assertions in the SAML response should be encrypted"
  default     = false
}

variable "assertion_consumer_post_url" {
  type        = string
  description = "SAML POST Binding URL for the client's assertion consumer service (login responses)."
  default     = ""
}

variable "logout_service_post_binding_url" {
  type        = string
  description = "SAML POST Binding URL for the client's logout service (logout responses)."
  default     = ""
}

variable "logout_service_redirect_binding_url" {
  type        = string
  description = "SAML Redirect Binding URL for the client's logout service (logout responses)."
  default     = ""
}

variable "roles" {
  type        = list(string)
  description = "List of client-level roles to create"
  default     = []
}

variable "use_realm_roles" {
  type        = bool
  description = "Whether to create realm-level roles instead of client-level roles"
  default     = false
}


variable "groups" {
  type = map(object({
    roles = list(string)
  }))
  description = "Map of realm groups and the client roles mapped to them (key: group name, value: list of client roles)"
  default     = {}
}

variable "full_scope_allowed" {
  type        = bool
  description = "Whether to allow full scope for the SAML client"
  default     = true
}

variable "email_attribute_name" {
  type        = string
  description = "SAML attribute name for email property"
  default     = "email"
}

variable "username_attribute_name" {
  type        = string
  description = "SAML attribute name for username property"
  default     = "username"
}

variable "first_name_attribute_name" {
  type        = string
  description = "SAML attribute name for first name property"
  default     = "firstName"
}

variable "last_name_attribute_name" {
  type        = string
  description = "SAML attribute name for last name property"
  default     = "lastName"
}

variable "groups_attribute_name" {
  type        = string
  description = "SAML attribute name for group memberships"
  default     = "groups"
}

variable "roles_attribute_name" {
  type        = string
  description = "SAML attribute name for client roles"
  default     = "roles"
}

variable "certificate_strategy" {
  type        = string
  description = "Strategy for certificate management: 'existing', 'generate', or 'vault' (future)"
  default     = "generate"

  validation {
    condition     = contains(["existing", "generate", "vault"], var.certificate_strategy)
    error_message = "The certificate_strategy must be one of: 'existing', 'generate', 'vault'."
  }
}

variable "saml_signing_certificate" {
  type        = string
  description = "PEM-encoded SAML signing certificate. Required if certificate_strategy is 'existing'."
  default     = null
  sensitive   = true
}

variable "saml_private_key" {
  type        = string
  description = "PEM-encoded SAML signing private key. Required if certificate_strategy is 'existing'."
  default     = null
  sensitive   = true
}

variable "users" {
  type = map(object({
    email            = string
    first_name       = string
    last_name        = string
    password         = string
    temporary_pass   = bool
    groups           = list(string)
    email_verified   = optional(bool, true)
    required_actions = optional(list(string), [])
  }))
  description = "Map of realm users to create (key: username, value: user configuration)"
  default     = {}
}

variable "secret_mappings" {
  type = map(object({
    secret_arn = string
    secret_key = string
  }))
  default     = {}
  description = "Map of module input keys (e.g. keycloak_password, smtp_password, smtp_host) to their corresponding AWS Secrets Manager Secret ARN/ID and JSON key."
}

variable "external_identity_providers" {
  type = map(object({
    enabled                    = bool
    type                       = string # "oidc" or "saml"
    client_id                  = optional(string)
    client_secret              = optional(string)
    authorization_url          = optional(string)
    token_url                  = optional(string)
    user_info_url              = optional(string)
    logout_url                 = optional(string)
    single_sign_on_service_url = optional(string)
    single_logout_service_url  = optional(string)
    name_id_policy_format      = optional(string, "urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified")
    alias                      = optional(string)
    display_name               = optional(string)
    entity_id                  = optional(string)
  }))
  description = "Map of external identity providers (key: provider name/alias)"
  default     = {}
}

variable "ldap_federation" {
  type = object({
    enabled                 = bool
    connection_url          = optional(string)
    users_dn                = optional(string)
    bind_dn                 = optional(string)
    bind_credential         = optional(string)
    name                    = optional(string, "ldap-federation")
    username_ldap_attribute = optional(string, "cn")
    rdn_ldap_attribute      = optional(string, "cn")
    uuid_ldap_attribute     = optional(string, "entryUUID")
    user_object_classes     = optional(list(string), ["inetOrgPerson", "organizationalPerson"])
    import_enabled          = optional(bool, true)
    sync_registrations      = optional(bool, false)
    edit_mode               = optional(string, "READ_ONLY")
    vendor                  = optional(string, "other")
  })
  description = "LDAP user federation configuration"
  default = {
    enabled = false
  }
  sensitive = true
}

variable "mfa" {
  type = object({
    enabled      = bool
    methods      = optional(list(string), []) # e.g. ["totp", "webauthn"]
    required_for = optional(list(string), []) # e.g. ["all", "admin"]
  })
  description = "MFA policies and default registration required actions"
  default = {
    enabled = false
  }
}

variable "password_policy" {
  type = object({
    length               = optional(number)
    digits               = optional(number)
    special_chars        = optional(number)
    upper_case           = optional(number)
    lower_case           = optional(number)
    password_history     = optional(number)
    max_age_days         = optional(number)
    not_username         = optional(bool, false)
    force_expired_change = optional(bool, false)
  })
  description = "Realm password policies"
  default     = null
}

variable "smtp" {
  type = object({
    host      = string
    port      = optional(string)
    from      = string
    from_name = optional(string)
    reply_to  = optional(string)
    ssl       = optional(bool)
    starttls  = optional(bool)
    username  = optional(string)
  })
  description = "Realm SMTP server settings"
  default     = null
}

variable "smtp_password" {
  type        = string
  description = "SMTP server password"
  default     = null
  sensitive   = true
}

variable "advanced_saml_mappers" {
  type = map(object({
    mapper_type     = string # "user_attribute", "user_property", "group", "role", "hardcoded_attribute"
    user_attribute  = optional(string)
    saml_attribute  = optional(string)
    user_property   = optional(string)
    attribute_value = optional(string) # for hardcoded attributes
    friendly_name   = optional(string)
  }))
  description = "Extensible map of custom SAML protocol mappers to provision"
  default     = {}
}

variable "realm_display_name" {
  type        = string
  description = "The display name of the realm"
  default     = null
}

variable "realm_display_name_html" {
  type        = string
  description = "The HTML display name of the realm"
  default     = null
}

variable "realm_login_theme" {
  type        = string
  description = "The login theme for the realm"
  default     = null
}

variable "realm_account_theme" {
  type        = string
  description = "The account theme for the realm"
  default     = null
}

variable "realm_admin_theme" {
  type        = string
  description = "The admin console theme for the realm"
  default     = null
}

variable "realm_email_theme" {
  type        = string
  description = "The email theme for the realm"
  default     = null
}

variable "ssl_required" {
  type        = string
  description = "The SSL requirement for the realm (external, all, or none)"
  default     = "external"
}

variable "remember_me" {
  type        = bool
  description = "Enable remember me on login page"
  default     = false
}

variable "registration_allowed" {
  type        = bool
  description = "Enable user self-registration"
  default     = false
}

variable "registration_email_as_username" {
  type        = bool
  description = "Use email address as username during self-registration"
  default     = false
}

variable "edit_username_allowed" {
  type        = bool
  description = "Allow users to edit their username"
  default     = false
}

variable "reset_password_allowed" {
  type        = bool
  description = "Allow users to reset their password via email"
  default     = false
}

variable "verify_email" {
  type        = bool
  description = "Force email verification for new users"
  default     = false
}

variable "login_with_email_allowed" {
  type        = bool
  description = "Allow login using email address"
  default     = true
}

variable "duplicate_emails_allowed" {
  type        = bool
  description = "Allow multiple users to register with same email"
  default     = false
}

variable "realm_attributes" {
  type        = map(string)
  description = "A map of custom realm attributes"
  default     = {}
}



