include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../..//infrastructure-modules/iam/"
}

inputs = {

  oidc = {
    "github" = {
      tls_certificate_url     = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
      url                     = "https://token.actions.githubusercontent.com"
      client_id_list          = ["sts.amazonaws.com"]
      custom_oidc_thumbprints = []
    }
  }
}