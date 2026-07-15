apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: ${CLUSTER_NAME}
    apiServerEndpoint: ${API_SERVER_URL}
    certificateAuthority: ${B64_CLUSTER_CA}
    cidr: ${CLUSTER_SERVICE_CIDR}
  kubelet:
    config:
      clusterDNS:
      - 172.20.0.10

# https://awslabs.github.io/amazon-eks-ami/nodeadm/doc/playground/