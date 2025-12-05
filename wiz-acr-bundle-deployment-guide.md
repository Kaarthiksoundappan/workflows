# Wiz Helm Chart Bundle Deployment to ACR for Air-Gapped AKS

This guide explains how to bundle Wiz Helm charts and deploy them to Azure Container Registry (ACR) for air-gapped AKS clusters that cannot access public repositories.

---

## Overview

**Problem:** The wiz-kubernetes-integration umbrella chart has dependencies pointing to public Helm repository (https://wiz-sec.github.io/charts). Air-gapped AKS clusters cannot access this, resulting in only the connector pod being deployed.

**Solution:** Bundle all dependency charts inside the umbrella chart and push to ACR as a single package.

**What Gets Deployed:**
- wiz-kubernetes-connector (manages cluster connection to Wiz)
- wiz-admission-controller (admission control and audit logs)
- wiz-sensor (runtime security sensor)

---

## Prerequisites

### On Local Machine (with Internet Access)
- Helm 3.x installed
- Azure CLI installed
- Internet access to download from https://charts.wiz.io
- ACR push permissions

### On AKS Cluster
- kubectl access to target AKS cluster
- No internet access required
- ACR pull permissions configured (via managed identity or service principal)

---

## Part 1: Prepare and Bundle Charts (Internet-Connected Machine)

### Step 1: Create Working Directory

```bash
# Create a dedicated working directory
mkdir -p ~/wiz-acr-bundle
cd ~/wiz-acr-bundle
```

### Step 2: Add Wiz Public Helm Repository

```bash
# Add the Wiz public Helm repository
helm repo add wiz-sec https://charts.wiz.io

# Update repository index
helm repo update

# Verify the repository was added
helm repo list | grep wiz-sec
```

### Step 3: Download Umbrella Chart (Untarred)

```bash
# Pull the wiz-kubernetes-integration chart and extract it
helm pull wiz-sec/wiz-kubernetes-integration --version 0.2.137 --untar

# Verify the chart was extracted
ls -la wiz-kubernetes-integration/
```

**Expected output:**
```
Chart.yaml
values.yaml
templates/
...
```

### Step 4: Download All Dependency Charts

```bash
# Download each dependency chart as .tgz package
helm pull wiz-sec/wiz-kubernetes-connector
helm pull wiz-sec/wiz-admission-controller
helm pull wiz-sec/wiz-sensor

# Verify all charts were downloaded
ls -lh *.tgz
```

**Expected output:**
```
wiz-kubernetes-connector-3.x.x.tgz
wiz-admission-controller-3.x.x.tgz
wiz-sensor-1.x.x.tgz
```

### Step 5: Create Charts Directory in Umbrella Chart

```bash
# Create the charts directory inside the umbrella chart
mkdir -p wiz-kubernetes-integration/charts

# Verify directory was created
ls -la wiz-kubernetes-integration/
```

### Step 6: Bundle Dependencies into Umbrella Chart

```bash
# Move all dependency .tgz files into the charts directory
mv wiz-kubernetes-connector-*.tgz wiz-kubernetes-integration/charts/
mv wiz-admission-controller-*.tgz wiz-kubernetes-integration/charts/
mv wiz-sensor-*.tgz wiz-kubernetes-integration/charts/

# Verify all dependencies are bundled
ls -lh wiz-kubernetes-integration/charts/
```

**Expected output:**
```
wiz-kubernetes-connector-3.x.x.tgz
wiz-admission-controller-3.x.x.tgz
wiz-sensor-1.x.x.tgz
```

### Step 7: Package the Bundled Chart

```bash
# Package the umbrella chart with all bundled dependencies
helm package wiz-kubernetes-integration

# Verify the package was created
ls -lh wiz-kubernetes-integration-0.2.137.tgz
```

### Step 8: Verify Bundle Contents (Optional but Recommended)

```bash
# List contents of the packaged chart to verify dependencies are included
tar -tzf wiz-kubernetes-integration-0.2.137.tgz | grep "charts/"

# Should show all three dependency charts
```

**Expected output:**
```
wiz-kubernetes-integration/charts/wiz-kubernetes-connector-3.x.x.tgz
wiz-kubernetes-integration/charts/wiz-admission-controller-3.x.x.tgz
wiz-kubernetes-integration/charts/wiz-sensor-1.x.x.tgz
```

---

## Part 2: Push Bundled Chart to ACR

### Step 9: Login to Azure and ACR

```bash
# Login to Azure (if not already logged in)
az login

# Login to your Azure Container Registry
# Replace <your-acr-name> with your actual ACR name
az acr login --name <your-acr-name>
```

**Expected output:**
```
Login Succeeded
```

### Step 10: Push Chart to ACR

```bash
# Push the bundled chart to ACR as an OCI artifact
# Replace <your-acr-name> with your actual ACR name
helm push wiz-kubernetes-integration-0.2.137.tgz oci://<your-acr-name>.azurecr.io/helm
```

**Expected output:**
```
Pushed: <your-acr-name>.azurecr.io/helm/wiz-kubernetes-integration:0.2.137
Digest: sha256:...
```

### Step 11: Verify Chart in ACR

```bash
# List the chart in ACR
az acr repository show \
  --name <your-acr-name> \
  --repository helm/wiz-kubernetes-integration

# List all versions/tags
az acr repository show-tags \
  --name <your-acr-name> \
  --repository helm/wiz-kubernetes-integration
```

**Expected output:**
```
[
  "0.2.137"
]
```

---

## Part 3: Deploy to AKS Cluster

### Step 12: Configure AKS to Pull from ACR

If not already configured, attach ACR to your AKS cluster:

```bash
# Attach ACR to AKS (enables AKS to pull images/charts from ACR)
az aks update \
  --name <aks-cluster-name> \
  --resource-group <resource-group> \
  --attach-acr <your-acr-name>

# Verify the attachment
az aks check-acr \
  --name <aks-cluster-name> \
  --resource-group <resource-group> \
  --acr <your-acr-name>.azurecr.io
```

### Step 13: Create Namespace

```bash
# Create the wiz namespace
kubectl create namespace wiz

# Verify namespace was created
kubectl get namespace wiz
```

### Step 14: Create Wiz API Token Secret

```bash
# Create secret with Wiz service account credentials
# Replace ***** with your actual clientId and clientToken
kubectl -n wiz create secret generic wiz-api-token \
  --from-literal clientId=***** \
  --from-literal clientToken=****

# Verify secret was created
kubectl get secret wiz-api-token -n wiz
```

### Step 15: Create values.yaml Configuration File

Create a file named `values.yaml` with the following content:

```yaml
global:
  wizApiToken:
    secret:
      create: false
      name: wiz-api-token

wiz-kubernetes-connector:
  enabled: true
  autoCreateConnector:
    clusterFlavor: AKS
  Wiz-broker:
    enabled: true

wiz-admission-controller:
  enabled: true
  kubernetesAuditLogsWebhook:
    enabled: true

wiz-sensor:
  enabled: true
```

### Step 16: Install from ACR

```bash
# Install the Wiz integration from ACR
# Replace <your-acr-name> with your actual ACR name
helm upgrade --install wiz-integration \
  oci://<your-acr-name>.azurecr.io/helm/wiz-kubernetes-integration \
  --version 0.2.137 \
  --values values.yaml \
  --namespace wiz

# Alternative: Install without values file (use chart defaults)
helm upgrade --install wiz-integration \
  oci://<your-acr-name>.azurecr.io/helm/wiz-kubernetes-integration \
  --version 0.2.137 \
  --namespace wiz \
  --set global.wizApiToken.secret.create=false \
  --set global.wizApiToken.secret.name=wiz-api-token
```

**Expected output:**
```
Release "wiz-integration" does not exist. Installing it now.
NAME: wiz-integration
LAST DEPLOYED: ...
NAMESPACE: wiz
STATUS: deployed
REVISION: 1
```

### Step 17: Verify Deployment

```bash
# Check all pods in the wiz namespace
kubectl get pods -n wiz

# Check with detailed output
kubectl get pods -n wiz -o wide

# Watch pods until they're all running
kubectl get pods -n wiz -w
```

**Expected output (all three types of pods):**
```
NAME                                          READY   STATUS    RESTARTS   AGE
wiz-kubernetes-connector-xxx                  1/1     Running   0          2m
wiz-admission-controller-xxx                  1/1     Running   0          2m
wiz-sensor-xxx                                1/1     Running   0          2m
```

### Step 18: Verify All Deployments

```bash
# List all deployments
kubectl get deployments -n wiz

# Check services
kubectl get services -n wiz

# Check the Helm release
helm list -n wiz
```

### Step 19: Check Pod Logs (Optional)

```bash
# Check connector logs
kubectl logs -n wiz deployment/wiz-kubernetes-connector

# Check admission controller logs
kubectl logs -n wiz deployment/wiz-admission-controller

# Check sensor logs
kubectl logs -n wiz deployment/wiz-sensor
```

---

## Verification Checklist

Use this checklist to ensure successful deployment:

- [ ] All three dependency charts bundled in umbrella chart
- [ ] Chart successfully pushed to ACR
- [ ] AKS cluster attached to ACR
- [ ] Namespace `wiz` created
- [ ] Secret `wiz-api-token` created with valid credentials
- [ ] Helm release installed successfully
- [ ] All three pod types are running:
  - [ ] wiz-kubernetes-connector
  - [ ] wiz-admission-controller
  - [ ] wiz-sensor
- [ ] No pods in CrashLoopBackOff or Error state
- [ ] Pods can communicate with Wiz backend (check logs)

---

## Troubleshooting

### Issue: Only Connector Pod Deployed

**Cause:** Dependencies not bundled in the chart.

**Solution:**
```bash
# Verify dependencies are bundled
helm pull oci://<your-acr-name>.azurecr.io/helm/wiz-kubernetes-integration --version 0.2.137
tar -tzf wiz-kubernetes-integration-0.2.137.tgz | grep "charts/"

# Should show all three .tgz files in charts/ directory
# If not, re-bundle following steps 5-10
```

### Issue: ImagePullBackOff Errors

**Cause:** AKS cannot pull from ACR.

**Solution:**
```bash
# Verify ACR attachment
az aks check-acr \
  --name <aks-cluster-name> \
  --resource-group <resource-group> \
  --acr <your-acr-name>.azurecr.io

# Re-attach if needed
az aks update \
  --name <aks-cluster-name> \
  --resource-group <resource-group> \
  --attach-acr <your-acr-name>
```

### Issue: Pods in CrashLoopBackOff

**Cause:** Invalid Wiz API credentials or connectivity issues.

**Solution:**
```bash
# Check pod logs
kubectl logs -n wiz <pod-name>

# Verify secret exists and has correct keys
kubectl get secret wiz-api-token -n wiz -o yaml

# Recreate secret if needed
kubectl delete secret wiz-api-token -n wiz
kubectl -n wiz create secret generic wiz-api-token \
  --from-literal clientId=<correct-id> \
  --from-literal clientToken=<correct-token>

# Restart deployment
kubectl rollout restart deployment -n wiz
```

### Issue: Chart Not Found in ACR

**Cause:** Chart not pushed or wrong repository path.

**Solution:**
```bash
# List all repositories in ACR
az acr repository list --name <your-acr-name>

# Check specific repository
az acr repository show-tags \
  --name <your-acr-name> \
  --repository helm/wiz-kubernetes-integration

# Re-push if needed (from Step 10)
```

### Issue: Helm Dependency Errors

**Cause:** Chart.yaml still references public repository.

**Solution:**
When bundling charts in the `charts/` directory, Helm uses those instead of downloading from repositories listed in Chart.yaml. No modification to Chart.yaml is needed.

If you still see dependency errors:
```bash
# Verify charts are properly bundled
tar -tzf wiz-kubernetes-integration-0.2.137.tgz | head -30

# Re-package ensuring charts/ directory contains all .tgz files
```

---

## Updating the Chart

When a new version is available:

```bash
# On internet-connected machine
cd ~/wiz-acr-bundle

# Remove old files
rm -rf wiz-kubernetes-integration/
rm -f *.tgz

# Pull new version (update version number)
helm repo update
helm pull wiz-sec/wiz-kubernetes-integration --version <new-version> --untar

# Download new dependencies
helm pull wiz-sec/wiz-kubernetes-connector
helm pull wiz-sec/wiz-admission-controller
helm pull wiz-sec/wiz-sensor

# Bundle again
mkdir -p wiz-kubernetes-integration/charts
mv wiz-kubernetes-connector-*.tgz wiz-kubernetes-integration/charts/
mv wiz-admission-controller-*.tgz wiz-kubernetes-integration/charts/
mv wiz-sensor-*.tgz wiz-kubernetes-integration/charts/

# Package and push
helm package wiz-kubernetes-integration
helm push wiz-kubernetes-integration-<new-version>.tgz oci://<your-acr-name>.azurecr.io/helm

# On AKS cluster, upgrade
helm upgrade wiz-integration \
  oci://<your-acr-name>.azurecr.io/helm/wiz-kubernetes-integration \
  --version <new-version> \
  --values values.yaml \
  --namespace wiz
```

---

## Cleanup (If Needed)

To completely remove the Wiz installation:

```bash
# Uninstall Helm release
helm uninstall wiz-integration -n wiz

# Delete namespace (this deletes everything in it)
kubectl delete namespace wiz

# Remove from ACR (optional)
az acr repository delete \
  --name <your-acr-name> \
  --repository helm/wiz-kubernetes-integration \
  --yes
```

---

## Summary

This guide showed how to:

1. ✅ Download Wiz charts from public repository
2. ✅ Bundle all dependencies into umbrella chart
3. ✅ Push bundled chart to ACR
4. ✅ Deploy to air-gapped AKS cluster
5. ✅ Verify all three components are running

**Key Benefit:** No public internet access required on AKS cluster - everything is bundled and served from ACR.

---

## Additional Resources

- Wiz Documentation: https://docs.wiz.io
- Azure Container Registry: https://docs.microsoft.com/azure/container-registry/
- Helm OCI Support: https://helm.sh/docs/topics/registries/
- AKS Documentation: https://docs.microsoft.com/azure/aks/
