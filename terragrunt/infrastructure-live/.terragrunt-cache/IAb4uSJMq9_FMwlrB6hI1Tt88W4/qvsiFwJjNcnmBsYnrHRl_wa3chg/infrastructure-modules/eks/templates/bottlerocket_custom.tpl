# Custom user data template provided for rendering
[settings.kubernetes]
"cluster-name" = "${cluster_name}"
"api-server" = "${cluster_endpoint}"
"cluster-certificate" = "${cluster_auth_base64}"

[settings.kubernetes.kube-reserved]
cpu = "300m"
memory = "300Mi"
ephemeral-storage= "1Gi"
[settings.kubernetes.system-reserved]
cpu = "300m"
memory = "200Mi"
ephemeral-storage= "1Gi"
[settings.kubernetes.eviction-hard]
"memory.available" = "15%"


[settings.kernel]
lockdown = "integrity"

${bootstrap_extra_args~}