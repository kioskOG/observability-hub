# Kube Prometheus Stack

**Kube Prometheus Stack** is a comprehensive monitoring stack specifically designed for Kubernetes. It brings together multiple components to provide detailed insights into your cluster's health and performance.


* **Prometheus**: This is the central monitoring system that collects and stores metrics from your Kubernetes cluster and its workloads. It uses a powerful query language (PromQL) to analyze and visualize the collected data.

* **Prometheus Operator**: This is a tool that simplifies the deployment and management of Prometheus instances on Kubernetes. It automates tasks such as scaling, upgrading, and configuration, making it easier to manage Prometheus in dynamic Kubernetes environments.

* **Alertmanager**: Handles alerts sent by Prometheus based on predefined rules. It supports various notification channels such as email, Slack, and PagerDuty.

* **Grafana**: Provides a user-friendly interface for visualizing metrics through customizable dashboards. It integrates seamlessly with Prometheus, allowing you to create real-time visualizations of your cluster's data.

* **Kube-State-Metrics**: Exposes detailed metrics about the state of Kubernetes resources, such as Deployments, Pods, and Nodes.

* **Node Exporter**: Collects hardware and OS-level metrics from the cluster nodes, such as CPU and memory usage.


> [!NOTE]
> Together, these components form a powerful stack that provides end-to-end visibility into your Kubernetes environment

## Prerequisites

1. A Kubernetes cluster (v1.19+ recommended).

2. Helm 3 installed on your local system.

3. kubectl installed and configured for your cluster.

## Add the Prometheus Community Helm Repository

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```


## Install the Kube Prometheus Stack Helm Chart

```bash
helm upgrade --install kube-prometheus-stack ./kube-prometheus-stack/ --namespace monitoring -f kube-prometheus-stack/prometheus-values.yaml
```

> [!NOTE]
> * Replace `kube-prometheus-stack` with your preferred release name.
>
> * The --namespace `monitoring` flag ensures that the stack is installed in a dedicated namespace.


## Accessing Grafana and Other Components

### Retrieve the Grafana Admin Password

```bash
kubectl get secret kube-prometheus-stack-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```


## Port Forward to Access Grafana

```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
```

Now, open your browser and navigate to [localhost](http://localhost:3000). Use the username admin and the retrieved password to log in.


## Why Choose the Kube Prometheus Stack?
The **Kube Prometheus Stack Helm Chart** is a community-driven solution that simplifies monitoring Kubernetes. With its comprehensive set of features and ease of deployment, it has become the go-to choice for DevOps teams worldwide.


## Key Benefits:

* **Ease of Deployment:** The Helm chart abstracts complex configurations.

* **Scalability:** Designed to handle dynamic Kubernetes environments.

* **Customizability:** Tailor every component to meet your needs.

* **Community Support:** Backed by the Prometheus community.
