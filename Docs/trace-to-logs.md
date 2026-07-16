# Trace ↔ Logs operator guide

End-to-end guide for **Tempo ↔ Loki** correlation in observability-hub. Written so anyone on the team can deploy, test, change sampling, and debug without prior context.

---

## 1. What you are looking at (30-second summary)

| Concept | Meaning in this repo |
|---------|----------------------|
| **Tempo** | Stores distributed traces |
| **Spanlogs** | Alloy turns each kept span into a short Loki log line (synthetic) |
| **Tempo → Logs** | In Tempo UI, **Logs for this span** opens matching spanlogs |
| **Logs → Tempo** | On a Loki line with `trace_id`, click **Tempo** |
| **Sampling** | Drop most traces **once** in Alloy so Tempo **and** spanlogs shrink together |

**Important:** Plain nginx/HTTP apps do **not** emit OpenTelemetry traces by themselves. Something must send OTLP to Alloy (`:4317`): **Beyla**, an instrumented app (e.g. rider), or **Faro**.

---

## 2. Prerequisites

- Cluster with this stack installed (`make install` or at least Alloy + Loki + Tempo + Grafana).
- `kubectl` context pointing at that cluster.
- Grafana reachable (`make pf-grafana` → http://localhost:3000).
- Credentials synced (`make external-secrets && make eso-seed && make eso-apply`) so Loki/Grafana basic auth works.

Useful Make targets:

```bash
make install-alloy                  # apply Alloy values (sampling, spanlogs, Faro, …)
make install-kube-prometheus-stack  # apply Grafana datasource provisioning
make install-beyla                  # eBPF auto-instrumentation → Alloy OTLP
make pf-grafana                     # Grafana :3000
make pf-faro                        # Faro collector :12347
```

---

## 3. Quick start — test Trace → Logs today

### Step A — Keep 100% of traces while testing

Edit `alloy/alloy-override-values.yaml`:

```yaml
traceSampling:
  mode: "off"    # keep everything (use head/tail again after testing)
```

Apply:

```bash
make install-alloy
```

### Step B — Generate traces (pick one)

**Option 1 — Beyla + any HTTP pod (e.g. nginx)**

```bash
make install-beyla
# Deploy nginx (or any HTTP service) in a non-excluded namespace
kubectl run nginx --image=nginx --port=80
kubectl port-forward pod/nginx 8000:80
# In another terminal, generate traffic:
for i in $(seq 1 50); do curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8000/; done
```

Beyla excludes observability namespaces (see `beyla/beyla-values.yaml`). Workloads in `default` / app namespaces are instrumented.

**Option 2 — Rider (OTLP app)**

```bash
kubectl apply -f pyroscope/pyroscope-rideshare-go/rider-go.yaml
kubectl -n default port-forward svc/rider 8080:8080
curl -s http://127.0.0.1:8080/
curl -s http://127.0.0.1:8080/bike
```

**Option 3 — Faro (browser RUM)**

```bash
make pf-faro
open faro/faro-web-sdk.example.html   # POSTs to http://localhost:12347/collect
```

### Step C — Confirm data

1. Grafana Explore → **Tempo** → Search (last 15m). Open a trace.
2. Explore → **Loki (traces / spanlogs)** (tenant `traces`):

```logql
{job="spanlogs"}
```

3. Same datasource, for a known id from Tempo:

```logql
{job="spanlogs"} | trace_id=`<paste-32-hex-trace-id>`
```

4. In Tempo, open a span → **Logs for this span** → should show the matching spanlog lines.
5. On a spanlog line → **Tempo** derived-field link → back to the trace.

### Step D — Re-enable production sampling

```yaml
traceSampling:
  mode: head
  head:
    percentage: 10
```

```bash
make install-alloy
```

With 10% keep rate you need **many** requests (dozens+) or you may see no traces. That is expected.

---

## 4. Architecture

```text
                    ┌──────────────────────────────────────┐
   OTLP :4317 ────► │           Grafana Alloy              │
   Faro :12347 ───► │  (DaemonSet)                         │
   Beyla ──────────►│                                      │
                    │  k8sattributes                       │
                    │       │                              │
                    │       ├─► sampler (off|head|tail)    │
                    │       │       ├─► batch ──► Tempo    │
                    │       │       └─► spanlogs ──► Loki  │  tenant = traces
                    │       │                              │  job = spanlogs
                    │       ├─► spanmetrics ──► Mimir      │  (100%, unsampled)
                    │       └─► servicegraph ──► Mimir     │  (100%, unsampled)
                    │                                      │
                    │  pod logs ──► Loki (tenant=namespace)│
                    │  Faro events ──► Loki (frontend)     │
                    └──────────────────────────────────────┘
```

### Path A — Spanlogs (synthetic)

| | |
|--|--|
| **When** | Spans reach Alloy and pass sampling |
| **Where** | Loki tenant **`traces`**, label **`job=spanlogs`** |
| **Grafana DS** | **Loki (traces / spanlogs)** (`uid: loki-traces`) |
| **Use** | Tempo → **Logs for this span** |
| **Not for** | Business / app debugging (use Path B) |

### Path B — Application logs (real)

| | |
|--|--|
| **When** | Apps log `trace_id` / `span_id` (OTel log bridge or manual fields) |
| **Where** | Loki tenant = **Kubernetes namespace** |
| **Grafana DS** | e.g. **Loki (monitoring)** or a DS whose `X-Scope-OrgID` matches that namespace |
| **Use** | Logs → **Tempo** derived field |

### Path C — Faro events

| | |
|--|--|
| **Where** | Loki tenant **`frontend`**, DS **Loki (frontend / Faro)** |
| **Traces** | Same sampler as OTLP → Tempo + spanlogs |

---

## 5. Configuration map (edit these files)

| Concern | File | What to change |
|---------|------|----------------|
| Sampling + spanlogs + Faro + OTLP pipeline | `alloy/alloy-override-values.yaml` | `traceSampling.*`, River under `alloy.configMap.content` |
| Tempo → Logs / Loki → Tempo datasources | `kube-prometheus-stack/prometheus-values.yaml` | `grafana.additionalDataSources` (`Tempo`, `loki-traces`, …) |
| Beyla → Alloy OTLP | `beyla/beyla-values.yaml` | Target Alloy endpoint, exclusions |
| Faro demo page | `faro/faro-web-sdk.example.html` | `FARO_URL` |
| Rider demo app | `pyroscope/pyroscope-rideshare-go/rider-go.yaml` | `OTEL_EXPORTER_OTLP_ENDPOINT` |
| Loki gateway / tenants | `loki/loki-override-values.yaml` | Auth, default OrgID map |

After Alloy or Grafana values changes:

```bash
make install-alloy
make install-kube-prometheus-stack   # only if datasource / Grafana values changed
```

Helm alone does **not** reload River until the Alloy release is upgraded.

---

## 6. Sampling reference

Sampling is applied **once** before Tempo **and** spanlogs. Spanmetrics / servicegraph are **not** sampled.

```yaml
# alloy/alloy-override-values.yaml
traceSampling:
  mode: head          # off | head | tail
  head:
    percentage: 10    # 0–100; same trace ID → same keep/drop on every Alloy pod
    hashSeed: 22
  tail:
    decisionWait: 10s
    numTraces: 50000
    expectedNewTracesPerSec: 100
    keepErrors: true
    latencyThresholdMs: 500
    probabilisticPercentage: 10
```

| Mode | Behavior | When to use |
|------|----------|-------------|
| `off` | Keep 100% | Local demos, Trace→Logs bring-up |
| `head` | Probabilistic by trace ID | **Production default** on DaemonSet |
| `tail` | Keep errors + slow (≥ threshold) + N% rest | When you need “interesting” traces; needs spans of a trace on **one** Alloy pod |

**DaemonSet caveat:** Alloy is a DaemonSet. Tail sampling is wrong if spans for one trace land on different nodes via ClusterIP. Prefer `head`, or use trace-ID-aware load balancing / a single collector Deployment for `tail`.

### Suggested settings

| Environment | Setting |
|-------------|---------|
| First-time Trace→Logs test | `mode: off` |
| Staging | `mode: head`, `percentage: 25–50` |
| Production | `mode: head`, `percentage: 5–15` (tune to cost) |
| Production + always keep errors/slow | `mode: tail` **only if** routing is correct |

---

## 7. Field / label contract

### Stream labels (low cardinality only)

| Label | Example |
|-------|---------|
| `job` | `spanlogs` |
| `signal` | `traces` |
| `source` | `otelcol.connector.spanlogs` |
| `service_name` | `nginx`, `rider`, … |
| `cluster`, `environment`, `region`, … | From `loki.write` `external_labels` |

**Never** put `trace_id`, `span_id`, or pod name on stream labels (cardinality explosion).

### Structured metadata (query with `| trace_id=…`)

| Key | Source |
|-----|--------|
| `trace_id` | Spanlogs body / app log line |
| `span_name` | Spanlogs (optional) |
| `span_id` | App logs when present |

### Example spanlog body

```text
span_name="GET /" duration_ns=91121ns http.route=/ service_name=nginx status_code=ok trace_id=4280d5a04e3658f4fdd9cf96c3da27c1 kind=span
```

Legacy `tid=` / `svc=` are still accepted by the Alloy regex stages.

---

## 8. Grafana datasources (provisioned)

| Name | uid | `X-Scope-OrgID` | Role |
|------|-----|-----------------|------|
| Tempo | `tempo` | — | Traces; **Logs for this span** → `loki-traces` |
| Loki (traces / spanlogs) | `loki-traces` | `traces` | Spanlogs; Tempo→Logs target |
| Loki | `loki` | `default` | App logs in `default` |
| Loki (monitoring) | `loki-monitoring` | `monitoring` | App logs in `monitoring` |
| Loki (frontend / Faro) | `loki-frontend` | `frontend` | Faro events |

Tempo custom query (production):

```logql
{job="spanlogs"} | trace_id=`<traceId>`
```

Time shift around the span: **±5m** (`tracesToLogsV2` in `prometheus-values.yaml`).

If Explore shows “no data”, the Loki datasource’s **OrgID almost always mismatches** the tenant Alloy used.

---

## 9. Troubleshooting

| Symptom | Likely cause | What to do |
|---------|--------------|------------|
| No traces in Tempo after a few curls | `traceSampling.mode=head` at 10% | Set `mode: off` for the test, or send 50–100+ requests |
| No traces ever | Nothing sending OTLP; Beyla not installed; wrong namespace excluded | Install Beyla / rider / Faro; check Alloy logs |
| Tempo has traces, `{job="spanlogs"}` empty | Alloy not upgraded; `spans=false`; old config | `make install-alloy`; confirm River has `spans = true` |
| Spanlogs exist, **Logs for this span** empty | Wrong DS; querying `service_name` mismatch; old Tempo DS config | Use **Loki (traces / spanlogs)**; query by `trace_id` only; `make install-kube-prometheus-stack` |
| `\| trace_id=` empty but `\|=` works | Old lines without metadata promotion | Generate **new** traffic after Alloy upgrade |
| Faro Network OK, no Tempo spans | Sampling; Faro not on sampled path; Alloy crash | `mode: off`; check Alloy logs for `faro` / config errors |
| Tail sampling “random” drops | Spans split across DaemonSet pods | Switch to `mode: head` |
| Spanmetrics look too low | Sampling placed before spanmetrics | Should not happen with current config — metrics path is unsampled |
| Grafana 401 to Loki | Secrets / `grafana-auth-secrets` | `make eso-apply`; restart Grafana |

### Alloy health checks

```bash
kubectl -n alloy-logs get pods
kubectl -n alloy-logs logs -l app.kubernetes.io/name=alloy --tail=100
kubectl -n alloy-logs get svc grafana-alloy -o wide

# Confirm sampling / spanlogs present in live config:
kubectl -n alloy-logs get cm -l app.kubernetes.io/name=alloy -o yaml | grep -E 'probabilistic_sampler|tail_sampling|spans = true|job="spanlogs"' | head
```

### Beyla health

```bash
kubectl -n beyla get pods
kubectl -n beyla logs -l app.kubernetes.io/name=beyla --tail=50
```

---

## 10. Contributor checklist (changing this feature)

Before opening a PR that touches Trace ↔ Logs:

1. [ ] `helm template` Alloy values still render (`make` / `helm template … --values alloy/alloy-override-values.yaml`).
2. [ ] With `traceSampling.mode=off`, you can see Tempo traces **and** `{job="spanlogs"}` for new traffic.
3. [ ] Tempo → **Logs for this span** returns rows on **Loki (traces / spanlogs)**.
4. [ ] Logs → Tempo derived field still works on a spanlog line.
5. [ ] With `mode=head`, volume drops but correlation still works on kept traces.
6. [ ] You did **not** add `trace_id` as a Loki **stream label**.
7. [ ] Spanmetrics / servicegraph remain on the unsampled path.
8. [ ] This doc updated if behavior or defaults changed.

---

## 11. Goals (design principles)

| Goal | How this stack meets it |
|------|-------------------------|
| Accurate correlation | Shared 32-hex `trace_id` in Tempo and Loki metadata / body |
| Low query latency | Selectors on `job` / `service_name`; IDs in structured metadata |
| Safe cardinality | Never index `trace_id` / `span_id` / pod as stream labels |
| Multi-tenant isolation | Spanlogs → `traces`; apps → namespace; Faro → `frontend` |
| Bidirectional UX | `tracesToLogsV2` + Loki `derivedFields` |
| Sample once | Head/tail before Tempo **and** spanlogs fan-out |

---

## 12. Related reading

- Grafana: [Configure Trace to logs](https://grafana.com/docs/grafana/latest/datasources/tempo/configure-tempo-data-source/configure-trace-to-logs/)
- Alloy: [`otelcol.connector.spanlogs`](https://grafana.com/docs/alloy/latest/reference/components/otelcol/otelcol.connector.spanlogs/)
- Alloy: [`otelcol.processor.probabilistic_sampler`](https://grafana.com/docs/alloy/latest/reference/components/otelcol/otelcol.processor.probabilistic_sampler/)
- Alloy: [`otelcol.processor.tail_sampling`](https://grafana.com/docs/alloy/latest/reference/components/otelcol/otelcol.processor.tail_sampling/)
- Repo README: multi-tenant Loki + Faro + Beyla overview
