include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../..//infrastructure-modules/iam/"
}

inputs = {

  iam_role = {

    # --- Observability Hub (Loki / Mimir / Tempo / Pyroscope) IRSA ---
    # Buckets: millenniumfalcon-{loki,mimir}-{chunks,ruler}, millenniumfalcon-{tempo,pyroscope}-chunks
    # Apply S3 stacks under us-east-2/s3/millenniumfalcon-* before relying on these policies.

    LokiServiceAccountRole = {
      custom_policy = [
        "LokiServiceAccountRole"
      ]
      managed_policy = []
    }

    MimirServiceAccountRole = {
      custom_policy = [
        "MimirServiceAccountRole"
      ]
      managed_policy = []
    }

    TempoServiceAccountRole = {
      custom_policy = [
        "TempoServiceAccountRole"
      ]
      managed_policy = []
    }

    PyroscopeServiceAccountRole = {
      custom_policy = [
        "PyroscopeServiceAccountRole"
      ]
      managed_policy = []
    }
  }
}

