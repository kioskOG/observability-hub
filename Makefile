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

# -------------------------------------
# Chart sources

CHART_loki  = grafana/loki
CHART_tempo = grafana/tempo-distributed
CHART_alloy = grafana/alloy
CHART_mimir = grafana/mimir-distributed
CHART_kps   = ./kube-prometheus-stack
CHART_pyroscope = grafana/pyroscope
CHART_blackbox = prometheus-community/prometheus-blackbox-exporter

# -------------------------------------
# Chart versions

VERSION_loki  = 6.30.1
VERSION_tempo = 1.42.2
VERSION_alloy = 1.1.1
VERSION_mimir = 5.7.0
VERSION_pyroscope = 1.14.0
VERSION_blackbox = 11.0.0

# -------------------------------------
# Values files

VALUES_loki  = ./loki/loki-override-values.yaml
VALUES_tempo = ./tempo/tempo-override-values.yaml
VALUES_alloy = ./alloy/alloy-override-values.yaml
VALUES_mimir = ./mimir/mimir-override-values.yaml
VALUES_kps   = ./kube-prometheus-stack/prometheus-values.yaml
VALUES_pyroscope = ./pyroscope/pyroscope-override-values.yaml
VALUES_blackbox = ./blackbox-exporter/values.yaml


# -------------------------------------
# Helm repo & namespace bootstrap

init:
	@./script.sh

	@kubectl apply -f ./default-storage-class.yaml

	@echo "👉 Adding Helm repo if missing and updating..."
	@helm repo add grafana https://grafana.github.io/helm-charts || true
	@helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	@helm repo update

	@echo "👉 Ensuring required namespaces exist..."
	@for ns in $(NAMESPACE_loki) $(NAMESPACE_tempo) $(NAMESPACE_alloy) $(NAMESPACE_mimir) $(NAMESPACE_kube-prometheus-stack) $(NAMESPACE_pyroscope) $(NAMESPACE_blackbox); do \
		if ! kubectl get namespace $$ns > /dev/null 2>&1; then \
			echo "✅ Creating namespace: $$ns"; \
			kubectl create namespace $$ns; \
		else \
			echo "⚙️  Namespace $$ns already exists. Skipping."; \
		fi \
	done

	@echo "👉 Ensuring Mimir basic auth secret for Nginx ingress is applied..."
	@kubectl create secret generic mimir-basic-auth --from-file=mimir/.htpasswd -n mimir --dry-run=client -o yaml | kubectl apply -f -

	@echo "👉 Applying Mimir secret for Prometheus remote_write"
	@kubectl apply -f mimir/mimir-secret-for-prometheus.yaml


	@echo "👉 Creating Loki basic auth secrets"
	@kubectl create secret generic loki-basic-auth --from-file=loki/.htpasswd -n loki --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create secret generic canary-basic-auth --from-literal=username=loki-canary --from-literal=password=loki-canary -n loki --dry-run=client -o yaml | kubectl apply -f -

	@echo "✅ All initial setup complete."


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

install-alloy:
	@if ! kubectl get configmap alloy-config -n $(NAMESPACE_alloy) > /dev/null 2>&1; then \
		echo "📦 Applying alloy ConfigMap..."; \
		kubectl apply -f ./alloy/alloy-configMap.yml; \
	else \
		echo "✅ ConfigMap 'alloy-config' already exists. Skipping apply."; \
	fi

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
		--debug

install-kube-prometheus-stack:
	helm upgrade --install kube-prometheus-stack $(CHART_kps) \
		-n $(NAMESPACE_kube-prometheus-stack) \
		--values $(VALUES_kps) \
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


# -------------------------------------
# Port-forward Targets
pf-grafana:
	kubectl port-forward svc/kube-prometheus-stack-grafana -n $(NAMESPACE_kube-prometheus-stack) 3000:80

pf-prometheus:
	kubectl port-forward svc/kube-prometheus-stack-prometheus -n $(NAMESPACE_kube-prometheus-stack) 9090

pf-alloy:
	kubectl port-forward svc/grafana-alloy -n $(NAMESPACE_alloy) 12345

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

uninstall:
	helm uninstall loki -n $(NAMESPACE_loki) || true
	helm uninstall tempo -n $(NAMESPACE_tempo) || true
	helm uninstall mimir -n $(NAMESPACE_mimir) || true
	helm uninstall kube-prometheus-stack -n $(NAMESPACE_kube-prometheus-stack) || true
	helm uninstall pyroscope -n $(NAMESPACE_pyroscope) || true
	helm uninstall prometheus-blackbox-exporter -n $(NAMESPACE_blackbox) || true


# Extra cleanup

uninstall-cleanup:
	@echo "🧹 Cleaning up Kubernetes resources created by this Makefile..."

	@echo "🗑 Deleting Secrets..."
	-kubectl delete secret loki-basic-auth -n $(NAMESPACE_loki) || true
	-kubectl delete secret canary-basic-auth -n $(NAMESPACE_loki) || true
	-kubectl delete secret mimir-basic-auth -n $(NAMESPACE_mimir) || true
	-kubectl delete secret mimir-remote-write-credentials -n $(NAMESPACE_kube-prometheus-stack) || true

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
	@echo "✅ Cleanup done."

uninstall-all: uninstall uninstall-alloy uninstall-pyroscope uninstall-blackbox uninstall-cleanup


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
template-debug-%:
	helm template $* $(CHART_$*) -n $(NAMESPACE_$*) --values $(VALUES_$*) --debug


# -------------------------------------
# Batch commands

install: init install-mimir install-kube-prometheus-stack install-loki install-tempo install-alloy install-pyroscope install-blackbox
status: status-loki status-tempo status-alloy status-mimir status-kube-prometheus-stack status-pyroscope status-blackbox
logs: logs-loki logs-tempo logs-alloy logs-mimir logs-kube-prometheus-stack logs-pyroscope logs-blackbox
template-debug: template-debug-loki template-debug-tempo template-debug-alloy template-debug-mimir template-debug-kube-prometheus-stack template-debug-pyroscope template-debug-blackbox

# -------------------------------------

# Help Target

help:
	@echo ""
	@echo "🚀 LGTM Stack Deployment Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make init                  - Add Helm repos and create namespaces"
	@echo "  make install               - Install all components (loki, tempo, alloy, mimir, kube-prometheus-stack)"
	@echo "  make uninstall             - Uninstall loki, tempo, mimir, kube-prometheus-stack"
	@echo "  make uninstall-alloy       - Uninstall Alloy separately"
	@echo "  make uninstall-cleanup     - Delete Secrets, ConfigMap, Namespaces"
	@echo "  make uninstall-all         - Uninstall everything + cleanup"
	@echo "  make status                - Show status of all components"
	@echo "  make logs                  - Show logs for all components"
	@echo "  make logs-<component>      - Tail logs of a component (e.g. logs-loki)"
	@echo "  make template-debug        - Render Helm templates for all components"
	@echo "  make template-debug-<comp> - Debug Helm templates for a component"
	@echo ""
	@echo "Examples:"
	@echo "  make install-loki"
	@echo "  make logs-tempo"
	@echo "  make template-debug-mimir"
	@echo ""
