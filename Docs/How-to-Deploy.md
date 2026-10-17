# How to deploy (end to end, with Keycloak SSO)

The complete, maintained install procedure is in the README: [Complete installation (from scratch)](../README.md#complete-installation-from-scratch). This page is the short version of the same sequence, ending with an SSO login into Grafana.

The layers, in order: **Cloud infrastructure** ➔ **Identity** ➔ **Storage + IRSA** ➔ **Secret sync** ➔ **Helm deployment**.

## 0. Target

```bash
export CLUSTER_NAME=millenniumfalcon AWS_REGION=us-east-2 ENVIRONMENT=dev   # prod | stage | dev
```

Make sure `ENVIRONMENT_NAME` (both Alloy values files) and `grafana.env.TENANT` (`prometheus-values.yaml`) are set to the same `ENVIRONMENT`.

## 1. VPC and EKS

```bash
cd terragrunt/infrastructure-live/accounts/mlops/us-east-2/vpc && terragrunt apply
cd ../eks && terragrunt apply
cd -
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
```

## 2. Keycloak client and Grafana OAuth secret

```bash
cd terragrunt/infrastructure-live/accounts/mlops/us-east-2/keycloak/grafana && terragrunt apply
cd ../../secrets/grafana-auth && terragrunt apply
cd -
```

## 3. S3 buckets, IRSA roles, rendered values

```bash
make aws-apply    # S3 → global/iam/role → render-helm-values (needs the Keycloak outputs from step 2)
```

## 4. Secrets

```bash
make external-secrets              # ESO with its IRSA role
make eso-seed ENVIRONMENT=$ENVIRONMENT
```

## 5. Install

```bash
make install       # init (namespaces + ExternalSecrets) and every component
```

## 6. Validate SSO

```bash
make pf-grafana    # http://localhost:3000
```

1. For a port-forward login, `root_url` and the Keycloak redirect URIs must allow `http://localhost:3000`. See [Grafana-SSO-Production.md](Grafana-SSO-Production.md) §5.
2. You should see **Sign in with Keycloak**. Log in with a Keycloak user.
3. Grafana maps your Keycloak roles to `GrafanaAdmin`, `Editor` or `Viewer`.
4. In Explore, check **Loki** (`{source="pod"}`) and **Mimir** (`up`) for the data of `$ENVIRONMENT`.
