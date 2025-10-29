<div align="center"> 
  <h1>🚀 LGTM stack on Kubernetes Complete Hands‑On Guides 🌟 </h1>
  <a href="https://github.com/kioskOG/observability-hub"><img src="https://readme-typing-svg.demolab.com?font=italic&weight=700&size=18&duration=4000&pause=1000&color=F727A9&center=true&width=600&lines=+-+Run+complete+LGTM+Stack+on+Kubernetes+for+observability." alt="Typing SVG" /> </a>  
  <br>
    <img src="https://img.shields.io/github/forks/kioskOG/observability-hub" alt="Forks"/>
  <img src="https://img.shields.io/github/stars/kioskOG/observability-hub" alt="Stars"/>
  <img src="https://img.shields.io/github/watchers/kioskOG/observability-hub" alt="Watchers"/>
  <img src="https://img.shields.io/github/last-commit/kioskOG/observability-hub" alt="Last Commit"/>
  <img src="https://img.shields.io/github/commit-activity/m/kioskOG/observability-hub" alt="Commit Activity"/>
  <img src="https://img.shields.io/github/repo-size/kioskOG/observability-hub" alt="Repo Size"/>
  <img src="https://img.shields.io/static/v1?label=%F0%9F%8C%9F&message=If%20Useful&style=style=flat&color=BC4E99" alt="Star Badge"/>

  <!-- <img src="https://awesome.re/badge.svg" alt="Awesome"/> -->
  <a href="https://github.com/kioskOG/observability-hub/blob/main/LICENSE"> <img src="https://img.shields.io/github/license/kioskOG/observability-hub" alt="GitHub License"/> </a>
  <a href="https://github.com/kioskOG/observability-hub/graphs/contributors"> <img src="https://img.shields.io/github/contributors/kioskOG/observability-hub" alt="GitHub contributors"/> </a>
  <a href="https://github.com/kioskOG/observability-hub/issues">  <img src="https://img.shields.io/github/issues/kioskOG/observability-hub" alt="Open Issues"/> </a>
  <a href="https://github.com/kioskOG/observability-hub/pulls"> <img src="https://img.shields.io/github/issues-pr-raw/kioskOG/observability-hub" alt="Open PRs"/> </a>
  <a href="https://github.com/kioskOG/observability-hub/pulls"> <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square" alt="PRs Welcome"/> </a>
  </div>

---

# observability-hub


> [!IMPORTANT]
> # If you wanna use Makefile for the complete deployment.

## ✅ How to Run

```bash
make help
make init                     # Setup all prerequisits including AWS roles, buckets & policies
make install                  # Complete Setup deploy
make install-loki             # Just Loki
make install-tempo            # Just Tempo
make uninstall-alloy          # Uninstall Alloy
make status-mimir             # Get Mimir status
make logs-tempo               # Tail Tempo logs
make template-debug-loki      # Render Loki manifests
make pf-grafana               # port forward to grafana service
```

> [!NOTE]
> For manual setup follow below steps.

## Deploy the Loki Helm chart on AWS
I expect you to have the necessary tools and permissions to deploy resources on AWS, such as:

- Full access to EKS (Amazon Elastic Kubernetes Service)
- Full access to S3 (Amazon Simple Storage Service)
- Sufficient permissions to create IAM (Identity Access Management) roles and policies

## Pre-requisits:-
- Helm 3 or above. [This should be installed on your local machine.](https://helm.sh/docs/intro/install/)
- A running Kubernetes cluster on AWS with OIDC configure
- Create an IAM role Mentioned Below for Mimir & Tempo & should have access to s3.
- Create a Storage-class named `gp2-standard`


## The minimum requirements for deploying Loki on EKS are:

- Kubernetes version 1.30 or above.
- 3 nodes for the EKS cluster.
- Instance type depends on your workload. A good starting point for a production cluster is `m7i.2xlarge`.

## The following plugins must also be installed within the EKS cluster:

- **Amazon EBS CSI Driver:** Enables Kubernetes to dynamically provision and manage EBS volumes as persistent storage for applications. We use this to provision the node volumes for Loki.

- **CoreDNS:** Provides internal DNS service for Kubernetes clusters, ensuring that services and pods can communicate with each other using DNS names.

- **kube-proxy:** Maintains network rules on nodes, enabling communication between pods and services within the cluster.

### 1. Create S3 buckets & Storage-class
```bash
aws s3 mb s3://bellatrix-loki-chunk --region eu-central-1 && aws s3 mb s3://bellatrix-loki-ruler --region eu-central-1
```

>> storage-class

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp2-standard
  annotations: 
    storageclass.kubernetes.io/is-default-class: "true" 
provisioner: ebs.csi.aws.com   # Internal-provisioner
allowVolumeExpansion: true
parameters:
  type: gp2
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
```

### 2. Defining IAM roles and policies

> [!NOTE]
> Create a new directory and navigate to it. Make sure to create the files in this directory

Create a `loki-s3-policy.json` file with the following content:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "LokiStorage",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::bellatrix-loki-chunk",
                "arn:aws:s3:::bellatrix-loki-chunk/*",
                "arn:aws:s3:::bellatrix-loki-ruler",
                "arn:aws:s3:::bellatrix-loki-ruler/*"
            ]
        }
    ]
}
```

### 3. Create the IAM policy using the AWS CLI:

```bash
aws iam create-policy --policy-name LokiS3AccessPolicy --policy-document file://loki-s3-policy.json
```

### 4. Create a trust policy document named `trust-policy.json` with the following content:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.ap-southeast-1.amazonaws.com/id/905FD3625D5E720BDB50A6227B6B654A"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.ap-southeast-1.amazonaws.com/id/905FD3625D5E720BDB50A6227B6B654A:sub": "system:serviceaccount:loki:loki",
                    "oidc.eks.ap-southeast-1.amazonaws.com/id/905FD3625D5E720BDB50A6227B6B654A:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
```

### 5. Create the IAM role using the AWS CLI:

```bash
aws iam create-role --role-name LokiServiceAccountRole --assume-role-policy-document file://trust-policy.json
```

### 6. Attach the policy to the role:

```bash
aws iam attach-role-policy --role-name LokiServiceAccountRole --policy-arn arn:aws:iam::<Account ID>:policy/LokiS3AccessPolicy
```

### 7. Deploying the Helm chart
>> Add the Grafana chart repository to Helm:

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
kubectl create namespace loki
```

> [!NOTE]
> This is very importent else loki gateway will fail.

### 8. Loki Basic Authentication

Loki by default does not come with any authentication. Since we will be deploying Loki to AWS and exposing the gateway to the internet near future, as of now we aren't exposing it to internet, I recommend adding at least basic authentication. In this guide we will give Loki a `username` and `password`:

1. To start we will need create a `.htpasswd` file with the `username` and `password`. You can use the `htpasswd` command to create the file:

```bash
htpasswd -c .htpasswd <username>
```

> [!NOTE]
> This will create a file called `auth` with the username you enterned. You will be prompted to enter a password. I am keeping the password as `loki-canary` .

2. Create a Kubernetes secret with the .htpasswd file:
```bash
kubectl create secret generic loki-basic-auth --from-file=.htpasswd -n loki
```

This will create a secret called loki-basic-auth in the loki namespace. We will reference this secret in the Loki Helm chart configuration.

3. Create a `canary-basic-auth` secret for the canary:

```bash
kubectl create secret generic canary-basic-auth \
  --from-literal=username=<USERNAME> \
  --from-literal=password=<PASSWORD> \
  -n loki
```
I have used username & password as `loki-canary`.

you can find the loki helm chart values under loki directory.

## 9. Deploy loki

> [!IMPORTANT]
>
> ```bash
>helm upgrade --install loki grafana/loki -n loki --create-namespace --values "<path-of-loki-override-values.yaml>"
>```

4. Verify the deployment:

```bash
kubectl get pods -n loki
```

## 10. Find the Loki Gateway Service

```bash
kubectl get svc -n loki
```

> [!IMPORTANT]
> Congratulations! You have successfully deployed Loki on AWS using the Helm chart. Before we finish, let’s test the deployment.

## 11. Testing Your Loki Deployment
k6 is one of the fastest ways to test your Loki deployment. This will allow you to both write and query logs to Loki. To get started with k6, follow the steps below:

1. Install k6 with the Loki extension on your local machine. Refer to [Installing k6 and the xk6-loki extension](https://grafana.com/docs/loki/latest/send-data/k6/)

2. Create a `aws-test.js` file with the following content:

```javascript
 import {sleep, check} from 'k6';
 import loki from 'k6/x/loki';

 /**
 * URL used for push and query requests
 * Path is automatically appended by the client
 * @constant {string}
 */

 const username = '<USERNAME>';
 const password = '<PASSWORD>';
 const external_ip = '<EXTERNAL-IP>';

 const credentials = `${username}:${password}`;

 const BASE_URL = `http://${credentials}@${external_ip}`;

 /**
 * Helper constant for byte values
 * @constant {number}
 */
 const KB = 1024;

 /**
 * Helper constant for byte values
 * @constant {number}
 */
 const MB = KB * KB;

 /**
 * Instantiate config and Loki client
 */

 const conf = new loki.Config(BASE_URL);
 const client = new loki.Client(conf);

 /**
 * Define test scenario
 */
 export const options = {
   vus: 10,
   iterations: 10,
 };

 export default () => {
   // Push request with 10 streams and uncompressed logs between 800KB and 2MB
   var res = client.pushParameterized(10, 800 * KB, 2 * MB);
   // Check for successful write
   check(res, { 'successful write': (res) => res.status == 204 });

   // Pick a random log format from label pool
   let format = randomChoice(conf.labels["format"]);

   // Execute instant query with limit 1
   res = client.instantQuery(`count_over_time({format="${format}"}[1m])`, 1)
   // Check for successful read
   check(res, { 'successful instant query': (res) => res.status == 200 });

   // Execute range query over last 5m and limit 1000
   res = client.rangeQuery(`{format="${format}"}`, "5m", 1000)
   // Check for successful read
   check(res, { 'successful range query': (res) => res.status == 200 });

   // Wait before next iteration
   sleep(1);
 }

 /**
 * Helper function to get random item from array
 */
 function randomChoice(items) {
   return items[Math.floor(Math.random() * items.length)];
 }
 ```

 > [!TIP]
 > use kubectl-port to forward loki-gateway service on your local.

 >> Replace <EXTERNAL-IP> with the localhost IP address with port of the Loki Gateway service.

 >> Replace <USERNAME> & <PASSWORD> with canary-basic-auth which we created.

> [!NOTE]
> This script will write logs to Loki and query logs from Loki. It will write logs in a random format between 800KB and 2MB and query logs in a random format over the last 5 minutes.


3. Run the test:
```bash
./k6 run aws-test.js
```


## For Mimir & Tempo, we will create another IAM role named `MimirServiceAccountRole`

### IAM role:-

>> **arn:aws:iam::<ACCOUNT_ID>:role/MimirServiceAccountRole**

* ## Trusted relationships.

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Principal": {
				"Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.ap-southeast-1.amazonaws.com/id/905FD3625D5E720BDB50A6227B6B654A"
			},
			"Action": "sts:AssumeRoleWithWebIdentity",
			"Condition": {
				"StringEquals": {
					"oidc.eks.ap-southeast-1.amazonaws.com/id/905FD3625D5E720BDB50A6227B6B654A:sub": [
						"system:serviceaccount:mimir:mimir",
						"system:serviceaccount:tempo:tempo"
					],
					"oidc.eks.ap-southeast-1.amazonaws.com/id/905FD3625D5E720BDB50A6227B6B654A:aud": "sts.amazonaws.com"
				}
			}
		}
	]
}
```


>> Attach below policy to above role:

policy name: mimir-s3
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "LokiStorage",
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::bellatrix-loki-chunk",
                "arn:aws:s3:::bellatrix-loki-chunk/*",
                "arn:aws:s3:::bellatrix-loki-ruler",
                "arn:aws:s3:::bellatrix-loki-ruler/*"
            ]
        }
    ]
}
```

> [!NOTE]
> I have updated this node role in my case, i was facing some issue with storage-class, where Storage class wasn't able to provisiong the volume.

>> nodegroup role:- eksctl-bellatrix-nodegroup-bellatr-NodeInstanceRole-Y0YxitYH58W0

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Principal": {
				"Service": "ec2.amazonaws.com"
			},
			"Action": "sts:AssumeRole"
		},
		{
			"Effect": "Allow",
			"Principal": {
				"Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.ap-southeast-1.amazonaws.com/id/905FD3625D5E720BDB50A6227B6B654A"
			},
			"Action": "sts:AssumeRoleWithWebIdentity",
			"Condition": {
				"StringEquals": {
					"oidc.eks.ap-southeast-1.amazonaws.com/id/905FD3625D5E720BDB50A6227B6B654A:sub": [
						"system:serviceaccount:mimir:mimir",
						"system:serviceaccount:tempo:tempo",
						"system:serviceaccount:kube-system:ebs-csi-controller-sa"
					],
					"oidc.eks.ap-southeast-1.amazonaws.com/id/905FD3625D5E720BDB50A6227B6B654A:aud": "sts.amazonaws.com"
				}
			}
		}
	]
}
```

>> Below policies needs to be attached to noderole:-

```bash
AmazonEC2ContainerRegistryPowerUser   AWS managed
AmazonEC2ContainerRegistryReadOnly    AWS managed
AmazonEKS_CNI_Policy                  AWS managed
AmazonEKSWorkerNodePolicy             AWS managed
AmazonSSMManagedInstanceCore          AWS managed
```
Amazon_EBS_CSI_Driver                 Inline Policy
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AttachVolume",
                "ec2:CreateSnapshot",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:DeleteSnapshot",
                "ec2:DeleteTags",
                "ec2:DeleteVolume",
                "ec2:DescribeInstances",
                "ec2:DescribeSnapshots",
                "ec2:DescribeTags",
                "ec2:DescribeVolumes",
                "ec2:DetachVolume"
            ],
            "Resource": "*"
        }
    ]
}
```


### Mimir Basic Authentication

Mimir by default does not come with any authentication. Since we will be deploying Mimir to AWS and exposing the gateway to the internet near future, as of now we aren't exposing it to internet, I recommend adding at least basic authentication. In this guide we will give Mimir a `username` and `password`:

1. To start we will need create a `.htpasswd` file with the `username` and `password`. You can use the `htpasswd` command to create the file:

```bash
cd mimir
htpasswd -c .htpasswd mimir-nginx
```

> [!IMPORTANT]
> [!NOTE]
> This will create a file called `auth` with the username you enterned. You will be prompted to enter a password. I am keeping the password as `mimir-nginx` .

2. Create a Kubernetes secret with the .htpasswd file:
```bash
kubectl create secret generic mimir-basic-auth --from-file=.htpasswd -n mimir
```

This will create a secret called mimir-basic-auth in the mimir namespace. We will reference this secret in the Mimir Helm chart configuration.


I have used username & password as `mimir-nginx`.

you can find the mimir helm chart values under mimir directory.


Once this is done, apply below config in `monitoring` **namespace** where we are running prometheus.

```bash
kubectl apply -f mimir/mimir-secret-for-prometheus.yaml
```

It will create a secret in `monitoring` **namespace** named `mimir-remote-write-credentials`


> [!NOTE]
> Now we are deploying all other components like, alloy, mimir & tempo.

```bash
# Navigate the alloy directory & run below commands
kubectl create namespace alloy-logs

kubectl apply -f alloy-logs-configMap.yml

helm repo add grafana https:grafana.github.io/helm-charts
helm repo update

helm upgrade --install grafana-alloy grafana/alloy --namespace alloy-logs -f alloy-override-values.yaml

kubectl get pods -n alloy-logs -l app.kubernetes.io/name=grafana-alloy
kubectl logs -n alloy-logs -l app.kubernetes.io/name=grafana-alloy --tail=100
```

```bash
helm upgrade --install mimir grafana/mimir-distributed -n mimir -f ./mimir/mimir-override-values.yaml
helm upgrade --install tempo grafana/tempo-distributed -n tempo --create-namespace -f ./tempo/tempo-override-values.yaml
```
