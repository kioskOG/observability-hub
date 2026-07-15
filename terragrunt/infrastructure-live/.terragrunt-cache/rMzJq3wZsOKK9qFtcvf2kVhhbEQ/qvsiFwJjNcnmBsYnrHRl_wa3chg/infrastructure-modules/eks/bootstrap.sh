#!/bin/bash
set -ex
# /etc/eks/bootstrap.sh ${CLUSTER_NAME} --kubelet-extra-args "${KUBELET_ARGS}" --b64-cluster-ca ${B64_CLUSTER_CA} --apiserver-endpoint ${API_SERVER_URL}

sudo yum install -y amazon-ssm-agent
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent
