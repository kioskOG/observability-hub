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
VERSION_alloy = 1.2.1
VERSION_mimir = 5.7.0
VERSION_pyroscope = 1.14.0
VERSION_blackbox = 11.0.0
VERSION_beyla = 1.16.8

# -------------------------------------
# -------------------------------------
# Values files

VALUES_loki  = ./loki/loki-override-values.rendered.yaml
VALUES_tempo = ./tempo/tempo-override-values.rendered.yaml
VALUES_alloy = ./alloy/alloy-override-values.yaml
VALUES_mimir = ./mimir/mimir-override-values.rendered.yaml
VALUES_kps   = ./kube-prometheus-stack/prometheus-values.yaml
VALUES_kps_override = ./kube-prometheus-stack/prometheus-override-values.rendered.yaml
VALUES_pyroscope = ./pyroscope/pyroscope-override-values.rendered.yaml
VALUES_blackbox = ./blackbox-exporter/values.yaml
VALUES_beyla = ./beyla/beyla-values.yaml

# -------------------------------------
# Cluster / region resolution
RESOLVE_ENV := ./scripts/resolve-cluster-env.sh
CLUSTER_NAME := $(shell CLUSTER_NAME='$(CLUSTER_NAME)' CLUSTER='$(CLUSTER)' $(RESOLVE_ENV) cluster 2>/dev/null)
CLUSTER := $(CLUSTER_NAME)
REGION := $(shell AWS_REGION='$(AWS_REGION)' AWS_DEFAULT_REGION='$(AWS_DEFAULT_REGION)' REGION='$(REGION)' $(RESOLVE_ENV) region 2>/dev/null)
AWS_REGION := $(REGION)
TMP_DIR ?= /tmp/observability-hub-eso
ESO_SECRET_PREFIX ?= observability-hub
HELM_KPS_CLUSTER_SET = $(if $(strip $(CLUSTER_NAME)),--set clusterName="$(CLUSTER_NAME)",)

show-env:
	@chmod +x $(RESOLVE_ENV)
	@$(RESOLVE_ENV) --check || true
	@echo "Make sees: CLUSTER_NAME='$(CLUSTER_NAME)' CLUSTER='$(CLUSTER)' REGION='$(REGION)'"

# Existing Terragrunt layout
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
# AWS via Terragrunt
# use -auto-approve if you don't want to Approve/Reject the apply & destroy.
# -------------------------------------

aws-plan-s3:
	@for s in $(OBS_S3_STACKS); do \
		echo "👉 plan s3/$$s"; \
		(cd $(TG_S3_DIR)/$$s && terragrunt plan); \
	done

aws-plan-iam:
	@echo "👉 plan global/iam/role"
	@cd $(TG_IAM_ROLE_DIR) && terragrunt plan

aws-plan: aws-plan-s3 aws-plan-iam

aws-apply-s3:
	@for s in $(OBS_S3_STACKS); do \
		echo "👉 apply s3/$$s"; \
		(cd $(TG_S3_DIR)/$$s && terragrunt apply ); \
	done

aws-apply-iam:
	@echo "👉 apply global/iam/role (includes observability IRSA)"
	@cd $(TG_IAM_ROLE_DIR) && terragrunt apply
	@$(MAKE) render-helm-values

aws-apply: aws-apply-s3 aws-apply-iam

aws-destroy-s3:
	@echo "👉 destroy observability S3 buckets"
	@for s in $(OBS_S3_STACKS); do \
		echo "👉 destroy s3/$$s"; \
		(cd $(TG_S3_DIR)/$$s && terragrunt destroy); \
	done

aws-destroy-iam:
	@echo "👉 destroy observability IRSA roles first (edit iam/role inputs if you only want LGTM roles removed)"
	@echo "👉 destroy global/iam/role"
	@cd $(TG_IAM_ROLE_DIR) && terragrunt destroy

aws-destroy: aws-destroy-iam aws-destroy-s3

# Re-render Helm temporary values from Terragrunt
render-helm-values:
	@chmod +x $(TG_MLOPS_DIR)/render-observability-helm-and-state.sh
	@CLUSTER_NAME="$(CLUSTER_NAME)" AWS_REGION="$(REGION)" \
	  OBSERVABILITY_CLUSTER_NAME="$(CLUSTER_NAME)" OBSERVABILITY_CLUSTER_REGION="$(REGION)" \
	  $(TG_MLOPS_DIR)/render-observability-helm-and-state.sh "$(CURDIR)"


# -------------------------------------
# Helm repo & namespace bootstrap

init:
	@echo "👉 Provisioning AWS S3 + IRSA via Terragrunt..."
# 	@$(MAKE) aws-apply
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
		fi \
	done
	@echo "👉 Syncing basic-auth secrets via External Secrets Operator..."
	@if ! kubectl api-resources | grep -q '^clustersecretstores'; then \
		echo "ERROR: External Secrets CRDs missing. Run: make external-secrets && make eso-seed && make init"; \
		exit 1; \
	fi
	@$(MAKE) eso-apply
	@echo "✅ All initial setup complete."

apply-alloy-manifests: eso-apply

# -------------------------------------
# AWS cleanup (Deprecated)

aws-cleanup-dry-run:
	@echo "DEPRECATED: Use 'make aws-destroy' via Terragrunt instead."
	@exit 1

aws-cleanup:
	@echo "DEPRECATED: Use 'make aws-destroy' via Terragrunt instead."
	@exit 1

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
	@$(if $(strip $(CLUSTER_NAME)),echo "👉 kube-prometheus-stack: clusterName=$(CLUSTER_NAME)";,echo "👉 kube-prometheus-stack: CLUSTER_NAME unset — using prometheus-values.yaml only";)
	helm upgrade --install kube-prometheus-stack $(CHART_kps) \
		-n $(NAMESPACE_kube-prometheus-stack) \
		--values $(VALUES_kps) \
		--values $(VALUES_kps_override) \
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
# Status & Logs
status-%:
	kubectl get all -n $(NAMESPACE_$*) || true

logs-%:
	kubectl logs -n $(NAMESPACE_$*) --tail=50 -l app.kubernetes.io/name=$* || true

template-debug-kube-prometheus-stack:
	helm template kube-prometheus-stack $(CHART_kps) -n $(NAMESPACE_kube-prometheus-stack) --values $(VALUES_kps) $(HELM_KPS_CLUSTER_SET) --debug

template-debug-%:
	helm template $* $(CHART_$*) -n $(NAMESPACE_$*) --values $(VALUES_$*) --debug

install: init install-kube-prometheus-stack install-mimir install-loki install-tempo install-alloy install-pyroscope install-blackbox install-beyla
status: status-loki status-tempo status-alloy status-mimir status-kube-prometheus-stack status-pyroscope status-blackbox status-beyla
logs: logs-loki logs-tempo logs-alloy logs-mimir logs-kube-prometheus-stack logs-pyroscope logs-blackbox logs-beyla
template-debug: template-debug-loki template-debug-tempo template-debug-alloy template-debug-mimir template-debug-kube-prometheus-stack template-debug-pyroscope template-debug-blackbox template-debug-beyla

# =====================================================================
# ==================== External Secrets Operator ======================
# =====================================================================

AWS_PAGER              ?=                                     # avoid "press q"
ESO_NAMESPACE          ?= external-secrets
ESO_HELM_REPO          ?= https://charts.external-secrets.io
ESO_CHART              ?= external-secrets
ESO_HELM_RELEASE       ?= external-secrets
ESO_SERVICE_ACCOUNT    ?= external-secrets

eso-init:
	@kubectl apply -f ./default-storage-class.yaml
	@echo "👉 Adding ESO repo and preparing namespace"
	@AWS_PAGER="" helm repo add external-secrets $(ESO_HELM_REPO) 2>/dev/null || true
	@AWS_PAGER="" helm repo update
	@if ! kubectl get namespace $(ESO_NAMESPACE) >/dev/null 2>&1; then \
	  echo "✅ Creating namespace $(ESO_NAMESPACE)"; \
	  kubectl create namespace $(ESO_NAMESPACE); \
	fi

eso-install:
	@echo "🚀 Installing/Upgrading External Secrets Operator via Helm (consuming Terragrunt outputs)"
	@ESO_ROLE_ARN=$$(cd $(TG_IAM_ROLE_DIR) && terragrunt output -json | jq -r '.iam_role_arns.value.ESOControllerServiceAccountRole' 2>/dev/null); \
	echo "👉 ESO IRSA Role ARN: $$ESO_ROLE_ARN"; \
	if [ -z "$$ESO_ROLE_ARN" ] || [ "$$ESO_ROLE_ARN" = "null" ]; then echo "ERROR: Could not fetch ESO_ROLE_ARN from Terragrunt."; exit 1; fi; \
	AWS_PAGER="" helm upgrade --install $(ESO_HELM_RELEASE) external-secrets/$(ESO_CHART) \
	  -n $(ESO_NAMESPACE) \
	  --set installCRDs=true \
	  --set serviceAccount.create=true \
	  --set serviceAccount.name=$(ESO_SERVICE_ACCOUNT) \
	  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$$ESO_ROLE_ARN"
	@$(MAKE) eso-wait-crds
	@kubectl rollout status deploy/$(ESO_HELM_RELEASE) -n $(ESO_NAMESPACE) --timeout=3m || true
	@$(MAKE) eso-wait-webhook

eso-wait-crds:
	@echo "⏳ Waiting for ESO CRDs..."
	@kubectl wait --for=condition=Established crd/clustersecretstores.external-secrets.io --timeout=120s
	@kubectl wait --for=condition=Established crd/externalsecrets.external-secrets.io --timeout=120s
	@if ! kubectl api-resources --api-group=external-secrets.io 2>/dev/null | grep -q '^externalsecrets'; then \
	  echo "ERROR: ExternalSecret CRD missing from API. Run: make eso-install"; \
	  exit 1; \
	fi

eso-wait-webhook:
	@echo "⏳ Waiting for ESO validating webhook endpoints..."
	@kubectl rollout status deploy/$(ESO_HELM_RELEASE)-webhook -n $(ESO_NAMESPACE) --timeout=3m
	@i=0; \
	while [ $$i -lt 60 ]; do \
	  eps=$$(kubectl get endpoints $(ESO_HELM_RELEASE)-webhook -n $(ESO_NAMESPACE) -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true); \
	  if [ -n "$$eps" ]; then \
	    echo "✅ Webhook ready (endpoints: $$eps)"; \
	    exit 0; \
	  fi; \
	  i=$$((i+1)); \
	  sleep 2; \
	done; \
	echo "ERROR: no endpoints for service $(ESO_HELM_RELEASE)-webhook in $(ESO_NAMESPACE)"; \
	kubectl -n $(ESO_NAMESPACE) get deploy,pods,svc,endpoints || true; \
	exit 1

eso-status:
	@kubectl -n $(ESO_NAMESPACE) get deploy,pods || true
	@kubectl api-resources | grep -E '^externalsecrets|^secretstores|^clustersecretstores' || true

eso-uninstall:
	@echo "🗑  Uninstalling ESO (leaves IRSA/IAM intact)"
	-@helm uninstall $(ESO_HELM_RELEASE) -n $(ESO_NAMESPACE) 2>/dev/null || true

eso-check-store:
	@echo "🔎 ClusterSecretStores"
	@kubectl get clustersecretstores.external-secrets.io -o wide || true
	@echo "🔎 ExternalSecrets"
	@kubectl get externalsecrets.external-secrets.io -A || true

eso-seed:
	@chmod +x ./external-secrets/seed-aws-secrets.sh
	@REGION="$(REGION)" ESO_SECRET_PREFIX="$(ESO_SECRET_PREFIX)" ./external-secrets/seed-aws-secrets.sh

eso-apply:
	@chmod +x $(RESOLVE_ENV)
	@$(RESOLVE_ENV) --check >/dev/null
	@if ! kubectl get crd externalsecrets.external-secrets.io >/dev/null 2>&1; then \
		echo "ERROR: ExternalSecret CRD missing. Run: make eso-install"; \
		exit 1; \
	fi
	@if ! kubectl get crd clustersecretstores.external-secrets.io >/dev/null 2>&1; then \
		echo "ERROR: ClusterSecretStore CRD missing. Run: make eso-install"; \
		exit 1; \
	fi
	@$(MAKE) eso-wait-crds
	@$(MAKE) eso-wait-webhook
	@echo "👉 Ensuring namespaces for ExternalSecrets..."
	@for ns in $(NAMESPACE_loki) $(NAMESPACE_mimir) $(NAMESPACE_alloy) $(NAMESPACE_kube-prometheus-stack); do \
		kubectl get namespace $$ns >/dev/null 2>&1 || kubectl create namespace $$ns; \
	done
	@echo "👉 Applying ClusterSecretStore (region=$(REGION))"
	@sed "s/__AWS_REGION__/$(REGION)/g" ./external-secrets/cluster-secret-store.yaml | kubectl apply -f -
	@echo "👉 Applying ExternalSecrets"
	@kubectl apply -f ./external-secrets/externalsecret-loki-basic-auth.yaml
	@kubectl apply -f ./external-secrets/externalsecret-canary-basic-auth.yaml
	@kubectl apply -f ./external-secrets/externalsecret-mimir-basic-auth.yaml
	@kubectl apply -f ./external-secrets/externalsecret-alloy-remote-credentials.yaml
	@kubectl apply -f ./external-secrets/externalsecret-mimir-remote-write.yaml
	@kubectl apply -f ./external-secrets/externalsecret-grafana-auth.yaml
	@$(MAKE) eso-wait

eso-wait:
	@echo "⏳ Waiting for ExternalSecrets to become Ready..."
	@kubectl wait --for=condition=Ready externalsecret/loki-basic-auth -n $(NAMESPACE_loki) --timeout=180s
	@kubectl wait --for=condition=Ready externalsecret/canary-basic-auth -n $(NAMESPACE_loki) --timeout=180s
	@kubectl wait --for=condition=Ready externalsecret/mimir-basic-auth -n $(NAMESPACE_mimir) --timeout=180s
	@kubectl wait --for=condition=Ready externalsecret/alloy-remote-credentials -n $(NAMESPACE_alloy) --timeout=180s
	@kubectl wait --for=condition=Ready externalsecret/mimir-remote-write-credentials -n $(NAMESPACE_kube-prometheus-stack) --timeout=180s
	@kubectl wait --for=condition=Ready externalsecret/grafana-auth-secrets -n $(NAMESPACE_kube-prometheus-stack) --timeout=180s
	@echo "✅ ExternalSecrets synced"
	@if kubectl get deploy kube-prometheus-stack-grafana -n $(NAMESPACE_kube-prometheus-stack) >/dev/null 2>&1; then \
	  echo "♻️  Restarting Grafana to reload datasource credentials..."; \
	  kubectl rollout restart deploy/kube-prometheus-stack-grafana -n $(NAMESPACE_kube-prometheus-stack); \
	  kubectl rollout status deploy/kube-prometheus-stack-grafana -n $(NAMESPACE_kube-prometheus-stack) --timeout=3m; \
	fi

external-secrets: eso-init eso-install eso-status

help:
	@echo "🚀 Observability Hub Deployment Makefile"
	@echo "  make aws-apply           - Terragrunt apply for all infrastructure"
	@echo "  make aws-destroy         - Terragrunt destroy for all infrastructure"
	@echo "  make external-secrets    - Deploy ESO using Terragrunt IAM outputs"
	@echo "  make eso-seed            - Create AWS Secrets Manager values"
	@echo "  make install             - Deploy observability stack"
	@echo "  make uninstall           - Tear down stack"
