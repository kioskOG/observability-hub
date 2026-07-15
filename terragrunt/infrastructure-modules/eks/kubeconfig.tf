resource "local_file" "kubeconfig" {
  content              = local.kubeconfig
  filename             = substr(var.config_output_path, -1, 1) == "/" ? "${var.config_output_path}kubeconfig_${var.cluster_name}" : var.config_output_path
  file_permission      = "0644"
  directory_permission = "0755"
  depends_on           = [aws_eks_cluster.eks_cluster]
}
