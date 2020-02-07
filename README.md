# Deploying Airflow on Google Kubernetes Engine

## About

I leveraged [an awesome Docker image with Airflow](https://github.com/puckel/docker-airflow).  Terraform for managing GCP infrastructure.  Postgres instance on CloudSQL for the Airflow meta database. I used [git-sync](https://github.com/kubernetes/git-sync) sidecar container to continuously sync DAGs and plugins on running cluster, so only need to rebuild Docker image when changing Python environment.  Packaged all Kubernetes resources in [a Helm chart](https://helm.sh/).  I also used the [kube-lego](https://github.com/kubernetes/charts/tree/master/stable/kube-lego) chart to automatically request TLS certificates for my Ingress (I secured my instance with [Cloud IAP](https://cloud.google.com/iap/), which requires a HTTPS load balancer).

Note: To run Citibike example pipeline, will need to create a Service Account with BigQuery access and add to the `google_cloud_default` [Connection](https://airflow.apache.org/concepts.html#connections) in Airflow UI.

## Deploy Instructions

### (1) Store project id and Fernet key as env variables

``` bash
export NETWORK_ID="network" # The network id/name where you want to deploy your cluster.
export SUBNET_ID="subnet" # The subnet id/name to use.
export PROJECT_ID=$(gcloud config get-value project -q)

if [ ! -f '.keys/fernet.key' ]; then
  export FERNET_KEY=$(python -c "from cryptography.fernet import Fernet; FERNET_KEY = Fernet.generate_key().decode(); print(FERNET_KEY)")
  echo $FERNET_KEY > .keys/fernet.key
else
  export FERNET_KEY=$(cat .keys/fernet.key)
fi
```

### (2) Create Docker image and upload to Google Container Repository

``` bash
docker build -t airflow-gke:latest .
docker tag airflow-gke gcr.io/${PROJECT_ID}/airflow-gke:latest
gcloud docker -- push gcr.io/${PROJECT_ID}/airflow-gke
```

### (3) Create infrastructure with Terraform

Note: You will also need to create a Service Account for the CloudSQL proxy in Kubernetes.  Create that (Role = "Cloud SQL Client"), download the JSON key, and attach as secret.  Stored in `.keys/airflow-cloudsql.json` in this example.

``` bash
terraform apply -var project=${PROJECT_ID} -var network=$(NETWORK_ID) -var subnet=$(SUBNET_ID)

gcloud container clusters get-credentials airflow-cluster
gcloud config set container/cluster airflow-cluster

kubectl create secret generic cloudsql-instance-credentials \
  --from-file=credentials.json=.keys/airflow-cloudsql.json
```

### (4) Set up Helm / Kube-Lego for TLS

``` bash
kubectl create serviceaccount -n kube-system tiller
kubectl create clusterrolebinding tiller-binding --clusterrole=cluster-admin --serviceaccount kube-system:tiller
helm init --service-account tiller

kubectl create namespace kube-lego

helm install \
  --namespace kube-lego \
  --set config.LEGO_EMAIL=donald.rauscher@gmail.com \
  --set config.LEGO_URL=https://acme-v01.api.letsencrypt.org/directory \
  --set config.LEGO_DEFAULT_INGRESS_CLASS=gce \
  stable/kube-lego
```

### (5) Deploy Airflow

``` bash
helm install . \
  --set projectId=${PROJECT_ID} \
  --set fernetKey=${FERNET_KEY}
```

If you want to redeploy Airflow, get first the name of the release:
```
helm list
```

And then, reinstall it:
```
helm upgrade <name> --install  . \
  --set projectId=${PROJECT_ID}  \
  --set fernetKey=${FERNET_KEY}
```


