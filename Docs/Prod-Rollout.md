# Production rollout: observability node group, HA, de-duplication

Runbook for the change set that moves the LGTM stack onto a dedicated node group and removes
duplicate / dropped telemetry. Order matters — follow the steps top to bottom.

## What changed

| Area | Change | Why |
|---|---|---|
| EKS | New managed node group `observability`: 4 × m6i.2xlarge, label `workload=observability`, taint `dedicated=observability:NoSchedule`. Module now supports per-node-group `labels` / `taints` (applied via EKS API **and** AL2023 NodeConfig kubelet flags, because custom-AMI launch templates bypass EKS label injection). Existing `wazuh` group user data is byte-identical → no node rollover. | Stack requests ~18 vCPU / ~53 GiB; the old 2 × m5.xlarge (8 vCPU) could not schedule it. |
| All charts | `nodeSelector` + `tolerations` on every observability workload; DaemonSets (Alloy, Beyla, node-exporter, loki-canary) tolerate the taint so they still run everywhere. Requests/limits on every component; Mimir right-sized from 17.9 → 6 vCPU. | Placement + predictable scheduling. |
| Alloy | Cluster events moved to a new single-replica StatefulSet release `grafana-alloy-events` (`alloy/alloy-events-values.yaml`). Pod-log and profile discovery are node-local. Positions/WAL on hostPath `/var/lib/alloy/data`. `KUBE_CLUSTER_NAME=millenniumfalcon`, `AWS_REGION=us-east-2`. | Every DaemonSet pod used to ship every event and scrape every profile target (N× duplicates). Labels now match Prometheus. |
| Span metrics | Alloy spanmetrics `CUMULATIVE` (was `DELTA`, which `otelcol.exporter.prometheus` silently dropped — only `target_info` reached Mimir). Exposed with Tempo-compatible names (`traces_spanmetrics_calls_total`, `traces_spanmetrics_latency_*`, label `service`). Dimensions: `http.method`, `http.request.method`, `http.route` (raw `http.target` removed). | RED metrics were missing; Grafana's Tempo views expect these names. |
| Service graph | Produced only by Tempo's metrics-generator (Alloy servicegraph connector removed; Tempo `span-metrics` processor disabled; Beyla `application_span` / `application_service_graph` disabled). Alloy stamps head-sampled spans with `sampling.ratio` (double); Tempo `span_multiplier_key` scales edges by 1/ratio. | One producer per series name; edges need trace-ID sharding which only Tempo has. |
| Mimir | HA tracker on (memberlist KV), `accept_ha_samples` on `cluster` / `prometheus_replica`. Series limit 1.5M/tenant (fits 8 Gi ingesters). | 2 Prometheus replicas were stored twice. |
| Prometheus | `replicaExternalLabelName: prometheus_replica` (explicit), 50 Gi PVC, `retentionSize: 40GB`, remote-write `queueConfig` fixed (the snake_case `queue_config` was silently pruned by the CRD), remote-write receiver disabled. Alertmanager: 2 replicas + PVC. | HA de-dup contract; WAL survives restarts. |
| Tempo | Mimir credentials from ExternalSecret `tempo-mimir-remote-write` (were hard-coded `mimir-nginx`/`mimir-nginx` → 401). RF 3 / 3 ingesters. | Security + durability. |
| Loki | Ruler: S3 storage (the `storage: local` override is gone), alerts → kube-prometheus-stack Alertmanager, recording rules → Mimir (ExternalSecret `loki-ruler-mimir-remote-write`). OTLP index labels are a real list of low-cardinality attributes. RF 3 / 3 ingesters; 2 replicas on the stateless read/write path. | Ruler was storing rules on local disk with no Alertmanager. |
| Pyroscope | 3 ingesters (= ring replication factor 3). | Write quorum. |

## Rollout

1. **Node group first.** Workloads now require `workload=observability` nodes; deploying charts
   before the nodes exist leaves pods Pending.
   ```bash
   cd terragrunt/infrastructure-live/accounts/mlops/us-east-2/eks
   terragrunt plan    # expect: + node group "observability", + launch template; wazuh unchanged
   terragrunt apply
   kubectl get nodes -l workload=observability   # 4 Ready nodes, 2 per AZ
   ```
2. **Check volume zones** (EBS volumes are AZ-bound). Every existing PV must have an observability
   node in its zone — with 2 nodes per AZ this holds unless 3+ replicas of one StatefulSet share an AZ:
   ```bash
   kubectl get pv -o custom-columns=CLAIM:.spec.claimRef.name,ZONE:.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]
   ```
3. **Secrets** (creates the `tempo` namespace and the two new ExternalSecrets):
   ```bash
   make eso-apply
   ```
4. **Charts** (same order as `make install`):
   ```bash
   make render-helm-values
   make install-kube-prometheus-stack install-mimir install-loki install-tempo \
        install-alloy install-alloy-events install-pyroscope install-blackbox install-beyla
   ```

## Expected one-time effects

- **Mimir series churn.** Prometheus series stored before the change carry `prometheus_replica`;
  new ones don't. Both sets sit in ingester heads for ~2–3 h, so active series briefly peak at
  ≈ 3× the Prometheus series count. Check it stays under the 1.5M limit:
  `sum(cortex_ingester_active_series)` before rollout × 3.
- **Prometheus / Alertmanager pods are recreated** (emptyDir → PVC). Local TSDB is discarded;
  everything up to that point is already in Mimir. Expect a scrape gap of a minute or two.
- **Alloy re-reads current log files once** on the first rollout (positions move to the hostPath).
  This is what every previous rollout already did with emptyDir; from now on positions persist.
- **Events:** the events release lists the last hour of events on first start, so recent events
  appear twice once.
- **Span-metric label changes:** `http_target` is gone, `http_route` / `service` are new; histogram
  buckets changed. Nothing in this repo queries the old labels.

## Verify

```bash
make pf-grafana   # then in Grafana → Explore (Mimir):
```
| Check | Query / place | Expect |
|---|---|---|
| Placement | `kubectl get pods -A -o wide \| grep -E 'loki\|mimir\|tempo\|pyroscope\|monitoring'` | all on observability nodes |
| HA de-dup | `count by (prometheus_replica) (up{job="apiserver"})` | one series, no `prometheus_replica` label |
| HA tracker | `cortex_distributor_deduped_samples_total` | increasing |
| RED metrics | `sum by (service) (rate(traces_spanmetrics_calls_total[5m]))` | your services |
| Service graph | Grafana → Tempo → Service Graph | edges with real (un-sampled) rates |
| Events not duplicated | Loki: `sum by (k8s_event_reason) (count_over_time({job="integrations/kubernetes/eventhandler"}[5m]))` | stable after rollout, not N× |
| Loki ruler | `kubectl -n loki logs deploy/loki-ruler \| grep -i s3` | no errors |
| Tempo → Mimir | `kubectl -n tempo logs deploy/tempo-metrics-generator \| grep -i 401` | none |

## Not covered by this change (follow-ups)

- **Grafana** runs 2 replicas on SQLite with a PVC per pod: users/sessions/UI-made dashboards differ
  per replica. Move to RDS Postgres (or run 1 replica) — deliberately not changed here because
  scaling down would orphan the second pod's database.
- **Zone-aware replication** is still off. A third AZ now exists (see below); enabling it is the next step.
- **No cluster-autoscaler / Karpenter** on the observability group: scale via `desired_capacity`.
- **StorageClass `gp2-standard` parameters are immutable**: the current `default-storage-class.yaml`
  (gp3, encrypted) is rejected by `kubectl apply` on clusters that already have the old gp2 class.
  Delete and re-create the StorageClass object first (existing PVs are not affected).
- **Tail sampling mode** keeps a biased subset, so no `sampling.ratio` is stamped and Tempo
  service-graph rates are not scaled in that mode (head mode is the default).

## Third availability zone (us-east-2c)

Adds `us-east-2c` to the VPC and the observability nodes, giving 2 nodes per AZ (6 total), with a NAT gateway per AZ.

| Stack | Change |
|---|---|
| `vpc` | New public subnet `10.36.128.0/20` and private subnet `10.36.144.0/20` in us-east-2c. Existing subnets are untouched: the AZ list is written per subnet, so no subnet changes AZ. `nat_gateway_per_az = true` adds NAT gateways (+ EIPs) in b and c and a private route table per AZ; the original NAT gateway stays in a. |
| `vpc` module | `nat_gateway_per_az` (default `false` = previous single-NAT behaviour), outputs `private_subnet_ids_by_az` and `nat_gateway_ids`. `tests/az.tftest.hcl` checks the subnet → AZ mapping and routing with a mock provider (`terraform test`). |
| `eks` | New managed node group `observability-c` (2 × m6i.2xlarge, same label and taint) in the us-east-2c subnet, read from the VPC stack's outputs (`dependency "vpc"`). The existing `observability` group and the control-plane subnets are not changed: node-group `subnet_ids` are immutable, and changing them would replace every node. |

### Rollout

1. **VPC:**
   ```bash
   cd terragrunt/infrastructure-live/accounts/mlops/us-east-2/vpc
   terragrunt plan    # expect: + 2 subnets, + 2 NAT gateways / EIPs, + 2 route tables, + 1 association;
                      #         ~ route-table changes on the b subnets' associations. NO subnet replaced.
   terragrunt apply
   ```
   The b subnets switch from the a NAT gateway to the b one with an in-place association update; open connections through NAT may reset once.
2. **EKS:**
   ```bash
   cd ../eks
   terragrunt plan    # expect: + node group observability-c (+ launch template); nothing else
   terragrunt apply
   kubectl get nodes -l workload=observability -L topology.kubernetes.io/zone   # 2 per zone
   ```
3. **Nothing moves by itself.** Existing pods and their EBS volumes stay in a/b. New PVCs (`WaitForFirstConsumer`) and DaemonSets will also use c.

### Next: zone-aware replication

With three zones, Loki, Mimir and Tempo can spread replicas so that an AZ outage loses at most one copy (`zoneAwareReplication` in each chart; `topology.kubernetes.io/zone` as the zone label). The charts re-create the ingester / store-gateway StatefulSets under per-zone names, so plan it as its own migration: flush ingesters first, follow each chart's migration guide, and roll one component at a time.

### Cost

Two more NAT gateways and EIPs (hourly charge + per-GB processing each) and 2 more m6i.2xlarge. Set `nat_gateway_per_az = false` to keep a single NAT gateway (in a): cheaper, but egress for every AZ then depends on us-east-2a.
