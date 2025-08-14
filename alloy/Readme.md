How it works:

* prometheus.exporter.unix "node_exporter": This block tells Grafana Alloy to start an internal HTTP server (usually on port 80 or 8080 within the Alloy pod, depending on its overall configuration) that exposes Node Exporter metrics.

* discovery.relabel "node_exporter_relabel": This block discovers the Alloy pods themselves (which are now acting as Node Exporters) and applies labels to their metrics.

* prometheus.scrape "node_exporter_scrape": This block tells the Alloy agent to scrape its own internal Node Exporter endpoint (or the endpoint of other Alloy pods, if configured for distributed scraping) and then forward those metrics.

* prometheus.remote_write "central_prometheus": This block then sends the scraped metrics to your central Prometheus/Mimir/Thanos instance.





# kubectl create namespace alloy-logs

# kubectl apply -f alloy-logs-configMap.yml

# helm repo add grafana https:grafana.github.io/helm-charts
# helm repo update

# helm upgrade --install grafana-alloy grafana/alloy -f alloy-override-values.yaml --namespace alloy-logs

# kubectl get pods -n alloy-logs -l app.kubernetes.io/name=grafana-alloy
# kubectl logs -n alloy-logs -l app.kubernetes.io/name=grafana-alloy --tail=100




## 🔍 1. Discovery and Log Target Construction

| Component                      | Type         | Purpose                                                                                                                                |
| ------------------------------ | ------------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| `discovery.kubernetes "pods"`  | Discovery    | Fetches metadata about all pods in the cluster. Needed for dynamic log collection.                                                     |
| `discovery.relabel "pod_logs"` | Relabeling   | Extracts metadata like pod/container name, namespace, UID, etc., and maps them to log labels. Defines the file paths for log scraping. |
| `local.file_match "pod_logs"`  | File matcher | Resolves log file paths like `/var/log/pods/...` for Alloy to read from. Used by `loki.source.file`.                                   |


## 📄 2. Log Ingestion and Processing

| Component                                        | Type                | Purpose                                                                                                                                                                              |
| ------------------------------------------------ | ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `loki.source.file "pod_logs"`                    | Source              | Reads logs from matched files (via `local.file_match`) and forwards them to the `loki.process.pod_logs` pipeline.                                                                    |
| `loki.source.kubernetes_events "cluster_events"` | Source              | Ingests Kubernetes events for additional cluster-level visibility.                                                                                                                   |
| `loki.process "pod_logs"`                        | Processing Pipeline | Handles log parsing, CRI/Docker decoding, label extraction, regex extraction (e.g., `status_code`), and JSON decoding. Also attaches static labels like `cluster`. Forwards to Loki. |
| `loki.process "cluster_events"`                  | Processing          | Labels Kubernetes events and forwards to Loki.                                                                                                                                       |
| `loki.write "loki"`                              | Exporter            | Sends all processed logs to Loki. Uses custom headers (auth + tenant).                                                                                                               |


## 🔄 3. OpenTelemetry Traces Pipeline

| Component                                   | Type      | Purpose                                                                                           |
| ------------------------------------------- | --------- | ------------------------------------------------------------------------------------------------- |
| `otelcol.receiver.otlp "default"`           | Receiver  | Accepts traces over gRPC (`4317`) and HTTP (`4318`). Feeds traces into processors and connectors. |
| `otelcol.processor.k8sattributes "default"` | Processor | Enriches trace data with Kubernetes metadata (namespace, pod, deployment, etc.).                  |
| `otelcol.processor.batch "default"`         | Processor | Batches trace and metric data for efficient export.                                               |
| `otelcol.exporter.otlp "tempo"`             | Exporter  | Sends trace data to Tempo’s gRPC endpoint (your `tempo-distributor`).                             |
| `otelcol.connector.spanlogs "default"`      | Connector | Extracts logs from spans and sends to `otelcol.exporter.loki` for trace-log correlation.          |
| `otelcol.exporter.loki "spanlogs_exporter"` | Exporter  | Sends span logs to Loki.                                                                          |
| `otelcol.connector.spanmetrics "default"`   | Connector | Converts spans into metrics (e.g., request duration). Forwards to Prometheus exporter.            |
| `otelcol.connector.servicegraph "default"`  | Connector | Builds service graphs from spans and exports metrics to Prometheus.                               |



## 📊 4. Prometheus Metric Export

| Component                               | Type     | Purpose                                                                                                     |
| --------------------------------------- | -------- | ----------------------------------------------------------------------------------------------------------- |
| `otelcol.exporter.prometheus "default"` | Exporter | Converts span metrics/service graphs into Prometheus format.                                                |
| `prometheus.remote_write "mimir"`       | Exporter | Sends Prometheus metrics to Grafana Mimir. This includes span metrics and service graph metrics from Tempo. |


## 🐞 5. Live Debugging

| Component                          | Type | Purpose                                                                                                    |
| ---------------------------------- | ---- | ---------------------------------------------------------------------------------------------------------- |
| `livedebugging { enabled = true }` | Misc | Enables Alloy’s live debugging mode for configuration and pipeline inspection. Useful for troubleshooting. |




## ✅ Summary Table (Components Overview)

| Component                         | Type           | Source/Input       | Output                    | Notes                                |
| --------------------------------- | -------------- | ------------------ | ------------------------- | ------------------------------------ |
| `discovery.kubernetes`            | Discovery      | Kubernetes API     | `discovery.relabel`       | Fetch pod metadata                   |
| `discovery.relabel`               | Relabeling     | Discovery targets  | `__path__`, labels        | Defines log file paths               |
| `local.file_match`                | File discovery | Relabel output     | -                         | Matches logs on disk                 |
| `loki.source.file`                | Log ingestion  | Matched files      | `loki.process`            | Reads container logs                 |
| `loki.source.kubernetes_events`   | Log ingestion  | k8s API events     | `loki.process`            | Adds cluster-level logs              |
| `loki.process`                    | Log pipeline   | Log inputs         | `loki.write`              | Parses, extracts, labels             |
| `otelcol.receiver.otlp`           | OTLP endpoint  | HTTP/gRPC clients  | Processors & Connectors   | Entry point for traces               |
| `otelcol.processor.k8sattributes` | Metadata       | Traces             | `otelcol.processor.batch` | Adds k8s metadata                    |
| `otelcol.connector.spanmetrics`   | Connector      | Traces             | Prometheus metrics        | Converts to span metrics             |
| `otelcol.connector.servicegraph`  | Connector      | Traces             | Prometheus metrics        | Generates service dependency metrics |
| `otelcol.connector.spanlogs`      | Connector      | Traces             | Logs                      | Exports span logs to Loki            |
| `otelcol.processor.batch`         | Processor      | Traces & metrics   | Exporters                 | Batches export                       |
| `otelcol.exporter.otlp`           | Exporter       | Traces             | Tempo                     | Sends spans                          |
| `otelcol.exporter.loki`           | Exporter       | Logs               | Loki                      | Sends logs from spans                |
| `otelcol.exporter.prometheus`     | Exporter       | Metrics            | Remote Write              | Sends to Mimir                       |
| `prometheus.remote_write`         | Exporter       | Prometheus metrics | Mimir                     | Remote write target                  |
