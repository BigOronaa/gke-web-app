# Lab Guide: Deploying a Web Application on GKE with Helm, NGINX Ingress, Cert-Manager, Vault, and CI/CD

## Project Overview
In this project, I deployed a containerized web application on **Google Kubernetes Engine (GKE)** using **Helm**. The application is exposed using **NGINX Ingress**, secured with **TLS certificates via cert-manager**, and integrates **HashiCorp Vault** for secrets management. The entire workflow—from image build to deployment—is automated using **GitHub Actions CI/CD**.

This project demonstrates real-world DevOps skills including Kubernetes, Helm, cloud-managed Kubernetes (GKE), ingress and TLS, secrets management, and CI/CD automation.

---

## Problem Statement
I was tasked as a DevOps engineer to design and implement a production-style Kubernetes deployment on GCP. The solution needed to:

- Package the application using Docker
- Store images in Google Artifact Registry
- Deploy to GKE using Helm charts
- Route traffic with NGINX Ingress
- Secure traffic with TLS using cert-manager
- Manage secrets with HashiCorp Vault
- Automate build and deployment using CI/CD

---

## Architecture Summary

- **Cloud Provider:** Google Cloud Platform (GCP)
- **Kubernetes:** Google Kubernetes Engine (GKE)
- **Container Registry:** Google Artifact Registry
- **Ingress:** NGINX Ingress Controller
- **TLS Management:** cert-manager with Let’s Encrypt
- **Secrets Management:** HashiCorp Vault
- **Packaging:** Helm
- **CI/CD:** GitHub Actions

---

## Deliverables

- Docker image pushed to Google Artifact Registry
- Helm chart for the web application
- NGINX Ingress Controller installed on GKE
- cert-manager with ClusterIssuer for TLS
- Vault deployed for secrets management
- GitHub Actions pipeline for CI/CD

---

## Step 1: Prepare the Web Application Docker Image

### Dockerfile
I created a simple Dockerfile using NGINX to serve static web content:

```dockerfile
FROM nginx:latest
COPY . /usr/share/nginx/html
EXPOSE 80
```

### Build the Docker Image

```bash
docker build -t us-central1-docker.pkg.dev/<PROJECT_ID>/my-repo/web-app:latest .
```

### Push Image to Google Artifact Registry

```bash
gcloud auth configure-docker us-central1-docker.pkg.dev
docker push us-central1-docker.pkg.dev/<PROJECT_ID>/my-repo/web-app:latest
```

---

## Step 2: Set Up the GKE Cluster

### Install Required Tools

```bash
# Install gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init

# Install kubectl
gcloud components install kubectl

# Install Docker
sudo apt update
sudo apt install -y docker.io
```

### Create the GKE Cluster

```bash
gcloud container clusters create my-cluster \
  --zone us-central1-a \
  --num-nodes 2 \
  --machine-type e2-medium
```

### Verify Cluster

```bash
kubectl get nodes
```

---

## Step 3: Install NGINX Ingress, Cert-Manager, and Vault

### Install NGINX Ingress Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

**NGINX Ingress values.yaml (example):**

```yaml
controller:
  replicaCount: 2
  service:
    type: LoadBalancer
  metrics:
    enabled: true
```

---

### Install cert-manager

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

### Create ClusterIssuer (Let’s Encrypt)

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

```bash
kubectl apply -f cluster-issuer.yaml
```

---

### Install HashiCorp Vault

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace
```

**Vault values.yaml (example):**

```yaml
server:
  ha:
    enabled: true
    replicas: 3
  ingress:
    enabled: true
    annotations:
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
    hosts:
      - host: vault.example.com
        paths: []
```

---

## Step 4: Deploy the Web Application Using Helm

### Helm Chart Structure

```text
web-app/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── serviceaccount.yaml
│   ├── vault-injector.yaml
│   └── NOTES.txt
```

### Chart.yaml

```yaml
apiVersion: v2
name: web-app
description: Helm chart for deploying a web application on GKE
version: 0.1.0
appVersion: "1.0"
```

### values.yaml (excerpt)

```yaml
replicaCount: 3

image:
  repository: us-central1-docker.pkg.dev/<PROJECT_ID>/my-repo/web-app
  tag: latest
  pullPolicy: Always

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: my-web-app.com
      paths:
        - /
  tls:
    - secretName: my-web-app-tls
      hosts:
        - my-web-app.com
```

---

### Deployment

The application Deployment pulls the image from Artifact Registry and injects configuration using ConfigMaps and Secrets.

```bash
helm dependency update web-app
helm install web-app ./web-app --namespace default
```

### Verify Deployment

```bash
kubectl get deployments
kubectl get services
kubectl get ingress
```

---

## Step 5: CI/CD Pipeline with GitHub Actions

### GitHub Actions Workflow

The pipeline automatically:
1. Builds the Docker image
2. Pushes it to Artifact Registry
3. Deploys the updated Helm release to GKE

```yaml
name: Deploy Web App to GKE

on:
  push:
    branches:
      - main

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - uses: docker/setup-buildx-action@v1

      - name: Login to Artifact Registry
        run: |
          echo "${{ secrets.GCP_SA_KEY }}" | docker login -u _json_key --password-stdin https://us-central1-docker.pkg.dev

      - name: Build and Push Image
        run: |
          docker build -t us-central1-docker.pkg.dev/${{ secrets.GCP_PROJECT_ID }}/my-repo/web-app:latest .
          docker push us-central1-docker.pkg.dev/${{ secrets.GCP_PROJECT_ID }}/my-repo/web-app:latest

  deploy:
    runs-on: ubuntu-latest
    needs: build-and-push
    steps:
      - uses: actions/checkout@v2

      - uses: google-github-actions/setup-gcloud@v0
        with:
          project_id: ${{ secrets.GCP_PROJECT_ID }}
          service_account_key: ${{ secrets.GCP_SA_KEY }}
          export_default_credentials: true

      - name: Configure kubectl
        run: |
          gcloud container clusters get-credentials my-cluster --zone us-central1-a --project ${{ secrets.GCP_PROJECT_ID }}

      - name: Deploy with Helm
        run: |
          helm upgrade --install web-app ./web-app --namespace default
```

---

## Step 6: Testing and Validation

### Access the Application

```bash
curl https://my-web-app.com
```

### Load Testing

```bash
ab -n 1000 -c 10 https://my-web-app.com/
```

---

## Key Learnings

- How to deploy production-style workloads on GKE
- Using Helm to manage Kubernetes complexity
- Automating TLS with cert-manager
- Integrating Vault for secure secrets handling
- Building a complete CI/CD pipeline for Kubernetes deployments

---

## Conclusion

This project simulates a real-world cloud-native deployment on GCP. It ties together containerization, Kubernetes, Helm, ingress management, security, and CI/CD—demonstrating practical DevOps engineering skills suitable for production environments.

