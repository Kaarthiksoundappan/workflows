# Steps to Deploy Wiz Charts to ACR for Air-Gapped AKS

## Problem
The wiz-kubernetes-integration umbrella chart has dependencies pointing to public Helm repository (https://wiz-sec.github.io/charts), which your AKS cluster cannot access. This causes only the connector pod to deploy while sensor and admission-controller are missing.

## Root Cause
The Chart.yaml contains dependencies that reference the public repository:
```yaml
dependencies:
- repository: https://wiz-sec.github.io/charts  # ← AKS can't reach this
  name: wiz-kubernetes-connector
- repository: https://wiz-sec.github.io/charts  # ← AKS can't reach this
  name: wiz-admission-controller
- repository: https://wiz-sec.github.io/charts  # ← AKS can't reach this
  name: wiz-sensor
```

## Solution Overview
You have two options:
1. **Bundle subcharts** (Recommended - simpler)
2. **Update Chart.yaml dependencies** to point to ACR

---

## Option 1: Bundle Subcharts (Recommended)

This method packages all dependencies directly into the umbrella chart.

### Step 1: Download All Charts from Public Repository

```bash
# On a machine with internet access
mkdir -p ~/wiz-acr-setup
cd ~/wiz-acr-setup

# Add Wiz public repository
helm repo add wiz-sec https://charts.wiz.io
helm repo update

# Pull the umbrella chart (untarred)
helm pull wiz-sec/wiz-kubernetes-integration --version 0.2.137 --untar

# Pull all dependency charts as .tgz files
helm pull wiz-sec/wiz-kubernetes-connector
helm pull wiz-sec/wiz-admission-controller
helm pull wiz-sec/wiz-sensor
```

### Step 2: Bundle Dependencies into Charts Directory

```bash
# Create charts directory inside the umbrella chart
mkdir -p wiz-kubernetes-integration/charts

# Move all dependency .tgz files into the charts directory
mv wiz-kubernetes-connector-*.tgz wiz-kubernetes-integration/charts/
mv wiz-admission-controller-*.tgz wiz-kubernetes-integration/charts/
mv wiz-sensor-*.tgz wiz-kubernetes-integration/charts/

# Verify
ls -lh wiz-kubernetes-integration/charts/
# Should show:
# wiz-kubernetes-connector-3.x.x.tgz
# wiz-admission-controller-3.x.x.tgz
# wiz-sensor-1.x.x.tgz
```

### Step 3: Repackage and Push to ACR

```bash
# Login to ACR
az acr login --name <your-acr-name>

# Package the umbrella chart with bundled dependencies
helm package wiz-kubernetes-integration

# Push to ACR
helm push wiz-kubernetes-integration-0.2.137.tgz oci://<your-acr-name>.azurecr.io/helm
```

### Step 4: Deploy from ACR

```bash
# On AKS cluster or with kubectl access
kubectl create namespace wiz
kubectl -n wiz create secret generic wiz-api-token \
  --from-literal clientId=***** \
  --from-literal clientToken=****

# Install from ACR - now all dependencies are bundled
helm upgrade --install wiz-integration \
  oci://<your-acr-name>.azurecr.io/helm/wiz-kubernetes-integration \
  --version 0.2.137 \
  --values values.yaml \
  -n wiz
```

### Step 5: Verify All Pods Deployed

```bash
kubectl get pods -n wiz

# Expected output (all three types):
# NAME                                          READY   STATUS    RESTARTS   AGE
# wiz-kubernetes-connector-xxx                  1/1     Running   0          2m
# wiz-admission-controller-xxx                  1/1     Running   0          2m
# wiz-sensor-xxx                                1/1     Running   0          2m
```

---

## Option 2: Update Chart.yaml Dependencies to Point to ACR

This method updates the Chart.yaml to reference ACR-hosted dependencies.

### Step 1: Download and Push Individual Charts to ACR

```bash
# On machine with internet access
helm repo add wiz-sec https://charts.wiz.io
helm repo update

# Pull individual dependency charts
helm pull wiz-sec/wiz-kubernetes-connector
helm pull wiz-sec/wiz-admission-controller
helm pull wiz-sec/wiz-sensor
helm pull wiz-sec/wiz-kubernetes-integration --version 0.2.137 --untar

# Login to ACR
az acr login --name <your-acr-name>

# Push dependencies to ACR
helm push wiz-kubernetes-connector-*.tgz oci://<your-acr-name>.azurecr.io/helm
helm push wiz-admission-controller-*.tgz oci://<your-acr-name>.azurecr.io/helm
helm push wiz-sensor-*.tgz oci://<your-acr-name>.azurecr.io/helm

# Note the exact versions pushed (e.g., 3.5.2, 3.6.1, 1.0.8401)
```

### Step 2: Update Chart.yaml Dependencies

Edit `wiz-kubernetes-integration/Chart.yaml`:

```yaml
apiVersion: v2
dependencies:
- condition: wiz-kubernetes-connector.enabled
  name: wiz-kubernetes-connector
  repository: oci://<your-acr-name>.azurecr.io/helm
  version: 3.5.2  # Use exact version you pushed
- condition: wiz-admission-controller.enabled
  name: wiz-admission-controller
  repository: oci://<your-acr-name>.azurecr.io/helm
  version: 3.6.1  # Use exact version you pushed
- condition: wiz-sensor.enabled
  name: wiz-sensor
  repository: oci://<your-acr-name>.azurecr.io/helm
  version: 1.0.8401  # Use exact version you pushed
description: A Helm chart for Kubernetes
name: wiz-kubernetes-integration
type: application
version: 0.2.137
```

### Step 3: Build Dependencies and Repackage

```bash
cd wiz-kubernetes-integration

# This will download dependencies from ACR to charts/ directory
helm dependency build

# Verify dependencies were downloaded
ls -lh charts/

# Go back and package
cd ..
helm package wiz-kubernetes-integration

# Push to ACR
helm push wiz-kubernetes-integration-0.2.137.tgz oci://<your-acr-name>.azurecr.io/helm
```

**Note:** `helm dependency build` requires Helm to authenticate to your ACR, which must be done on a machine with ACR access.

---

## Comparison: Which Option to Choose?

| Aspect | Option 1: Bundle | Option 2: Update Chart.yaml |
|--------|------------------|----------------------------|
| Complexity | Simpler | More complex |
| Updates | Repackage entire chart | Update individual charts |
| Chart size | Larger (all bundled) | Smaller (references) |
| Dependency resolution | None (pre-bundled) | At install time |
| **Recommended for** | **Air-gapped clusters** | Partial internet access |

**For your use case (no public internet access):** Use **Option 1 (Bundle)** - it's simpler and guarantees all dependencies are included.

---

## Troubleshooting

### Only Connector Pod Shows Up

```bash
# Check what charts were actually deployed
helm get manifest wiz-integration -n wiz | grep "kind: Deployment"

# Check if dependencies are present
helm pull oci://<your-acr-name>.azurecr.io/helm/wiz-kubernetes-integration --version 0.2.137
tar -tzf wiz-kubernetes-integration-0.2.137.tgz | grep charts/

# Expected output:
# wiz-kubernetes-integration/charts/wiz-kubernetes-connector-x.x.x.tgz
# wiz-kubernetes-integration/charts/wiz-admission-controller-x.x.x.tgz
# wiz-kubernetes-integration/charts/wiz-sensor-x.x.x.tgz
```

### Verify Bundled Chart Before Pushing

```bash
# Before pushing to ACR, verify the package
tar -tzf wiz-kubernetes-integration-0.2.137.tgz | head -20

# Should show charts/*.tgz files
```
