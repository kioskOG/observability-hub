# Per-environment tenancy: rollout on an existing install

Runbook for moving a running stack from the old layout to one tenant per environment (`prod`, `stage`, `dev`) in Loki and Mimir. The old layout had Loki tenants per namespace, Mimir single-tenant, and one shared credential. The target design is described in the README under [Multi-tenancy](../README.md#multi-tenancy-loki-and-mimir). Follow the steps in order.

## What changes

| Area | Before | After |
|------|--------|-------|
| Loki tenant | Pod namespace; fixed tenants `platform`, `alloy-logs`, `traces`, `frontend`; canary `loki-system` | Environment (`ENVIRONMENT_NAME`); canary `canary`. Streams are told apart by the `source` label |
| Loki gateway | Forwarded the client's `X-Scope-OrgID` (on query/tail paths the gateway's own rule never applied) | Tenant derived from the basic-auth user; a mismatching header gets 403 |
| Mimir | `multitenancy_enabled: false`, everything in tenant `anonymous` | `multitenancy_enabled: true`, `tenant_federation.enabled: true`, tenant = environment |
| Mimir gateway | Our custom nginx config sat under `nginx.config`, which the chart ignores, so the chart default (trusting the client header) ran | Config moved to `nginx.nginxConfig`; the tenant always comes from the user. This also activates `client_max_body_size 540M` and `/ready` |
| Credentials | `loki-canary` / `mimir-nginx` shared by every client | `loki-writer-<env>`, `mimir-writer-<env>`, `loki-canary`, `loki-ruler`, `grafana-reader` |
| Grafana | Loki datasources `loki`, `loki-monitoring`, `loki-traces`, `loki-frontend`; Mimir with no tenant | `loki`, `loki-all`, `mimir`, `mimir-all`, `mimir-anonymous`; old Loki datasources removed via `deleteDatasources` |
| `environment` label | `Production` | `prod` / `stage` / `dev` |

## Before you start

1. Set the environment consistently: `ENVIRONMENT_NAME` in both Alloy values files and `grafana.env.TENANT` in `prometheus-values.yaml`. See the README section [Environments](../README.md#environments-prod--stage--dev).
2. List the Mimir rules and Alertmanager config currently stored for `anonymous`, so you can reload them later:
   ```bash
   mimirtool rules print --address=http://<mimir-nginx> --id=anonymous --user=<old user> --key=<old password> > /tmp/anonymous-rules.yaml
   ```
3. Dashboards or alerts that filter on `environment="Production"` must be changed to the new value.

## Rollout

The order matters: clients must have their new credentials before the gateways start enforcing.

1. **Seed the new credentials** (rotates everything):
   ```bash
   make eso-seed ENVIRONMENT=<env>
   make eso-apply      # syncs secrets; also restarts Grafana
   ```
   From now on the old gateways only know the new users, so writes get 401 until the next step. Clients retry, so data is delayed, not lost.
2. **Collectors** pick up the new credentials and tenant (the old gateways still accept any header):
   ```bash
   make install-alloy install-alloy-events
   kubectl -n monitoring rollout restart sts/prometheus-kube-prometheus-stack-prometheus
   kubectl -n tempo rollout restart deploy/tempo-metrics-generator
   ```
3. **Render and upgrade the backends:**
   ```bash
   make render-helm-values
   make install-mimir
   make install-loki
   kubectl -n loki exec deploy/loki-gateway -- nginx -t
   kubectl -n mimir exec deploy/mimir-nginx -- nginx -t
   ```
4. **Grafana:** `make install-kube-prometheus-stack`.
5. **Reload Mimir rules** into the environment tenant:
   ```bash
   mimirtool rules load --address=http://<mimir-nginx> --id=<env> --user=grafana-reader --key=<mimir-grafana-reader password> /tmp/anonymous-rules.yaml
   ```

## Expected one-time effects

- **Loki history:** logs in the old namespace tenants are no longer visible in Grafana. With the 24h retention they expire within a day.
- **Mimir history:** metrics written before the switch stay in tenant `anonymous`, readable through **Mimir (pre-tenancy history)**. Dashboards on the default **Mimir** datasource start empty at the switch time. Long ranges that need both sides can use a federated query, but series are split by `__tenant_id__`.
- **Short write gap** between steps 1 and 3 (401s, retried).
- **`environment` label value changes**, so new series are created for everything that carries it.

### Optional: move `anonymous` history into the environment tenant

Blocks are stored per tenant under the bucket prefix `<tenant>/`. Copying the uploaded blocks keeps the history in one tenant:

```bash
aws s3 sync s3://<cluster>-mimir-chunks/anonymous/ s3://<cluster>-mimir-chunks/<env>/ --exclude 'bucket-index.json.gz'
```

Do this only after the ingesters have uploaded every `anonymous` block, which takes about `blocks_storage.tsdb.block_ranges_period` plus the ship interval after the switch, typically ~3 h. The compactor rebuilds the bucket index on its next run. Verify in **Mimir** before deleting `anonymous/`.

## Verify

| Check | How | Expect |
|-------|-----|--------|
| No auth errors | `kubectl -n alloy-logs logs ds/grafana-alloy --tail=500 \| grep -E ' 40[13] '` | nothing |
| Logs in the env tenant | Grafana → **Loki** → `sum by (source) (count_over_time({source=~".+"}[5m]))` | `pod`, `syslog`/`journal`, `alloy`, `k8s-events`, … |
| Metrics in the env tenant | **Mimir** → `count(up)` | > 0 |
| Federation | **Mimir (all environments)** → `count by (__tenant_id__) (up)` | one row per environment that writes |
| Header spoofing rejected | `curl -u loki-writer-<env>:<pw> -H 'X-Scope-OrgID: other' http://loki-gateway.loki/loki/api/v1/labels` (from a pod) | 403 |
| Loki ruler → Mimir | `kubectl -n loki logs sts/loki-ruler \| grep -iE '40[13]'` | nothing |
| Tempo → Mimir | `kubectl -n tempo logs deploy/tempo-metrics-generator \| grep -iE '40[13]'` | nothing |

## Rollback

Revert the commit, then run `make eso-seed` (the old script recreates the shared users), `make eso-apply`, `make render-helm-values`, and reinstall the same components. Data written to environment tenants stays in S3 under `<env>/`, but is not visible while Mimir is single-tenant.
