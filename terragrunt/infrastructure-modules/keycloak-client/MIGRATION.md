# Migration Guide: `keycloak-saml-client` → `keycloak-client`

This guide covers renaming the module and adopting SAML + OIDC support without breaking existing Wazuh (SAML) deployments.

## 1. Module path

| Before | After |
|--------|--------|
| `infrastructure-modules/keycloak-saml-client` | `infrastructure-modules/keycloak-client` |

Update Terragrunt `terraform.source`:

```hcl
terraform {
  source = "../../../../../..//infrastructure-modules/keycloak-client"
}
```

State lives in the live stack directory. Changing the module *source path* does not change resource addresses; `moved` blocks inside the module handle address shifts from adding `count` / renames.

## 2. Protocol default (Wazuh-safe)

`client_protocol` defaults to `"saml"`. Existing SAML stacks need **no** protocol input.

```hcl
# Optional — this is already the default
client_protocol = "saml"
```

OIDC stacks must set:

```hcl
client_protocol = "openid-connect"
```

## 3. Mapper variable rename

| Deprecated | Prefer |
|------------|--------|
| `advanced_saml_mappers` | `saml_mappers` |

`advanced_saml_mappers` still works and is merged with `saml_mappers` (`saml_mappers` wins on key clash). Migrate when convenient:

```hcl
# Before
advanced_saml_mappers = {
  department = {
    mapper_type    = "user_attribute"
    user_attribute = "department"
    saml_attribute = "department"
  }
}

# After
saml_mappers = {
  department = {
    mapper_type    = "user_attribute"
    user_attribute = "department"
    saml_attribute = "department"
  }
}
```

### Extensible mappers (any Keycloak mapper type)

Prefer `protocol_mapper` + `config` when typed shortcuts are insufficient:

```hcl
saml_mappers = {
  custom = {
    protocol_mapper = "saml-user-attribute-mapper"
    config = {
      "user.attribute"       = "department"
      "attribute.name"       = "department"
      "attribute.nameformat" = "Basic"
    }
  }
}

oidc_mappers = {
  custom = {
    protocol_mapper = "oidc-usermodel-attribute-mapper"
    config = {
      "user.attribute" = "department"
      "claim.name"     = "department"
      "jsonType.label" = "String"
      "id.token.claim" = "true"
    }
  }
}
```

## 4. Outputs

Prefer structured outputs:

| Prefer | Deprecated flat aliases |
|--------|-------------------------|
| `client` (`protocol`, `client_id`, `client_uuid`, `name`, `realm`) | — |
| `endpoints` (protocol-selected bundle) | — |
| `saml` / `oidc` | `idp_metadata_url`, `idp_entity_id`, `sp_entity_id` |
| `client_secret` (sensitive, OIDC only) | — |

```hcl
# Before
module.x.idp_metadata_url

# After
module.x.endpoints.idp_metadata_url
# or
module.x.saml.idp_metadata_url
```

Flat SAML outputs remain for one release cycle of compatibility.

## 5. Endpoints

All URLs are built in `locals.tf` from `keycloak_base_url` + realm (`local.endpoints`). Do not re-derive paths in callers.

## 6. Wazuh zero-drift checklist

1. Point Terragrunt source at `keycloak-client`.
2. Leave `client_protocol` unset (or `"saml"`).
3. Keep existing SAML inputs unchanged.
4. Run `terragrunt plan` — expect **No changes** (aside from any intentional input edits).
5. `moved.tf` remaps uncounted `keycloak-saml-client` addresses → counted `[0]` addresses:
   - `keycloak_saml_client.this` → `this[0]`
   - default scopes, property mappers, roles mapper, `null_resource`
   - `advanced_*` mapper resources → `saml_*` names

If plan shows destroy/recreate of the SAML client, stop and verify `moved.tf` is present in the module version you are applying.

## 7. Grafana (OIDC) cutover

Grafana live config should use OIDC per [Grafana Keycloak docs](https://grafana.com/docs/grafana/latest/setup-grafana/configure-access/configure-authentication/keycloak/):

- `client_protocol = "openid-connect"`
- Redirect: `/login/generic_oauth`
- Roles: `admin` / `editor` / `viewer` (map in Grafana `role_attribute_path`)
- Optional `oidc_mappers.groups` for Team Sync
- Wire Grafana `[auth.generic_oauth]` to `endpoints.*` and `client_secret`

See `examples/grafana/` and `us-east-2/keycloak/grafana/terragrunt.hcl`.
