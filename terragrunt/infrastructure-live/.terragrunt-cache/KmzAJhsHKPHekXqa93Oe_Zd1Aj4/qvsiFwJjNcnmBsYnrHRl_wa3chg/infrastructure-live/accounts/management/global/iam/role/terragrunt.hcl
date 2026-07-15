include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../..//infrastructure-modules/iam/"
}

inputs = {

  iam_role = {
    # IRSA role for Wazuh Manager pods — allows S3 read access to the central
    # AWS logs bucket and KMS decrypt for encrypted log objects.
    WazuhManagerServiceAccountRole = {
      custom_policy = [
        "WazuhManagerServiceAccountRole"
      ]
      managed_policy = []
    }

    # IRSA role for Wazuh Indexer pods — allows S3 read/write for snapshot
    # repository-s3 backup and restore operations.
    WazuhIndexerSnapshotsRole = {
      custom_policy = [
        "WazuhIndexerSnapshotsRole"
      ]
      managed_policy = []
    }
  }
}
