data "tls_certificate" "this" {
  url = aws_eks_cluster.eks_cluster.identity.0.oidc.0.issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = concat([data.tls_certificate.this.certificates.0.sha1_fingerprint], var.custom_oidc_thumbprints)
  url             = aws_eks_cluster.eks_cluster.identity.0.oidc.0.issuer

  #    tags = merge(
  #     { Name = "${var.cluster_name}-eks-irsa" },
  #     var.tags
  #   )
}