# Dynamic AWS Secrets Manager lookup
# Resolves module inputs from mapping definitions dynamically at runtime

locals {
  # Extract unique secret ARNs from the mapping configuration
  secret_arns = distinct([for k, v in var.secret_mappings : v.secret_arn])
}

data "aws_secretsmanager_secret_version" "mapped" {
  for_each  = toset(local.secret_arns)
  secret_id = each.value
}

locals {
  # Parse the secrets JSON string for each retrieved secret
  parsed_secrets = {
    for arn in local.secret_arns :
    arn => jsondecode(data.aws_secretsmanager_secret_version.mapped[arn].secret_string)
  }

  # Map individual keys dynamically
  resolved_secrets = {
    for k, v in var.secret_mappings :
    k => lookup(local.parsed_secrets[v.secret_arn], v.secret_key, null)
  }

  # Resolution with priority:
  # 1. Explicit variable value (if provided)
  # 2. Resolved value from secret_mappings
  # 3. Module default

  # 1. Resolve Keycloak administrative password
  resolved_keycloak_password = var.keycloak_password != null ? var.keycloak_password : lookup(local.resolved_secrets, "keycloak_password", null)

  # 2. Resolve SMTP authentication password
  resolved_smtp_password = var.smtp_password != null ? var.smtp_password : lookup(local.resolved_secrets, "smtp_password", null)

  # 3. Resolve LDAP bind credentials (mapped from ldap_bind_password)
  resolved_ldap_credential = try(var.ldap_federation.bind_credential, null) != null ? var.ldap_federation.bind_credential : lookup(local.resolved_secrets, "ldap_bind_password", null)

  # 4. Resolve SMTP parameters
  resolved_smtp_host     = try(var.smtp.host, null) != null ? var.smtp.host : lookup(local.resolved_secrets, "smtp_host", null)
  resolved_smtp_port     = try(var.smtp.port, null) != null ? var.smtp.port : lookup(local.resolved_secrets, "smtp_port", null)
  resolved_smtp_from     = try(var.smtp.from, null) != null ? var.smtp.from : lookup(local.resolved_secrets, "smtp_from", null)
  resolved_smtp_username = try(var.smtp.username, null) != null ? var.smtp.username : lookup(local.resolved_secrets, "smtp_username", null)

  smtp_config = (var.smtp != null || local.resolved_smtp_host != null) ? {
    host              = local.resolved_smtp_host
    port              = local.resolved_smtp_port
    from              = local.resolved_smtp_from
    from_display_name = try(var.smtp.from_name, null) != null ? var.smtp.from_name : lookup(local.resolved_secrets, "smtp_from_name", null)
    reply_to          = try(var.smtp.reply_to, null) != null ? var.smtp.reply_to : lookup(local.resolved_secrets, "smtp_reply_to", null)
    ssl               = try(var.smtp.ssl, null) != null ? var.smtp.ssl : lookup(local.resolved_secrets, "smtp_ssl", null)
    starttls          = try(var.smtp.starttls, null) != null ? var.smtp.starttls : lookup(local.resolved_secrets, "smtp_starttls", null)
    username          = local.resolved_smtp_username
  } : null
}
