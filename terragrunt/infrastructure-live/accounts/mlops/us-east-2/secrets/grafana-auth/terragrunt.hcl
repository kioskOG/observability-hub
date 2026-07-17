include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../..//infrastructure-modules/secrets"
}

dependency "grafana_keycloak" {
  config_path = "../../keycloak/grafana"
  
  mock_outputs = {
    client_secret = "mock-secret-for-plan"
    client = {
      client_id = "mock-client-id"
    }
  }
}

inputs = {
  region = "us-east-2"
  secrets = {
    "observability-hub/grafana-auth" = {
      description = "Grafana OIDC Client Secret (Published by Terraform)"
      values = {
        GRAFANA_OAUTH_CLIENT_SECRET = dependency.grafana_keycloak.outputs.client_secret
      }
    }
  }
}
