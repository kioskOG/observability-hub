include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../..//infrastructure-modules/iam/"
}

dependency "eks" {
  config_path = "../../../us-east-2/eks"
  mock_outputs = {
    oidc_issuer_url   = "https://oidc.eks.us-east-2.amazonaws.com/id/29B28D057753364E9FB4F59C3DB4A7DD"
    oidc_provider_arn = "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/oidc.eks.us-east-2.amazonaws.com/id/29B28D057753364E9FB4F59C3DB4A7DD"
  }
}

locals {
  common_vars = yamldecode(file("${get_terragrunt_dir()}/../../../us-east-2/common.yaml"))
}

inputs = {

  policy_vars = local.common_vars
  oidc_issuer_url   = dependency.eks.outputs.oidc_issuer_url
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn

  iam_role = {

    # --- Observability Hub (Loki / Mimir / Tempo / Pyroscope) IRSA ---
    # Buckets: millenniumfalcon-{loki,mimir}-{chunks,ruler}, millenniumfalcon-{tempo,pyroscope}-chunks
    # Apply S3 stacks under us-east-2/s3/millenniumfalcon-* before relying on these policies.

    LokiServiceAccountRole = {
      irsa_service_accounts = ["loki:*"]
      custom_policy = [
        "LokiServiceAccountRole"
      ]
      managed_policy = []
    }

    MimirServiceAccountRole = {
      irsa_service_accounts = ["mimir:*"]
      custom_policy = [
        "MimirServiceAccountRole"
      ]
      managed_policy = []
    }

    TempoServiceAccountRole = {
      irsa_service_accounts = ["tempo:*"]
      custom_policy = [
        "TempoServiceAccountRole"
      ]
      managed_policy = []
    }

    PyroscopeServiceAccountRole = {
      irsa_service_accounts = ["pyroscope:*"]
      custom_policy = [
        "PyroscopeServiceAccountRole"
      ]
      managed_policy = []
    }

    ESOControllerServiceAccountRole = {
      irsa_service_accounts = ["external-secrets:external-secrets"]
      custom_policy = [
        "ESOSecretsManagerAccessPolicy"
      ]
      managed_policy = []
    }
  }
}

