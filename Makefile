.DEFAULT_GOAL := help



# -------------------------------------
# Namespaces

NAMESPACE_loki  = loki
NAMESPACE_tempo = tempo
NAMESPACE_alloy = alloy-logs
NAMESPACE_mimir = mimir
NAMESPACE_kube-prometheus-stack = monitoring
NAMESPACE_pyroscope = pyroscope
NAMESPACE_blackbox = monitoring
NAMESPACE_beyla = beyla

# -------------------------------------
# Chart sources

CHART_loki  = grafana/loki
CHART_tempo = grafana/tempo-distributed
CHART_alloy = grafana/alloy
CHART_mimir = grafana/mimir-distributed
CHART_kps   = ./kube-prometheus-stack
CHART_pyroscope = grafana/pyroscope
CHART_blackbox = prometheus-community/prometheus-blackbox-exporter
CHART_beyla = grafana/beyla

# -------------------------------------
# Chart versions

VERSION_loki  = 6.30.1
VERSION_tempo = 1.42.2
VERSION_alloy = 1.1.1
VERSION_mimir = 5.7.0
VERSION_pyroscope = 1.14.0
VERSION_blackbox = 11.0.0
VERSION_beyla = 1.16.8

# -------------------------------------
# Values files

VALUES_loki  = ./loki/loki-override-values.yaml
VALUES_tempo = ./tempo/tempo-override-values.yaml
VALUES_alloy = ./alloy/alloy-override-values.yaml
VALUES_mimir = ./mimir/mimir-override-values.yaml
VALUES_kps   = ./kube-prometheus-stack/prometheus-values.yaml
VALUES_pyroscope = ./pyroscope/pyroscope-override-values.yaml
VALUES_blackbox = ./blackbox-exporter/values.yaml
VALUES_beyla = ./beyla/beyla-values.yaml

# -------------------------------------
# kube-prometheus-stack: Prometheus external label cluster (same as script.sh cluster_name)

OBSERVABILITY_STATE_FILE ?= ./.observability-poc-aws.state
# Written by ./script.sh → make init. Override: CLUSTER_NAME=my-eks make install-kube-prometheus-stack
CLUSTER_NAME ?= $(shell test -f $(OBSERVABILITY_STATE_FILE) && grep -E '^cluster_name=' $(OBSERVABILITY_STATE_FILE) 2>/dev/null | cut -d= -f2- | head -1 | tr -d '\r')
# ESO IRSA + ClusterSecretStore (same state file keys as script.sh)
CLUSTER ?= $(CLUSTER_NAME)
REGION ?= $(shell test -f $(OBSERVABILITY_STATE_FILE) && grep -E '^region_name=' $(OBSERVABILITY_STATE_FILE) 2>/dev/null | cut -d= -f2- | head -1 | tr -d '\r')
TMP_DIR ?= /tmp/observability-hub-eso
ESO_SECRET_PREFIX ?= observability-hub
# Only pass --set when non-empty so values.yaml / Helm defaults still apply when no state file exists
HELM_KPS_CLUSTER_SET = $(if $(strip $(CLUSTER_NAME)),--set clusterName="$(CLUSTER_NAME)",)

# Existing Terragrunt layout (no composition module):
#   S3  → terragrunt/.../us-east-2/s3/millenniumfalcon-*
#   IAM → terragrunt/.../global/iam/role/  (Loki/Mimir/Tempo/Pyroscope IRSA)
TG_MLOPS_DIR   ?= terragrunt/infrastructure-live/accounts/mlops
TG_S3_DIR      ?= $(TG_MLOPS_DIR)/us-east-2/s3
TG_IAM_ROLE_DIR ?= $(TG_MLOPS_DIR)/global/iam/role
OBS_S3_STACKS ?= \
	millenniumfalcon-loki-chunks \
	millenniumfalcon-loki-ruler \
	millenniumfalcon-mimir-chunks \
	millenniumfalcon-mimir-ruler \
	millenniumfalcon-tempo-chunks \
	millenniumfalcon-pyroscope-chunks


# -------------------------------------
# AWS via Terragrunt (existing s3 + iam modules / live stacks)

aws-plan:
	@for s in $(OBS_S3_STACKS); do \
		echo "👉 plan s3/$$s"; \
		(cd $(TG_S3_DIR)/$$s && terragrunt plan); \
	done
	@echo "👉 plan global/iam/role"
	@cd $(TG_IAM_ROLE_DIR) && terragrunt plan

aws-apply:
	@for s in $(OBS_S3_STACKS); do \
		echo "👉 apply s3/$$s"; \
		(cd $(TG_S3_DIR)/$$s && terragrunt apply -auto-approve); \
	done
	@echo "👉 apply global/iam/role (includes observability IRSA)"
	@cd $(TG_IAM_ROLE_DIR) && terragrunt apply -auto-approve
	@$(MAKE) render-helm-values

aws-destroy:
	@echo "👉 destroy observability IRSA roles first (edit iam/role inputs if you only want LGTM roles removed)"
	@for s in $(OBS_S3_STACKS); do \
		echo "👉 destroy s3/$$s"; \
		(cd $(TG_S3_DIR)/$$s && terragrunt destroy -auto-approve); \
	done

# Re-render Helm *-override-values.yaml + .observability-poc-aws.state
render-helm-values:
	@chmod +x $(TG_MLOPS_DIR)/render-observability-helm-and-state.sh
	@$(TG_MLOPS_DIR)/render-observability-helm-and-state.sh "$(CURDIR)"


# -------------------------------------
# Helm repo & namespace bootstrap

init:
	@echo "👉 Provisioning AWS S3 + IRSA via Terragrunt (was script.sh)..."
	@$(MAKE) aws-apply

	@kubectl apply -f ./default-storage-class.yaml

	@echo "👉 Adding Helm repo if missing and updating..."
	@helm repo add grafana https://grafana.github.io/helm-charts || true
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	@helm repo update

	@echo "👉 Ensuring required namespaces exist..."
	@for ns in $(NAMESPACE_loki) $(NAMESPACE_tempo) $(NAMESPACE_alloy) $(NAMESPACE_mimir) $(NAMESPACE_kube-prometheus-stack) $(NAMESPACE_pyroscope) $(NAMESPACE_blackbox) $(NAMESPACE_beyla); do \
		if ! kubectl get namespace $$ns > /dev/null 2>&1; then \
			echo "✅ Creating namespace: $$ns"; \
			kubectl create namespace $$ns; \
		else \
			echo "⚙️  Namespace $$ns already exists. Skipping."; \
		fi \
	done

	@echo "👉 Syncing basic-auth secrets via External Secrets Operator (no local .htpasswd)..."
	@if ! kubectl api-resources | grep -q '^clustersecretstores'; then \
		echo "ERROR: External Secrets CRDs missing. Run: make external-secrets && make eso-seed && make init"; \
		exit 1; \
	fi
	@$(MAKE) eso-apply

	@echo "✅ All initial setup complete."


# -------------------------------------
# Legacy alias: credentials now come from ExternalSecrets (see eso-apply).
apply-alloy-manifests: eso-apply


# -------------------------------------
# AWS POC cleanup (S3 + IAM from Terragrunt / legacy script.sh state — not Kubernetes)

aws-cleanup-dry-run:
	@chmod +x ./cleanup-aws.sh
	@if [ -f ./.observability-poc-aws.state ]; then \
		echo "👉 Using .observability-poc-aws.state (dry-run)"; \
		./cleanup-aws.sh --dry-run --from-state; \
	else \
		echo "👉 No state file — you will be prompted like script.sh (dry-run)"; \
		./cleanup-aws.sh --dry-run; \
	fi

aws-cleanup:
	@chmod +x ./cleanup-aws.sh
	@if [ -f ./.observability-poc-aws.state ]; then \
		echo "👉 Using .observability-poc-aws.state"; \
		./cleanup-aws.sh --from-state; \
	else \
		echo "👉 No state file — you will be prompted like script.sh"; \
		./cleanup-aws.sh; \
	fi


# -------------------------------------
# Install Targets

install-loki:
	helm upgrade --install loki $(CHART_loki) \
		--version $(VERSION_loki) \
		-n $(NAMESPACE_loki) \
		--values $(VALUES_loki) \
		--debug

install-tempo:
	helm upgrade --install tempo $(CHART_tempo) \
		--version $(VERSION_tempo) \
		-n $(NAMESPACE_tempo) \
		--values $(VALUES_tempo) \
		--debug

install-alloy: apply-alloy-manifests
	helm upgrade --install grafana-alloy $(CHART_alloy) \
		--version $(VERSION_alloy) \
		-n $(NAMESPACE_alloy) \
		--values $(VALUES_alloy) \
		--debug

install-mimir:
	helm upgrade --install mimir $(CHART_mimir) \
		--version $(VERSION_mimir) \
		-n $(NAMESPACE_mimir) \
		--values $(VALUES_mimir) \
		--timeout 15m \
		--debug

install-kube-prometheus-stack:
	@$(if $(strip $(CLUSTER_NAME)),echo "👉 kube-prometheus-stack: clusterName=$(CLUSTER_NAME) (from $(OBSERVABILITY_STATE_FILE) or env CLUSTER_NAME)";,echo "👉 kube-prometheus-stack: CLUSTER_NAME unset — using prometheus-values.yaml only";)
	helm upgrade --install kube-prometheus-stack $(CHART_kps) \
		-n $(NAMESPACE_kube-prometheus-stack) \
		--values $(VALUES_kps) \
		$(HELM_KPS_CLUSTER_SET) \
		--debug

install-pyroscope:
	helm upgrade --install pyroscope $(CHART_pyroscope) \
		--version $(VERSION_pyroscope) \
		-n $(NAMESPACE_pyroscope) \
		--values $(VALUES_pyroscope) \
		--debug

install-blackbox:
	helm upgrade --install prometheus-blackbox-exporter $(CHART_blackbox) \
		--version $(VERSION_blackbox) \
		-n $(NAMESPACE_blackbox) \
		--values $(VALUES_blackbox) \
		--debug

# Beyla eBPF auto-instrumentation → Alloy OTLP (requires install-alloy first)
install-beyla:
	helm upgrade --install beyla $(CHART_beyla) \
		--version $(VERSION_beyla) \
		-n $(NAMESPACE_beyla) \
		--create-namespace \
		--values $(VALUES_beyla) \
		--debug


# -------------------------------------
# Port-forward Targets
pf-grafana:
	kubectl port-forward svc/kube-prometheus-stack-grafana -n $(NAMESPACE_kube-prometheus-stack) 3000:80

pf-prometheus:
	kubectl port-forward svc/kube-prometheus-stack-prometheus -n $(NAMESPACE_kube-prometheus-stack) 9090

pf-alloy:
	kubectl port-forward svc/grafana-alloy -n $(NAMESPACE_alloy) 12345

# Faro RUM collector (browser → Alloy otelcol.receiver.faro)
pf-faro:
	kubectl port-forward svc/grafana-alloy -n $(NAMESPACE_alloy) 12347:12347

# -------------------------------------
# Uninstall Targets
uninstall-loki:
	helm uninstall loki -n $(NAMESPACE_loki) || true

uninstall-tempo:
	helm uninstall tempo -n $(NAMESPACE_tempo) || true

uninstall-mimir:
	helm uninstall mimir -n $(NAMESPACE_mimir) || true

uninstall-kube-prometheus-stack:
	helm uninstall kube-prometheus-stack -n $(NAMESPACE_kube-prometheus-stack) || true

uninstall-alloy:
	helm uninstall grafana-alloy -n $(NAMESPACE_alloy) || true

uninstall-blackbox:
	helm uninstall prometheus-blackbox-exporter -n $(NAMESPACE_blackbox) || true


uninstall-pyroscope:
	helm uninstall pyroscope -n $(NAMESPACE_pyroscope) || true

uninstall-beyla:
	helm uninstall beyla -n $(NAMESPACE_beyla) || true

uninstall:
	helm uninstall loki -n $(NAMESPACE_loki) || true
	helm uninstall tempo -n $(NAMESPACE_tempo) || true
	helm uninstall mimir -n $(NAMESPACE_mimir) || true
	helm uninstall kube-prometheus-stack -n $(NAMESPACE_kube-prometheus-stack) || true
	helm uninstall pyroscope -n $(NAMESPACE_pyroscope) || true
	helm uninstall prometheus-blackbox-exporter -n $(NAMESPACE_blackbox) || true
	helm uninstall beyla -n $(NAMESPACE_beyla) || true


# Extra cleanup

uninstall-cleanup:
	@echo "🧹 Cleaning up Kubernetes resources created by this Makefile..."

	@echo "🗑 Deleting ExternalSecrets + synced Secrets..."
	-kubectl delete externalsecret loki-basic-auth canary-basic-auth -n $(NAMESPACE_loki) || true
	-kubectl delete externalsecret mimir-basic-auth -n $(NAMESPACE_mimir) || true
	-kubectl delete externalsecret mimir-remote-write-credentials -n $(NAMESPACE_kube-prometheus-stack) || true
	-kubectl delete externalsecret alloy-remote-credentials -n $(NAMESPACE_alloy) || true
	-kubectl delete secret loki-basic-auth -n $(NAMESPACE_loki) || true
	-kubectl delete secret canary-basic-auth -n $(NAMESPACE_loki) || true
	-kubectl delete secret mimir-basic-auth -n $(NAMESPACE_mimir) || true
	-kubectl delete secret mimir-remote-write-credentials -n $(NAMESPACE_kube-prometheus-stack) || true
	-kubectl delete secret alloy-remote-credentials -n $(NAMESPACE_alloy) || true

	@echo "🗑 Deleting ConfigMaps..."
	-kubectl delete configmap alloy-config -n $(NAMESPACE_alloy) || true

	@echo "🗑 Deleting PersistentVolumeClaims..."
	-kubectl delete pvc -n $(NAMESPACE_mimir) --all --force || true
	-kubectl delete pvc -n $(NAMESPACE_loki) --all --force || true
	-kubectl delete pvc -n $(NAMESPACE_tempo) --all --force || true
	-kubectl delete pvc -n $(NAMESPACE_kube-prometheus-stack) --all --force || true
	-kubectl delete pvc -n $(NAMESPACE_pyroscope) --all --force || true
	-kubectl delete pvc -n $(NAMESPACE_blackbox) --all --force || true

	@echo "🗑 Deleting Namespaces..."
	-kubectl delete namespace $(NAMESPACE_loki) --force || true
	-kubectl delete namespace $(NAMESPACE_tempo) --force || true
	-kubectl delete namespace $(NAMESPACE_alloy) --force || true
	-kubectl delete namespace $(NAMESPACE_mimir) --force || true
	-kubectl delete namespace $(NAMESPACE_kube-prometheus-stack) --force || true
	-kubectl delete namespace $(NAMESPACE_pyroscope) --force || true
	-kubectl delete namespace $(NAMESPACE_blackbox) --force || true
	-kubectl delete namespace $(NAMESPACE_beyla) --force || true
	@echo "✅ Cleanup done."

uninstall-all: uninstall uninstall-alloy uninstall-pyroscope uninstall-blackbox uninstall-beyla uninstall-cleanup


# -------------------------------------
# Status Targets

status-%:
	kubectl get all -n $(NAMESPACE_$*) || true


# -------------------------------------
# Logs Targets

logs-%:
	kubectl logs -n $(NAMESPACE_$*) --tail=50 -l app.kubernetes.io/name=$* || true

# -------------------------------------
# Template Debug Targets
# Explicit kube-prometheus-stack target: pattern rule cannot use CHART_kube-prometheus-stack (hyphen parses as minus).

template-debug-kube-prometheus-stack:
	helm template kube-prometheus-stack $(CHART_kps) -n $(NAMESPACE_kube-prometheus-stack) --values $(VALUES_kps) $(HELM_KPS_CLUSTER_SET) --debug

template-debug-%:
	helm template $* $(CHART_$*) -n $(NAMESPACE_$*) --values $(VALUES_$*) --debug


# -------------------------------------
# Batch commands

install: init install-mimir install-kube-prometheus-stack install-loki install-tempo install-alloy install-pyroscope install-blackbox install-beyla
status: status-loki status-tempo status-alloy status-mimir status-kube-prometheus-stack status-pyroscope status-blackbox status-beyla
logs: logs-loki logs-tempo logs-alloy logs-mimir logs-kube-prometheus-stack logs-pyroscope logs-blackbox logs-beyla
template-debug: template-debug-loki template-debug-tempo template-debug-alloy template-debug-mimir template-debug-kube-prometheus-stack template-debug-pyroscope template-debug-blackbox template-debug-beyla

# -------------------------------------


# =====================================================================
# ==================== External Secrets Operator ======================
# =====================================================================

AWS_PAGER              ?=                                     # avoid "press q"
ESO_NAMESPACE          ?= external-secrets
ESO_HELM_REPO          ?= https://charts.external-secrets.io
ESO_CHART              ?= external-secrets
ESO_HELM_RELEASE       ?= external-secrets

# The ServiceAccount the controller uses (chart default is "external-secrets")
ESO_SERVICE_ACCOUNT    ?= external-secrets

# IRSA for ESO controller -> access to AWS Secrets Manager
ESO_ROLE_NAME          ?= ESOControllerServiceAccountRole
ESO_POLICY_NAME        ?= ESOSecretsManagerAccessPolicy


# =====================================================================
# ==================== External Secrets Operator ======================
# =====================================================================

eso-init:
	@echo "👉 Adding ESO repo and preparing namespace"
	@AWS_PAGER="" helm repo add external-secrets $(ESO_HELM_REPO) 2>/dev/null || true
	@AWS_PAGER="" helm repo update
	@if ! kubectl get namespace $(ESO_NAMESPACE) >/dev/null 2>&1; then \
	  echo "✅ Creating namespace $(ESO_NAMESPACE)"; \
	  kubectl create namespace $(ESO_NAMESPACE); \
	fi

eso-install:
	@echo "🚀 Installing/Upgrading External Secrets Operator via Helm"
	@AWS_PAGER="" helm upgrade --install $(ESO_HELM_RELEASE) external-secrets/$(ESO_CHART) \
	  -n $(ESO_NAMESPACE) \
	  --set installCRDs=true \
	  --set serviceAccount.create=true \
	  --set serviceAccount.name=$(ESO_SERVICE_ACCOUNT)
	@kubectl rollout status deploy/$(ESO_HELM_RELEASE) -n $(ESO_NAMESPACE) --timeout=3m || true

eso-status:
	@kubectl -n $(ESO_NAMESPACE) get deploy,pods || true
	@kubectl api-resources | grep -E '^externalsecrets|^secretstores|^clustersecretstores' || true

eso-uninstall:
	@echo "🗑  Uninstalling ESO (leaves IRSA/IAM intact)"
	-@helm uninstall $(ESO_HELM_RELEASE) -n $(ESO_NAMESPACE) 2>/dev/null || true

# ---------------- IRSA for ESO controller SA ----------------
eso-iam-role:
	@echo "🔍 Ensuring ESO IRSA Role"
	@if [ -z "$(CLUSTER)" ] || [ -z "$(REGION)" ]; then \
		echo "ERROR: CLUSTER and REGION required (from env or $(OBSERVABILITY_STATE_FILE) cluster_name / region_name)"; \
		exit 1; \
	fi
	@account_id=$$(AWS_PAGER="" aws sts get-caller-identity --query Account --output text); \
	oidc=$$(AWS_PAGER="" aws eks describe-cluster --name "$(CLUSTER)" --region "$(REGION)" --query "cluster.identity.oidc.issuer" --output text); \
	idp_id=$$(echo $$oidc | awk -F '/' '{print $$NF}'); \
	mkdir -p $(TMP_DIR); \
	printf '%s' '{ "Version": "2012-10-17", "Statement": [ { "Effect": "Allow", "Principal": { "Federated": "arn:aws:iam::'$$account_id':oidc-provider/oidc.eks.$(REGION).amazonaws.com/id/'$$idp_id'" }, "Action": "sts:AssumeRoleWithWebIdentity", "Condition": { "StringEquals": { "oidc.eks.$(REGION).amazonaws.com/id/'$$idp_id':sub": "system:serviceaccount:$(ESO_NAMESPACE):$(ESO_SERVICE_ACCOUNT)", "oidc.eks.$(REGION).amazonaws.com/id/'$$idp_id':aud": "sts.amazonaws.com" } } } ] }' > "$(TMP_DIR)/eso-trust.json"; \
	if AWS_PAGER="" aws iam get-role --role-name "$(ESO_ROLE_NAME)" >/dev/null 2>&1; then \
	  echo "✅ Role exists: $(ESO_ROLE_NAME)"; \
	else \
	  AWS_PAGER="" aws iam create-role --role-name "$(ESO_ROLE_NAME)" --assume-role-policy-document file://$(TMP_DIR)/eso-trust.json >/dev/null; \
	  echo "📌 Created role: $(ESO_ROLE_NAME)"; \
	fi

eso-iam-policy:
	@echo "🔧 Ensuring ESO Secrets Manager policy"
	@printf '%s' '{ "Version": "2012-10-17", "Statement": [ { "Effect": "Allow", "Action": [ "secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret", "secretsmanager:ListSecrets" ], "Resource": "*" } ] }' > "$(TMP_DIR)/eso-sm-policy.json"
	@account_id=$$(AWS_PAGER="" aws sts get-caller-identity --query Account --output text); \
	policy_arn=arn:aws:iam::$$account_id:policy/$(ESO_POLICY_NAME); \
	if AWS_PAGER="" aws iam get-policy --policy-arn $$policy_arn >/dev/null 2>&1; then \
	  echo "✅ Policy exists: $(ESO_POLICY_NAME)"; \
	else \
	  AWS_PAGER="" aws iam create-policy --policy-name "$(ESO_POLICY_NAME)" --policy-document file://$(TMP_DIR)/eso-sm-policy.json >/dev/null; \
	  echo "📌 Created policy: $(ESO_POLICY_NAME)"; \
	fi

eso-iam-attach:
	@echo "🔗 Attaching ESO policy to role"
	@account_id=$$(AWS_PAGER="" aws sts get-caller-identity --query Account --output text); \
	policy_arn=arn:aws:iam::$$account_id:policy/$(ESO_POLICY_NAME); \
	if AWS_PAGER="" aws iam list-attached-role-policies --role-name "$(ESO_ROLE_NAME)" | grep -q "$(ESO_POLICY_NAME)"; then \
	  echo "✅ Policy already attached"; \
	else \
	  AWS_PAGER="" aws iam attach-role-policy --role-name "$(ESO_ROLE_NAME)" --policy-arn $$policy_arn >/dev/null; \
	  echo "📌 Attached policy $(ESO_POLICY_NAME) to role $(ESO_ROLE_NAME)"; \
	fi

eso-sa-annotate:
	@echo "🏷  Annotating $(ESO_NAMESPACE)/$(ESO_SERVICE_ACCOUNT) with IRSA role ARN"
	@account_id=$$(aws sts get-caller-identity --query Account --output text); \
	role_arn=$$(printf 'arn:aws:iam::%s:role/%s' "$$account_id" "$(ESO_ROLE_NAME)"); \
	kubectl -n "$(ESO_NAMESPACE)" annotate sa "$(ESO_SERVICE_ACCOUNT)" \
	  eks.amazonaws.com/role-arn="$$role_arn" --overwrite

eso-check-store:
	@echo "🔎 ClusterSecretStores"
	@kubectl get clustersecretstores.external-secrets.io -o wide || true
	@echo "🔎 ExternalSecrets"
	@kubectl get externalsecrets.external-secrets.io -A || true

# Seed AWS Secrets Manager (no .htpasswd written to the repo)
eso-seed:
	@chmod +x ./external-secrets/seed-aws-secrets.sh
	@REGION="$(REGION)" ESO_SECRET_PREFIX="$(ESO_SECRET_PREFIX)" ./external-secrets/seed-aws-secrets.sh

# Apply ClusterSecretStore + ExternalSecrets; wait until synced
eso-apply:
	@if [ -z "$(REGION)" ]; then \
		echo "ERROR: REGION unset. Export REGION or run script.sh so $(OBSERVABILITY_STATE_FILE) has region_name="; \
		exit 1; \
	fi
	@echo "👉 Applying ClusterSecretStore (region=$(REGION))"
	@sed "s/__AWS_REGION__/$(REGION)/g" ./external-secrets/cluster-secret-store.yaml | kubectl apply -f -
	@echo "👉 Applying ExternalSecrets"
	@kubectl apply -f ./external-secrets/externalsecret-loki-basic-auth.yaml
	@kubectl apply -f ./external-secrets/externalsecret-canary-basic-auth.yaml
	@kubectl apply -f ./external-secrets/externalsecret-mimir-basic-auth.yaml
	@kubectl apply -f ./external-secrets/externalsecret-alloy-remote-credentials.yaml
	@kubectl apply -f ./external-secrets/externalsecret-mimir-remote-write.yaml
	@$(MAKE) eso-wait

eso-wait:
	@echo "⏳ Waiting for ExternalSecrets to become Ready..."
	@kubectl wait --for=condition=Ready externalsecret/loki-basic-auth -n $(NAMESPACE_loki) --timeout=180s
	@kubectl wait --for=condition=Ready externalsecret/canary-basic-auth -n $(NAMESPACE_loki) --timeout=180s
	@kubectl wait --for=condition=Ready externalsecret/mimir-basic-auth -n $(NAMESPACE_mimir) --timeout=180s
	@kubectl wait --for=condition=Ready externalsecret/alloy-remote-credentials -n $(NAMESPACE_alloy) --timeout=180s
	@kubectl wait --for=condition=Ready externalsecret/mimir-remote-write-credentials -n $(NAMESPACE_kube-prometheus-stack) --timeout=180s
	@echo "✅ ExternalSecrets synced"

# Operator + IRSA (does not create ClusterSecretStore — use eso-apply)
external-secrets: eso-init eso-iam-role eso-iam-policy eso-iam-attach eso-install eso-sa-annotate eso-status



# Help Target

help:
	@echo ""
	@echo "🚀 LGTM Stack Deployment Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make aws-plan / aws-apply  - Terragrunt plan/apply observability S3 + IRSA (replaces script.sh)"
	@echo "  make render-helm-values    - Re-render Helm overrides + state file from Terragrunt outputs"
	@echo "  make aws-destroy           - Terragrunt destroy observability stack"
	@echo "  make external-secrets      - Install ESO + IRSA for AWS Secrets Manager"
	@echo "  make eso-seed              - Create/update SM secrets (htpasswd generated in-memory)"
	@echo "  make eso-apply             - Apply ClusterSecretStore + ExternalSecrets and wait"
	@echo "  make init                  - aws-apply + namespaces + eso-apply (no local .htpasswd)"
	@echo "  make apply-alloy-manifests - Alias for eso-apply (credentials via ESO)"
	@echo "  make aws-cleanup-dry-run   - List S3/IAM from state file (legacy cleanup-aws.sh)"
	@echo "  make aws-cleanup           - Delete those AWS resources (type DELETE to confirm)"
	@echo "  make install               - Install all components (incl. Beyla after Alloy)"
	@echo "  make install-loki          - Helm upgrade Loki"
	@echo "  make install-alloy         - eso-apply + Helm upgrade Alloy (includes Faro receiver :12347)"
	@echo "  make install-beyla         - Beyla eBPF DaemonSet → Alloy OTLP"
	@echo "  make pf-faro               - Port-forward Alloy Faro collector (browser RUM)"
	@echo "  make uninstall             - Uninstall core charts (+ beyla)"
	@echo "  make uninstall-alloy       - Uninstall Alloy separately"
	@echo "  make uninstall-beyla       - Uninstall Beyla"
	@echo "  make uninstall-cleanup     - Delete ExternalSecrets/Secrets, ConfigMap, Namespaces"
	@echo "  make uninstall-all         - Uninstall everything + cleanup"
	@echo "  make status                - Show status of all components"
	@echo "  make logs                  - Show logs for all components"
	@echo "  make logs-<component>      - Tail logs of a component (e.g. logs-loki)"
	@echo "  make template-debug        - Render Helm templates for all components"
	@echo "  make template-debug-<comp> - Debug Helm templates for a component"
	@echo ""
	@echo "Faro RUM / Beyla eBPF:"
	@echo "  - Faro: Alloy otelcol.receiver.faro on :12347 → Tempo + Loki tenant frontend"
	@echo "  - Example SDK page: faro/faro-web-sdk.example.html (use make pf-faro)"
	@echo "  - Beyla: beyla/beyla-values.yaml exports OTLP to grafana-alloy.alloy-logs:4317"
	@echo ""
	@echo "kube-prometheus-stack cluster label:"
	@echo "  After make init, cluster_name from .observability-poc-aws.state is passed as Helm clusterName."
	@echo "  Override: CLUSTER_NAME=my-eks make install-kube-prometheus-stack"
	@echo ""
	@echo "Secrets (External Secrets Operator):"
	@echo "  1) make external-secrets"
	@echo "  2) make eso-seed          # writes ONLY to AWS Secrets Manager"
	@echo "  3) make init              # or: make eso-apply"
	@echo "  Secret names: $(ESO_SECRET_PREFIX)/{loki-basic-auth,mimir-basic-auth,loki-canary,"
	@echo "                alloy-remote-credentials,mimir-remote-write}"
	@echo "  Do not commit .htpasswd or Kubernetes Secret YAML with credentials."
	@echo ""
	@echo "Loki multi-tenant + Grafana:"
	@echo "  - After changing Loki values: make install-loki"
	@echo "  - In each Grafana Loki datasource, add HTTP header X-Scope-OrgID (e.g. monitoring, default)"
	@echo "    or create one datasource per tenant."
	@echo ""
	@echo "Examples:"
	@echo "  make aws-plan && make aws-apply"
	@echo "  make external-secrets && make eso-seed && make init && make install"
	@echo "  make install-loki"
	@echo "  make aws-destroy                              # preferred teardown"
	@echo "  make aws-cleanup-dry-run && make aws-cleanup   # legacy state-file teardown"
	@echo "  make logs-tempo"
	@echo "  make template-debug-mimir"
	@echo ""
