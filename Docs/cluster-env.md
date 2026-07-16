# Cluster / region configuration

How observability-hub resolves **EKS cluster name** and **AWS region** for Make, External Secrets, and Helm rendering.

## Do not rely on `.observability-poc-aws.state`

That file is an **optional legacy inventory** for `cleanup-aws.sh --from-state` only. The Makefile does **not** require it.

## Resolution order

Implemented in [`scripts/resolve-cluster-env.sh`](../scripts/resolve-cluster-env.sh):

1. **Environment (preferred)**
   - Cluster: `CLUSTER_NAME` or `CLUSTER`
   - Region: `AWS_REGION`, then `AWS_DEFAULT_REGION`, then `REGION`
2. **Live discovery**
   - `kubectl` current context / cluster name (EKS ARN) or node labels / `providerID`
   - `aws configure get region`
3. **Legacy state file** (deprecated) — prints a warning if used

## Everyday usage

```bash
# Explicit (CI / laptops without EKS context name)
export CLUSTER_NAME=millenniumfalcon
export AWS_REGION=us-east-2

make show-env
make eso-iam-role
make install-kube-prometheus-stack
```

Or rely on an EKS kubecontext shaped like:

`arn:aws:eks:us-east-2:123456789012:cluster/millenniumfalcon`

```bash
kubectl config use-context arn:aws:eks:us-east-2:…:cluster/millenniumfalcon
make show-env   # CLUSTER_NAME + REGION from the ARN
```

## Related Make targets

| Target | Uses cluster/region for |
|--------|-------------------------|
| `show-env` | Print resolved values + source |
| `eso-iam-role` / `external-secrets` | EKS OIDC trust for IRSA |
| `eso-apply` / `eso-seed` | Secrets Manager region / ClusterSecretStore |
| `install-kube-prometheus-stack` | Prometheus external label `clusterName` |
| `render-helm-values` / `aws-apply` | Bucket naming + IRSA ARN render |

## Helm render inputs

`terragrunt/.../render-observability-helm-and-state.sh` reads the same env vars (`CLUSTER_NAME`, `AWS_REGION`, …). Bucket names follow `{cluster_lower}-loki-chunks`, etc.

Set `WRITE_OBSERVABILITY_STATE=0` to skip writing the optional legacy state file.
