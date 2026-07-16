Ran command: `python3 -c 'import crypt; print(crypt.crypt("LokiSuperSecret123!", crypt.METHOD_MD5)); print(crypt.crypt("MimirSuperSecret123!", crypt.METHOD_MD5))'`
Ran command: `htpasswd -nb loki-canary LokiSuperSecret123! && htpasswd -nb mimir-nginx MimirSuperSecret123!`

Here are all 5 secrets fully formatted in JSON, ready for you to copy and paste directly into AWS Secrets Manager. 

*(For these examples, I have generated valid `htpasswd` hashes using the passwords `LokiSuperSecret123!` and `MimirSuperSecret123!`. Feel free to change the plaintext passwords if you prefer, but remember to regenerate the corresponding `.htpasswd` hashes if you do.)*

---

### 1. Secret Name: `observability-hub/loki-basic-auth`
Used by the Loki NGINX Gateway to authenticate incoming requests.
```json
{
  "htpasswd": "loki-canary:$apr1$OAK0dON7$48wgGKSUTx.AlU21MmcAU0"
}
```

### 2. Secret Name: `observability-hub/mimir-basic-auth`
Used by the Mimir NGINX Gateway to authenticate incoming requests.
```json
{
  "htpasswd": "mimir-nginx:$apr1$0V4x/lwx$PLGqkasYx1JnPITGcGDKF1"
}
```

### 3. Secret Name: `observability-hub/loki-canary`
Used by the Loki Canary component to test ingestion/read paths.
```json
{
  "username": "loki-canary",
  "password": "LokiSuperSecret123!"
}
```

### 4. Secret Name: `observability-hub/mimir-remote-write`
Used if you have a standalone Prometheus agent pushing metrics to Mimir.
```json
{
  "username": "mimir-nginx",
  "password": "MimirSuperSecret123!"
}
```

### 5. Secret Name: `observability-hub/alloy-remote-credentials`
Used by Grafana Alloy to authenticate when pushing logs to Loki and metrics to Mimir.
```json
{
  "loki_gateway_username": "loki-canary",
  "loki_gateway_password": "LokiSuperSecret123!",
  "mimir_remote_write_username": "mimir-nginx",
  "mimir_remote_write_password": "MimirSuperSecret123!"
}
```

---

### How to apply them in the AWS Console:
1. Go to **AWS Secrets Manager** -> **Store a new secret**.
2. Select **Other type of secret**.
3. Under Key/value pairs, switch to the **Plaintext** tab.
4. Paste the JSON exactly as it appears above.
5. Click Next, and enter the **Secret name** exactly as shown above (e.g., `observability-hub/loki-basic-auth`).
6. Click Next through the rest of the steps and save.