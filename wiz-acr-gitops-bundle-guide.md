# Wiz Helm Chart Bundle for ACR - GitOps Deployment Guide

Complete standalone guide for bundling Wiz charts for air-gapped AKS with GitOps/Flux deployment.

---

## Overview

This guide shows how to:
1. Bundle Wiz charts with all dependencies
2. Modify chart for pre-created secrets (GitOps-friendly)
3. Push to ACR
4. Deploy using GitOps/Flux

---

## Part 1: Bundle and Prepare Chart (Internet-Connected Machine)

### Step 1: Setup Working Directory

```bash
mkdir -p ~/wiz-acr-bundle
cd ~/wiz-acr-bundle
```

### Step 2: Download Charts from Wiz Public Repository

```bash
# Add Wiz repository
helm repo add wiz-sec https://charts.wiz.io
helm repo update

# Download umbrella chart (extracted)
helm pull wiz-sec/wiz-kubernetes-integration --version 0.2.137 --untar

# Download all dependency charts as .tgz files
helm pull wiz-sec/wiz-kubernetes-connector
helm pull wiz-sec/wiz-admission-controller
helm pull wiz-sec/wiz-sensor

# Verify downloads
ls -lh
```

**Expected output:**
```
wiz-kubernetes-integration/          (directory)
wiz-kubernetes-connector-3.x.x.tgz
wiz-admission-controller-3.x.x.tgz
wiz-sensor-1.x.x.tgz
```

### Step 3: Modify Chart for Pre-Created Secret

This is **critical for GitOps** - we need the chart to use a pre-created secret instead of creating one.

```bash
# Edit the umbrella chart's values.yaml
vi wiz-kubernetes-integration/values.yaml

# OR use sed for automated modification
sed -i '/^global:/,/wizApiToken:/{
  /secret:/,/create:/{
    s/create: true/create: false/
  }
  /secret:/,/name:/{
    s/name: ""/name: "wiz-api-token"/
  }
}' wiz-kubernetes-integration/values.yaml
```

**Manual edit (if using vi/nano):**

Find these lines (around line 16-24):
```yaml
  wizApiToken:
    secret:
      create: true     # ← Change this to false
      name: ""         # ← Change this to "wiz-api-token"
```

Change to:
```yaml
  wizApiToken:
    secret:
      create: false    # ← Changed
      name: "wiz-api-token"  # ← Changed
```

Save and exit.

### Step 4: Verify the Changes

```bash
# Verify the secret configuration was updated
grep -A 10 "wizApiToken:" wiz-kubernetes-integration/values.yaml | grep -A 5 "secret:"
```

**Expected output:**
```yaml
    secret:
      create: false
      name: "wiz-api-token"
```

### Step 5: Bundle Dependencies into Chart

```bash
# Create charts directory inside umbrella chart
mkdir -p wiz-kubernetes-integration/charts

# Move all dependency .tgz files into charts directory
mv wiz-kubernetes-connector-*.tgz wiz-kubernetes-integration/charts/
mv wiz-admission-controller-*.tgz wiz-kubernetes-integration/charts/
mv wiz-sensor-*.tgz wiz-kubernetes-integration/charts/

# Verify bundling
ls -lh wiz-kubernetes-integration/charts/
```

**Expected output:**
```
wiz-kubernetes-connector-3.x.x.tgz
wiz-admission-controller-3.x.x.tgz
wiz-sensor-1.x.x.tgz
```

### Step 6: Package the Bundled Chart

```bash
# Package the umbrella chart with bundled dependencies
helm package wiz-kubernetes-integration

# Verify package created
ls -lh wiz-kubernetes-integration-0.2.137.tgz
```

### Step 7: Verify Bundle Contents

```bash
# List contents to confirm all dependencies are bundled
tar -tzf wiz-kubernetes-integration-0.2.137.tgz | grep "charts/"
```

**Expected output:**
```
wiz-kubernetes-integration/charts/wiz-kubernetes-connector-3.x.x.tgz
wiz-kubernetes-integration/charts/wiz-admission-controller-3.x.x.tgz
wiz-kubernetes-integration/charts/wiz-sensor-1.x.x.tgz
```

### Step 8: Push to ACR

```bash
# Login to Azure and ACR
az login
az acr login --name <your-acr-name>

# Push bundled chart to ACR
helm push wiz-kubernetes-integration-0.2.137.tgz oci://<your-acr-name>.azurecr.io/helm
```

**Expected output:**
```
Pushed: <your-acr-name>.azurecr.io/helm/wiz-kubernetes-integration:0.2.137
Digest: sha256:...
```

### Step 9: Verify in ACR

```bash
# Verify chart is in ACR
az acr repository show-tags \
  --name <your-acr-name> \
  --repository helm/wiz-kubernetes-integration
```

**Expected output:**
```json
[
  "0.2.137"
]
```

---

## Part 2: GitOps Deployment Configuration

### Step 10: Create Wiz API Token Secret Manifest

Create file: `wiz-secret.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: wiz-api-token
  namespace: wiz
type: Opaque
stringData:
  clientId: "YOUR_WIZ_CLIENT_ID"
  clientToken: "YOUR_WIZ_CLIENT_TOKEN"
```

**IMPORTANT:**
- Replace `YOUR_WIZ_CLIENT_ID` and `YOUR_WIZ_CLIENT_TOKEN` with actual values
- For GitOps, consider using Sealed Secrets or External Secrets Operator instead of plain secrets
- This secret must be created BEFORE deploying the Helm release

### Step 11: Create Namespace Manifest

Create file: `namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: wiz
```

### Step 12: Create HelmRepository Manifest

Create file: `wiz-helmrepository.yaml`

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: wiz-acr
  namespace: wiz
spec:
  type: oci
  url: oci://<your-acr-name>.azurecr.io/helm
  interval: 10m
```

Replace `<your-acr-name>` with your actual ACR name.

### Step 13: Create HelmRelease Manifest

Create file: `wiz-helmrelease.yaml`

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: wiz-integration
  namespace: wiz
spec:
  interval: 10m
  chart:
    spec:
      chart: wiz-kubernetes-integration
      version: 0.2.137
      sourceRef:
        kind: HelmRepository
        name: wiz-acr
        namespace: wiz
  values:
    # The bundled chart already has secret.create: false and secret.name: wiz-api-token
    # But we can override if needed

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

### Step 14: Create Kustomization Manifest

Create file: `kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - wiz-secret.yaml
  - wiz-helmrepository.yaml
  - wiz-helmrelease.yaml
```

---

## Part 3: Directory Structure

Your GitOps repository should look like this:

```
wiz-gitops/
├── kustomization.yaml
├── namespace.yaml
├── wiz-secret.yaml          # Or use SealedSecret/ExternalSecret
├── wiz-helmrepository.yaml
└── wiz-helmrelease.yaml
```

---

## Part 4: Deploy Using GitOps

### Option A: Using Flux Directly

```bash
# Ensure Flux is installed on your cluster
flux check

# Create a GitRepository source (if not already done)
flux create source git wiz-deployment \
  --url=https://github.com/your-org/your-repo \
  --branch=main \
  --interval=1m

# Create a Kustomization to deploy
flux create kustomization wiz \
  --source=GitRepository/wiz-deployment \
  --path=./wiz-gitops \
  --prune=true \
  --interval=10m
```

### Option B: Commit to Git and Let Flux Sync

```bash
# Add files to git
git add wiz-gitops/
git commit -m "Add Wiz deployment manifests"
git push

# Flux will automatically detect and apply
# Monitor the deployment
flux get kustomizations
flux get helmreleases -n wiz
```

---

## Part 5: Verification

### Step 15: Check Flux Resources

```bash
# Check HelmRepository
kubectl get helmrepository -n wiz

# Check HelmRelease
kubectl get helmrelease -n wiz

# Check HelmRelease status
flux get helmrelease wiz-integration -n wiz
```

### Step 16: Verify Pods

```bash
# Check all pods in wiz namespace
kubectl get pods -n wiz

# Watch until all are running
kubectl get pods -n wiz -w
```

**Expected output:**
```
NAME                                          READY   STATUS    RESTARTS   AGE
wiz-kubernetes-connector-xxx                  1/1     Running   0          2m
wiz-admission-controller-xxx                  1/1     Running   0          2m
wiz-sensor-xxx                                1/1     Running   0          2m
```

### Step 17: Check Helm Release

```bash
# List Helm releases
helm list -n wiz

# Get release details
helm get values wiz-integration -n wiz
```

---

## Troubleshooting

### Issue: Only Connector Pod Deployed

**Check if dependencies are bundled:**
```bash
# Pull chart from ACR
helm pull oci://<your-acr-name>.azurecr.io/helm/wiz-kubernetes-integration --version 0.2.137

# Check contents
tar -tzf wiz-kubernetes-integration-0.2.137.tgz | grep charts/

# Should show all three dependency .tgz files
```

**Solution:** Re-bundle following steps 5-8.

### Issue: Secret Not Found

**Check secret exists:**
```bash
kubectl get secret wiz-api-token -n wiz

# View secret (base64 encoded)
kubectl get secret wiz-api-token -n wiz -o yaml
```

**Solution:** Ensure `wiz-secret.yaml` is applied before HelmRelease.

In `kustomization.yaml`, resources are applied in order, so put `wiz-secret.yaml` before `wiz-helmrelease.yaml`.

### Issue: HelmRelease Failed

**Check HelmRelease status:**
```bash
kubectl describe helmrelease wiz-integration -n wiz

# Check Flux logs
flux logs --level=error
```

**Common causes:**
- ACR authentication issues
- Chart version not found
- Values syntax errors

### Issue: ImagePullBackOff

**Verify ACR access:**
```bash
# Check if AKS is attached to ACR
az aks check-acr \
  --name <aks-cluster-name> \
  --resource-group <resource-group> \
  --acr <your-acr-name>.azurecr.io

# Attach if needed
az aks update \
  --name <aks-cluster-name> \
  --resource-group <resource-group> \
  --attach-acr <your-acr-name>
```

### Issue: Chart Secret Still Being Created

**Verify values in deployed release:**
```bash
helm get values wiz-integration -n wiz

# Check if secret.create is false
```

**Solution:** Ensure Step 3 was completed correctly. Re-package and push.

---

## Security Best Practices for GitOps

### Using Sealed Secrets (Recommended)

Instead of plain `wiz-secret.yaml`:

```bash
# Install Sealed Secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Create sealed secret
kubectl create secret generic wiz-api-token \
  --from-literal=clientId=YOUR_CLIENT_ID \
  --from-literal=clientToken=YOUR_CLIENT_TOKEN \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > wiz-sealedsecret.yaml

# Commit sealed secret to Git (safe)
git add wiz-sealedsecret.yaml
```

### Using External Secrets Operator

Create file: `wiz-externalsecret.yaml`

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: wiz-api-token
  namespace: wiz
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: azure-keyvault
    kind: SecretStore
  target:
    name: wiz-api-token
  data:
    - secretKey: clientId
      remoteRef:
        key: wiz-client-id
    - secretKey: clientToken
      remoteRef:
        key: wiz-client-token
```

---

## Quick Reference Commands

### Bundle Chart
```bash
cd ~/wiz-acr-bundle
helm repo add wiz-sec https://charts.wiz.io && helm repo update
helm pull wiz-sec/wiz-kubernetes-integration --version 0.2.137 --untar
helm pull wiz-sec/{wiz-kubernetes-connector,wiz-admission-controller,wiz-sensor}
sed -i 's/create: true/create: false/' wiz-kubernetes-integration/values.yaml
sed -i 's/name: ""/name: "wiz-api-token"/' wiz-kubernetes-integration/values.yaml
mkdir -p wiz-kubernetes-integration/charts
mv wiz-*.tgz wiz-kubernetes-integration/charts/
helm package wiz-kubernetes-integration
```

### Push to ACR
```bash
az acr login --name <your-acr-name>
helm push wiz-kubernetes-integration-0.2.137.tgz oci://<your-acr-name>.azurecr.io/helm
```

### Verify Deployment
```bash
kubectl get pods -n wiz
flux get helmrelease wiz-integration -n wiz
helm list -n wiz
```

---

## Summary Checklist

- [ ] Downloaded and extracted wiz-kubernetes-integration chart
- [ ] Modified values.yaml: `secret.create: false`, `secret.name: "wiz-api-token"`
- [ ] Downloaded all three dependency charts
- [ ] Bundled dependencies into `charts/` directory
- [ ] Packaged umbrella chart
- [ ] Pushed to ACR
- [ ] Created namespace manifest
- [ ] Created secret manifest (or SealedSecret/ExternalSecret)
- [ ] Created HelmRepository pointing to ACR
- [ ] Created HelmRelease with proper values
- [ ] Created Kustomization manifest
- [ ] Committed to Git repository
- [ ] Flux deployed all resources
- [ ] All three pod types running: connector, admission-controller, sensor

---

## Next Steps After Deployment

1. **Monitor pods:** `kubectl get pods -n wiz -w`
2. **Check logs:** `kubectl logs -n wiz deployment/wiz-sensor`
3. **Verify in Wiz Console:** Check if cluster appears in Wiz dashboard
4. **Test admission controller:** Deploy a test pod and verify policy enforcement
5. **Set up alerts:** Configure Flux alerts for HelmRelease failures

---

## Complete Example Session

```bash
# Part 1: Bundle (on internet-connected machine)
mkdir -p ~/wiz-acr-bundle && cd ~/wiz-acr-bundle
helm repo add wiz-sec https://charts.wiz.io && helm repo update
helm pull wiz-sec/wiz-kubernetes-integration --version 0.2.137 --untar
helm pull wiz-sec/wiz-kubernetes-connector
helm pull wiz-sec/wiz-admission-controller
helm pull wiz-sec/wiz-sensor

# Modify for pre-created secret
sed -i '/secret:/,/create:/ s/create: true/create: false/' wiz-kubernetes-integration/values.yaml
sed -i '/secret:/,/name:/ s/name: ""/name: "wiz-api-token"/' wiz-kubernetes-integration/values.yaml

# Bundle and package
mkdir -p wiz-kubernetes-integration/charts
mv wiz-kubernetes-connector-*.tgz wiz-admission-controller-*.tgz wiz-sensor-*.tgz wiz-kubernetes-integration/charts/
helm package wiz-kubernetes-integration

# Push to ACR
az acr login --name myacr
helm push wiz-kubernetes-integration-0.2.137.tgz oci://myacr.azurecr.io/helm

# Part 2: GitOps (create manifests and commit)
# ... create YAML files as shown above ...
git add wiz-gitops/ && git commit -m "Add Wiz deployment" && git push

# Part 3: Verify
flux get helmrelease wiz-integration -n wiz
kubectl get pods -n wiz
```

---

## Additional Resources

- Flux Helm Controller: https://fluxcd.io/docs/components/helm/
- Sealed Secrets: https://github.com/bitnami-labs/sealed-secrets
- External Secrets: https://external-secrets.io/
- Wiz Documentation: https://docs.wiz.io
