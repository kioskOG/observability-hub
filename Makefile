.DEFAULT_GOAL := help
.SECONDEXPANSION:

# -------------------------------------
# Components: namespace, Helm release, chart, version, values
# Every chart comes from an upstream repo, pinned here. Values files only hold overrides.

COMPONENTS = kube-prometheus-stack mimir loki tempo alloy alloy-events pyroscope blackbox beyla

NAMESPACE_loki  = loki
NAMESPACE_tempo = tempo
NAMESPACE_alloy = alloy-logs
NAMESPACE_alloy-events = alloy-logs
NAMESPACE_mimir = mimir
NAMESPACE_kube-prometheus-stack = monitoring
NAMESPACE_pyroscope = pyroscope
NAMESPACE_blackbox = monitoring
NAMESPACE_beyla = beyla

RELEASE_loki  = loki
RELEASE_tempo = tempo
RELEASE_alloy = grafana-alloy
RELEASE_alloy-events = grafana-alloy-events
RELEASE_mimir = mimir
RELEASE_kube-prometheus-stack = kube-prometheus-stack
RELEASE_pyroscope = pyroscope
RELEASE_blackbox = prometheus-blackbox-exporter
RELEASE_beyla = beyla

# Chart versions are declared once, in helm/Chart.yaml, and locked in helm/Chart.lock.
# `make charts` downloads exactly those archives into helm/charts/; installs use the local archive.
HUB_CHART_DIR = helm
# chart_version,<chart name>: version of that dependency in helm/Chart.yaml.
chart_version = $(shell awk '/^  - name:/{n=$$3} /^    version:/{if (n=="$1") print $$2}' $(HUB_CHART_DIR)/Chart.yaml)
chart_archive = $(HUB_CHART_DIR)/charts/$1-$(call chart_version,$1).tgz

CHART_loki  = $(call chart_archive,loki)
CHART_tempo = $(call chart_archive,tempo-distributed)
CHART_alloy = $(call chart_archive,alloy)
CHART_alloy-events = $(CHART_alloy)
CHART_mimir = $(call chart_archive,mimir-distributed)
CHART_kube-prometheus-stack = $(call chart_archive,kube-prometheus-stack)
CHART_pyroscope = $(call chart_archive,pyroscope)
CHART_blackbox = $(call chart_archive,prometheus-blackbox-exporter)
CHART_beyla = $(call chart_archive,beyla)
CHART_external-secrets = $(call chart_archive,external-secrets)

# Rendered from *-values-template.yaml by render-helm-values (git-ignored).
RENDERED_loki  = ./loki/loki-override-values.rendered.yaml
RENDERED_tempo = ./tempo/tempo-override-values.rendered.yaml
RENDERED_mimir = ./mimir/mimir-override-values.rendered.yaml
RENDERED_pyroscope = ./pyroscope/pyroscope-override-values.rendered.yaml
RENDERED_kube-prometheus-stack = ./kube-prometheus-stack/prometheus-override-values.rendered.yaml
RENDERED_ALL = $(RENDERED_loki) $(RENDERED_tempo) $(RENDERED_mimir) $(RENDERED_pyroscope) $(RENDERED_kube-prometheus-stack)

VALUES_loki  = $(RENDERED_loki)
VALUES_tempo = $(RENDERED_tempo)
VALUES_mimir = $(RENDERED_mimir)
VALUES_pyroscope = $(RENDERED_pyroscope)
VALUES_kube-prometheus-stack = ./kube-prometheus-stack/prometheus-values.yaml $(RENDERED_kube-prometheus-stack)
VALUES_alloy = ./alloy/alloy-override-values.yaml
VALUES_alloy-events = ./alloy/alloy-events-values.yaml
VALUES_blackbox = ./blackbox-exporter/values.yaml
VALUES_beyla = ./beyla/beyla-values.yaml

# Extra helm args per component.
ARGS_alloy = --set-file alloy.configMap.content=./alloy/config/daemonset.alloy
ARGS_alloy-events = --set-file alloy.configMap.content=./alloy/config/events.alloy
ARGS_kube-prometheus-stack = $(if $(strip $(CLUSTER_NAME)),--set clusterName="$(CLUSTER_NAME)",)
ARGS_mimir = --timeout 15m
ARGS_beyla = --create-namespace

# DEBUG=1 adds --debug to helm commands.
HELM_FLAGS = $(if $(DEBUG),--debug,)

# helm_args,<component>: locked chart archive, namespace, values and extra args (shared by install + template).
helm_args = $(CHART_$1) -n $(NAMESPACE_$1) $(addprefix --values ,$(VALUES_$1)) $(ARGS_$1) $(HELM_FLAGS)

# -------------------------------------
# Cluster / region resolution
RESOLVE_ENV := ./scripts/resolve-cluster-env.sh
CLUSTER_NAME := $(shell CLUSTER_NAME='$(CLUSTER_NAME)' CLUSTER='$(CLUSTER)' $(RESOLVE_ENV) cluster 2>/dev/null)
CLUSTER := $(CLUSTER_NAME)
REGION := $(shell AWS_REGION='$(AWS_REGION)' AWS_DEFAULT_REGION='$(AWS_DEFAULT_REGION)' REGION='$(REGION)' $(RESOLVE_ENV) region 2>/dev/null)
AWS_REGION := $(REGION)
TMP_DIR ?= /tmp/observability-hub-eso
ESO_SECRET_PREFIX ?= observability-hub
CLUSTER_LOWER = $(shell echo '$(CLUSTER_NAME)' | tr '[:upper:]' '[:lower:]')

show-env:
	@chmod +x $(RESOLVE_ENV)
	@$(RESOLVE_ENV) --check || true
	@echo "Make sees: CLUSTER_NAME='$(CLUSTER_NAME)' CLUSTER='$(CLUSTER)' REGION='$(REGION)'"

# Existing Terragrunt layout
TG_MLOPS_DIR   ?= terragrunt/infrastructure-live/accounts/mlops
TG_S3_DIR      ?= $(TG_MLOPS_DIR)/$(REGION)/s3
TG_IAM_ROLE_DIR ?= $(TG_MLOPS_DIR)/global/iam/role
# Bucket stacks are named {cluster_lower}-<bucket>, the same names render-observability-helm-and-state.sh puts in the values.
OBS_S3_STACKS ?= $(addprefix $(CLUSTER_LOWER)-,loki-chunks loki-ruler mimir-chunks mimir-ruler tempo-chunks pyroscope-chunks)

# Fail early when CLUSTER_NAME / REGION are unresolved or a bucket stack directory is missing.
check-s3-stacks:
	@test -n "$(CLUSTER_NAME)" -a -n "$(REGION)" || { echo "ERROR: CLUSTER_NAME/REGION unresolved (make show-env)"; exit 1; }
	@for s in $(OBS_S3_STACKS); do \
		test -d "$(TG_S3_DIR)/$$s" || { echo "ERROR: missing Terragrunt stack $(TG_S3_DIR)/$$s"; exit 1; }; \
	done

# -------------------------------------
# AWS via Terragrunt
# use -auto-approve if you don't want to Approve/Reject the apply & destroy.
# -------------------------------------

aws-plan-s3: check-s3-stacks
	@for s in $(OBS_S3_STACKS); do \
		echo "👉 plan s3/$$s"; \
		(cd $(TG_S3_DIR)/$$s && terragrunt plan); \
	done

aws-plan-iam:
	@echo "👉 plan global/iam/role"
	@cd $(TG_IAM_ROLE_DIR) && terragrunt plan

aws-plan: aws-plan-s3 aws-plan-iam

aws-apply-s3: check-s3-stacks
	@for s in $(OBS_S3_STACKS); do \
		echo "👉 apply s3/$$s"; \
		(cd $(TG_S3_DIR)/$$s && terragrunt apply ); \
	done

aws-apply-iam:
	@echo "👉 apply global/iam/role (includes observability IRSA)"
	@cd $(TG_IAM_ROLE_DIR) && terragrunt apply
	@$(MAKE) render-helm-values

aws-apply: aws-apply-s3 aws-apply-iam

aws-destroy-s3: check-s3-stacks
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

# -------------------------------------
# Charts (helm/Chart.yaml + helm/Chart.lock)

helm-repos:
	@helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
	@helm repo add external-secrets https://charts.external-secrets.io >/dev/null 2>&1 || true

# Download the locked chart archives into helm/charts/.
charts: helm-repos
	helm dependency build $(HUB_CHART_DIR)

# After changing a version in helm/Chart.yaml: re-resolve, rewrite Chart.lock, download. Commit both files.
charts-update: helm-repos
	helm dependency update $(HUB_CHART_DIR)

# Show what is pinned.
charts-list:
	@helm dependency list $(HUB_CHART_DIR)

# An archive is fetched only when missing: its name carries the version, so bumping a version in
# helm/Chart.yaml (+ make charts-update) is what triggers a download. Output goes to stderr so that
# template-debug-* stays clean YAML.
$(HUB_CHART_DIR)/charts/%.tgz:
	@$(MAKE) charts >&2

init: charts
	@kubectl apply -f ./default-storage-class.yaml
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

# Rendered values are rebuilt when their template changes. Run `make render-helm-values` yourself after
# Terragrunt outputs change (bucket names, IRSA roles, Keycloak endpoints); `make install` always does.
%-override-values.rendered.yaml: %-values-template.yaml
	@$(MAKE) render-helm-values

install-kube-prometheus-stack: $(CHART_kube-prometheus-stack) $(RENDERED_kube-prometheus-stack)
	@echo "👉 kube-prometheus-stack: clusterName=$(if $(strip $(CLUSTER_NAME)),$(CLUSTER_NAME),<unset: chart default>)"
	helm upgrade --install $(RELEASE_kube-prometheus-stack) $(call helm_args,kube-prometheus-stack)

install-mimir: $(CHART_mimir) $(RENDERED_mimir)
	helm upgrade --install $(RELEASE_mimir) $(call helm_args,mimir)

install-loki: $(CHART_loki) $(RENDERED_loki)
	helm upgrade --install $(RELEASE_loki) $(call helm_args,loki)

install-tempo: $(CHART_tempo) $(RENDERED_tempo)
	helm upgrade --install $(RELEASE_tempo) $(call helm_args,tempo)

install-pyroscope: $(CHART_pyroscope) $(RENDERED_pyroscope)
	helm upgrade --install $(RELEASE_pyroscope) $(call helm_args,pyroscope)

install-alloy: $(CHART_alloy) apply-alloy-manifests
	helm upgrade --install $(RELEASE_alloy) $(call helm_args,alloy)

# Single-replica Kubernetes events collector (events must not be collected by the DaemonSet: N× duplicates).
install-alloy-events: $(CHART_alloy-events) apply-alloy-manifests
	helm upgrade --install $(RELEASE_alloy-events) $(call helm_args,alloy-events)

install-blackbox: $(CHART_blackbox)
	helm upgrade --install $(RELEASE_blackbox) $(call helm_args,blackbox)

install-beyla: $(CHART_beyla)
	helm upgrade --install $(RELEASE_beyla) $(call helm_args,beyla)

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
uninstall-%:
	helm uninstall $(RELEASE_$*) -n $(NAMESPACE_$*) || true

# Reverse install order: collectors first, backends last.
uninstall: uninstall-beyla uninstall-blackbox uninstall-pyroscope uninstall-alloy-events uninstall-alloy \
	uninstall-tempo uninstall-loki uninstall-mimir uninstall-kube-prometheus-stack

OBS_NAMESPACES = $(sort $(foreach c,$(COMPONENTS),$(NAMESPACE_$(c))))

# Extra cleanup: ExternalSecrets, PVCs + their EBS volumes, namespaces. DESTRUCTIVE (telemetry in PVCs is lost).
# gp2-standard has reclaimPolicy: Retain, so deleting a PVC alone leaves the PV and its EBS volume behind.
# The PVs are switched to Delete first so the EBS CSI driver removes the volumes.
uninstall-cleanup:
	@echo "🧹 Cleaning up Kubernetes resources created by this Makefile..."
	@echo "🗑 Deleting ExternalSecrets (ESO then removes the synced Secrets)..."
	-kubectl delete externalsecret loki-basic-auth canary-basic-auth loki-ruler-mimir-remote-write -n $(NAMESPACE_loki) --ignore-not-found
	-kubectl delete externalsecret mimir-basic-auth -n $(NAMESPACE_mimir) --ignore-not-found
	-kubectl delete externalsecret mimir-remote-write-credentials grafana-auth-secrets grafana-admin-credentials -n $(NAMESPACE_kube-prometheus-stack) --ignore-not-found
	-kubectl delete externalsecret alloy-remote-credentials -n $(NAMESPACE_alloy) --ignore-not-found
	-kubectl delete externalsecret tempo-mimir-remote-write -n $(NAMESPACE_tempo) --ignore-not-found
	@echo "🗑 Releasing PersistentVolumes (reclaimPolicy → Delete) and deleting PVCs..."
	@for ns in $(OBS_NAMESPACES); do \
		for pv in $$(kubectl get pvc -n $$ns -o jsonpath='{.items[*].spec.volumeName}' 2>/dev/null); do \
			kubectl patch pv $$pv -p '{"spec":{"persistentVolumeReclaimPolicy":"Delete"}}' >/dev/null && echo "   $$ns: $$pv → Delete"; \
		done; \
		kubectl delete pvc -n $$ns --all --wait=false --ignore-not-found; \
	done
	@echo "🗑 Deleting Namespaces..."
	-kubectl delete namespace $(OBS_NAMESPACES) --ignore-not-found
	@echo "✅ Cleanup done. Check for leftovers: kubectl get pv | grep Released"

uninstall-all: uninstall uninstall-cleanup

# -------------------------------------
# Status & Logs
status-%:
	kubectl get all -n $(NAMESPACE_$*) || true

# Pods of one release (the chart's app.kubernetes.io/instance label), every container.
logs-%:
	kubectl logs -n $(NAMESPACE_$*) -l app.kubernetes.io/instance=$(RELEASE_$*) \
		--all-containers --prefix --tail=50 --max-log-requests=20 || true

template-debug-%: $$(CHART_$$*)
	helm template $(RELEASE_$*) $(call helm_args,$*)

# render-helm-values first: Terragrunt outputs (buckets, IRSA, Keycloak) may have changed since the last render.
install: render-helm-values init $(addprefix install-,$(COMPONENTS))
status: $(addprefix status-,$(COMPONENTS))
logs: $(addprefix logs-,$(COMPONENTS))
template-debug: $(addprefix template-debug-,$(COMPONENTS))

# =====================================================================
# ==================== External Secrets Operator ======================
# =====================================================================

AWS_PAGER              ?=                                     # avoid "press q"
ESO_NAMESPACE          ?= external-secrets
ESO_HELM_REPO          ?= https://charts.external-secrets.io
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

eso-install: $(CHART_external-secrets)
	@echo "🚀 Installing/Upgrading External Secrets Operator via Helm (consuming Terragrunt outputs)"
	@ESO_ROLE_ARN=$$(cd $(TG_IAM_ROLE_DIR) && terragrunt output -json | jq -r '.iam_role_arns.value.ESOControllerServiceAccountRole' 2>/dev/null); \
	echo "👉 ESO IRSA Role ARN: $$ESO_ROLE_ARN"; \
	if [ -z "$$ESO_ROLE_ARN" ] || [ "$$ESO_ROLE_ARN" = "null" ]; then echo "ERROR: Could not fetch ESO_ROLE_ARN from Terragrunt."; exit 1; fi; \
	AWS_PAGER="" helm upgrade --install $(ESO_HELM_RELEASE) $(CHART_external-secrets) \
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
	@ENVIRONMENT="$(ENVIRONMENT)" REGION="$(REGION)" ESO_SECRET_PREFIX="$(ESO_SECRET_PREFIX)" ./external-secrets/seed-aws-secrets.sh

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
	@for ns in $(NAMESPACE_loki) $(NAMESPACE_mimir) $(NAMESPACE_alloy) $(NAMESPACE_kube-prometheus-stack) $(NAMESPACE_tempo); do \
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
	@kubectl apply -f ./external-secrets/externalsecret-grafana-admin.yaml
	@kubectl apply -f ./external-secrets/externalsecret-tempo-mimir-remote-write.yaml
	@kubectl apply -f ./external-secrets/externalsecret-loki-ruler-mimir-remote-write.yaml
	@$(MAKE) eso-wait

eso-wait:
	@echo "⏳ Waiting for ExternalSecrets to become Ready..."
	@kubectl wait --for=condition=Ready externalsecret/loki-basic-auth -n $(NAMESPACE_loki) --timeout=180s
	@kubectl wait --for=condition=Ready externalsecret/canary-basic-auth -n $(NAMESPACE_loki) --timeout=180s
	@kubectl wait --for=condition=Ready externalsecret/mimir-basic-auth -n $(NAMESPACE_mimir) --timeout=180s
	@kubectl wait --for=condition=Ready externalsecret/alloy-remote-credentials -n $(NAMESPACE_alloy) --timeout=180s
	@kubectl wait --for=condition=Ready externalsecret/mimir-remote-write-credentials -n $(NAMESPACE_kube-prometheus-stack) --timeout=180s
	@kubectl wait --for=condition=Ready externalsecret/grafana-auth-secrets -n $(NAMESPACE_kube-prometheus-stack) --timeout=180s
	@kubectl wait --for=condition=Ready externalsecret/grafana-admin-credentials -n $(NAMESPACE_kube-prometheus-stack) --timeout=180s
	@kubectl wait --for=condition=Ready externalsecret/tempo-mimir-remote-write -n $(NAMESPACE_tempo) --timeout=180s
	@kubectl wait --for=condition=Ready externalsecret/loki-ruler-mimir-remote-write -n $(NAMESPACE_loki) --timeout=180s
	@echo "✅ ExternalSecrets synced"
	@if kubectl get deploy kube-prometheus-stack-grafana -n $(NAMESPACE_kube-prometheus-stack) >/dev/null 2>&1; then \
	  echo "♻️  Restarting Grafana to reload datasource credentials..."; \
	  kubectl rollout restart deploy/kube-prometheus-stack-grafana -n $(NAMESPACE_kube-prometheus-stack); \
	  kubectl rollout status deploy/kube-prometheus-stack-grafana -n $(NAMESPACE_kube-prometheus-stack) --timeout=3m; \
	fi

external-secrets: eso-init eso-install eso-status

# Set the Grafana local admin password to the one in Secret grafana-admin-credentials.
# GF_SECURITY_ADMIN_PASSWORD only applies when Grafana creates its database, and every replica has its
# own SQLite DB, so an existing install needs this after eso-seed (first rollout or rotation).
grafana-admin-reset:
	@pods=$$(kubectl get pods -n $(NAMESPACE_kube-prometheus-stack) -l app.kubernetes.io/name=grafana,app.kubernetes.io/instance=$(RELEASE_kube-prometheus-stack) -o name); \
	test -n "$$pods" || { echo "ERROR: no Grafana pods in $(NAMESPACE_kube-prometheus-stack)"; exit 1; }; \
	for p in $$pods; do \
		kubectl get secret grafana-admin-credentials -n $(NAMESPACE_kube-prometheus-stack) -o jsonpath='{.data.admin-password}' | base64 -d | \
		kubectl exec -i -n $(NAMESPACE_kube-prometheus-stack) $$p -c grafana -- grafana cli admin reset-admin-password --password-from-stdin >/dev/null \
		&& echo "✅ $$p: admin password reset" || { echo "ERROR: reset failed on $$p"; exit 1; }; \
	done

help:
	@echo "🚀 Observability Hub Deployment Makefile"
	@echo "  Install order (see README 'Complete installation'):"
	@echo "  make show-env                      - Resolved CLUSTER_NAME / REGION"
	@echo "  make aws-apply                     - S3 + IRSA via Terragrunt, then render-helm-values"
	@echo "  make external-secrets              - Deploy ESO using Terragrunt IAM outputs"
	@echo "  make eso-seed ENVIRONMENT=<env>    - Create/rotate gateway credentials (env: prod|stage|dev)"
	@echo "  make install                       - init (ExternalSecrets) + every component"
	@echo ""
	@echo "  make install-<component>           - Upgrade one component"
	@echo "  make charts-list / charts-update   - Pinned charts (helm/Chart.yaml + Chart.lock)"
	@echo "  make render-helm-values            - Re-render *-values-template.yaml"
	@echo "  make grafana-admin-reset          - Apply the Secrets Manager admin password to Grafana"
	@echo "  make status / logs / eso-check-store"
	@echo "  make uninstall-all                 - Helm uninstall + delete PVCs/namespaces"
	@echo "  make aws-destroy                   - Terragrunt destroy S3 + IRSA (data loss)"
