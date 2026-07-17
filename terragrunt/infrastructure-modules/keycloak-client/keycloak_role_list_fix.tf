###############################################################################
# keycloak_role_list_fix.tf
#
# Permanent fix for the SAML duplicate Attribute Name error:
#   "Found an Attribute element with duplicated Name"
#
# Root cause:
#   When Keycloak creates a SAML client it auto-attaches the realm-level
#   'role_list' Client Scope. That scope contains a built-in mapper named
#   'role list' with attribute.name=Role and single=false. This causes
#   Keycloak to emit one <saml:Attribute Name="Role"> per realm role,
#   resulting in duplicate Attribute Name elements that break java-saml
#   (used by OpenSearch / Wazuh Indexer).
#
# Fix:
#   Delete the built-in 'role list' mapper from the realm-level 'role_list'
#   scope via the Keycloak Admin REST API. Our custom 'wazuhRoleKey' mapper
#   (on the SAML client, attribute.name=Roles, single=true) then takes over
#   and emits a single, clean <saml:Attribute Name="Roles"> element.
#
# Idempotency:
#   The script checks for mapper existence before deleting. Subsequent
#   applies are no-ops when the mapper has already been removed.
###############################################################################

resource "null_resource" "delete_role_list_mapper" {
  count = local.is_saml ? 1 : 0

  # Re-run if the realm or Keycloak URL changes, or if the client is recreated
  triggers = {
    realm_name   = var.realm_name
    keycloak_url = var.keycloak_base_url
    client_id    = keycloak_saml_client.this[0].id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-SCRIPT
      set -euo pipefail

      KEYCLOAK_URL="${var.keycloak_base_url}"
      REALM="${var.realm_name}"
      USERNAME="${var.keycloak_username}"
      PASSWORD="${local.resolved_keycloak_password}"

      echo "[role-list-fix] Authenticating to Keycloak at $KEYCLOAK_URL ..."
      TOKEN=$(curl -sf \
        -d "client_id=admin-cli&grant_type=password&username=$USERNAME&password=$PASSWORD" \
        "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

      echo "[role-list-fix] Looking up 'role_list' client scope in realm '$REALM'..."
      SCOPE_ID=$(curl -sf \
        -H "Authorization: Bearer $TOKEN" \
        "$KEYCLOAK_URL/admin/realms/$REALM/client-scopes" \
        | python3 -c "
import sys, json
scopes = json.load(sys.stdin)
match = next((s['id'] for s in scopes if s['name'] == 'role_list'), None)
print(match or '')
")

      if [ -z "$SCOPE_ID" ]; then
        echo "[role-list-fix] 'role_list' scope not found. Nothing to do."
        exit 0
      fi
      echo "[role-list-fix] Found role_list scope: $SCOPE_ID"

      echo "[role-list-fix] Searching for built-in mapper with single=false..."
      MAPPER_ID=$(curl -sf \
        -H "Authorization: Bearer $TOKEN" \
        "$KEYCLOAK_URL/admin/realms/$REALM/client-scopes/$SCOPE_ID/protocol-mappers/models" \
        | python3 -c "
import sys, json
mappers = json.load(sys.stdin)
# Find the saml-role-list-mapper with single=false (the problematic built-in)
match = next((
    m['id'] for m in mappers
    if m.get('protocolMapper') == 'saml-role-list-mapper'
    and m.get('config', {}).get('single', 'true').lower() == 'false'
), None)
print(match or '')
")

      if [ -z "$MAPPER_ID" ]; then
        echo "[role-list-fix] Built-in role list mapper (single=false) not found. Already clean."
        exit 0
      fi

      echo "[role-list-fix] Deleting problematic mapper $MAPPER_ID ..."
      HTTP_STATUS=$(curl -sf -o /dev/null -w "%%{http_code}" -X DELETE \
        -H "Authorization: Bearer $TOKEN" \
        "$KEYCLOAK_URL/admin/realms/$REALM/client-scopes/$SCOPE_ID/protocol-mappers/models/$MAPPER_ID")

      if [ "$HTTP_STATUS" = "204" ] || [ "$HTTP_STATUS" = "200" ]; then
        echo "[role-list-fix] SUCCESS: Deleted built-in 'role list' mapper from 'role_list' scope."
        echo "[role-list-fix] Only wazuhRoleKey (single=true, Name=Roles) will now emit roles."
      else
        echo "[role-list-fix] ERROR: Unexpected HTTP status: $HTTP_STATUS"
        exit 1
      fi
    SCRIPT
  }

  depends_on = [
    keycloak_saml_client.this,
    keycloak_generic_protocol_mapper.roles,
  ]
}
