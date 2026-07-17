To test the complete end-to-end flow from scratch—starting with a raw AWS account and ending with a successful SSO login into Grafana—you should execute the following sequence of commands.

This sequence follows the repository's strict separation of concerns: **Cloud Infrastructure** ➔ **Identity Infrastructure** ➔ **Secret Sync** ➔ **Helm Application Deployment**.

### 1. Base AWS Infrastructure (VPC & EKS)
First, establish the network and compute layer.
```bash
# 1. Provision the VPC
cd terragrunt/infrastructure-live/accounts/mlops/us-east-2/vpc
terragrunt apply

# 2. Provision the EKS Cluster
cd ../eks
terragrunt apply

# 3. Authenticate kubectl against the new cluster
aws eks update-kubeconfig --region us-east-2 --name <your-cluster-name>
```

```
export AWS_REGION="us-east-2"                  
export KUBECONFIG=$HOME/.kube/millenniumfalcon
```

### 2. IAM & Storage (IRSA & S3)
Provision the S3 buckets for Loki/Mimir/Tempo and the IAM roles required by the pods.
```bash
# 1. Provision IAM roles for IRSA
cd ../../global/iam/role
terragrunt apply

# 2. Provision S3 buckets 
cd ../../us-east-2/s3
terragrunt run-all apply
```

### 3. Identity & Secrets Publication (The new SSO Integration)
Now, orchestrate the identity layer and publish the generated credentials.
```bash
# 1. Provision the Grafana OIDC Client in Keycloak
cd ../keycloak/grafana
terragrunt apply

# 2. Publish the generated OAuth client_secret to AWS Secrets Manager
cd ../../secrets/grafana-auth
terragrunt apply
```

### 4. Kubernetes Secret Synchronization
Switch back to the repository root to manage Kubernetes-level secret synchronization using the `Makefile`.
```bash
# Return to the repository root
cd ../../../../../../..

# 1. Seed standard Basic Auth passwords (Loki/Mimir) into AWS Secrets Manager
make eso-seed

# 2. Install External Secrets Operator (if not already installed on the cluster)
make external-secrets

# 3. Create ClusterSecretStore and ExternalSecrets (Syncs the Keycloak Secret to K8s)
make eso-apply
```

### 5. Helm Rendering & Deployment
Finally, deploy the Observability applications, dynamically injecting the Keycloak OIDC endpoints and client ID into Grafana.
```bash
# 1. Extract Terragrunt outputs (OIDC URLs, Client IDs, IAM ARNs) into rendered Helm templates
make render-helm-values

# 2. Install the complete Observability stack (Grafana, Loki, Mimir, Tempo, Alloy)
make init
make install
```

### 6. Validation (SSO Login)
Once the pods are running and stable, you can validate the authentication flow.
```bash
# 1. Port-forward Grafana to your local machine (if not exposed via Ingress)
make pf-grafana
```
1. Open your browser and navigate to `http://localhost:8080`.
2. You should see the **"Sign in with Keycloak"** button.
3. Click the button and log in with a valid Keycloak user.
4. You will be redirected back to Grafana and instantly granted access with a role (e.g. `GrafanaAdmin`, `Editor`, or `Viewer`) mapped dynamically based on your Keycloak permissions!
