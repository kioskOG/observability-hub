# kube-prometheus-stack

Prometheus Operator, Prometheus (2 replicas, remote-write to Mimir), Grafana (Keycloak SSO, Loki/Mimir/Tempo/Pyroscope datasources), Alertmanager (the stack's only one), kube-state-metrics and node-exporter.

The chart is the upstream `prometheus-community/kube-prometheus-stack`, pinned in [`helm/Chart.yaml`](../helm/Chart.yaml) and locked in `helm/Chart.lock`. This directory holds only values:

| File | Purpose |
|------|---------|
| `prometheus-values.yaml` | Overrides of the chart defaults: placement, resources, Prometheus HA + remote write, Grafana datasources and plugins, Alertmanager. Keep it to settings that differ from `helm show values helm/charts/kube-prometheus-stack-<version>.tgz` |
| `prometheus-values-template.yaml` | Grafana SSO (`auth.generic_oauth`, `root_url`), rendered by `make render-helm-values` into `prometheus-override-values.rendered.yaml` (git-ignored) |

## Install / upgrade

```bash
make install-kube-prometheus-stack            # helm upgrade --install with both values files + clusterName
make template-debug-kube-prometheus-stack     # same args, helm template
```

`clusterName` is set from the resolved `CLUSTER_NAME` (`make show-env`) and becomes Prometheus's `cluster` external label. It must match Alloy's `KUBE_CLUSTER_NAME`.

## Access

```bash
make pf-grafana        # http://localhost:3000
make pf-prometheus     # http://localhost:9090
```

Log in to Grafana with Keycloak SSO; see [`../Docs/Grafana-SSO-Production.md`](../Docs/Grafana-SSO-Production.md).

## Alerting

Every alert source (Prometheus, the Loki ruler, the Mimir ruler) sends to this Alertmanager. No receivers are configured yet: the chart default routes everything to `null`. Configure `alertmanager.config` in `prometheus-values.yaml`, and keep receiver credentials in a Secret.

## Upgrading the chart

1. Read the chart's upgrade notes. Helm installs the operator CRDs on first install but never upgrades them, so apply new CRDs as those notes describe before upgrading.
2. Bump its `version` in `helm/Chart.yaml`, run `make charts-update`, and commit `Chart.yaml` + `Chart.lock`.
3. `make template-debug-kube-prometheus-stack` and review the diff, then `make install-kube-prometheus-stack`.
