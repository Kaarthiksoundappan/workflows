# Manual Helm Install from ACR

This guide covers deploying Wiz Kubernetes Integration using **manual Helm commands** instead of GitOps.

## When to Use This Method

- **Development/Testing**: Quick deployments for testing
- **No GitOps**: Cluster doesn't have Flux/ArgoCD
- **Direct Control**: Want full control over helm commands
- **CI/CD Pipelines**: Integrate with custom deployment pipelines

## Prerequisites

Same as GitOps deployment:
- ✅ Images mirrored to ACR (run `mirror-images-to-acr.sh`)
- ✅ Helm chart pushed to ACR
- ✅ Kubernetes cluster access
- ✅ Wiz API credentials

## Installation Steps

### Step 1: Create Namespace

```bash
kubectl create namespace wiz
```

### Step 2: Create Secrets

#### ACR Pull Secret

```bash
kubectl create secret docker-registry acr-credentials \
  --docker-server=your-acr-name.azurecr.io \
  --docker-username=<acr-username> \
  --docker-password=<acr-password> \
  --namespace=wiz
```

**For AKS with Managed Identity (Recommended):**
```bash
# No secret needed - attach ACR to AKS
az aks update \
  --name your-aks-cluster \
  --resource-group your-rg \
  --attach-acr your-acr-name
```

#### Wiz API Token Secret

```bash
kubectl create secret generic wiz-api-token \
  --from-literal=clientId=<your-wiz-client-id> \
  --from-literal=clientToken=<your-wiz-client-secret> \
  --namespace=wiz
```

### Step 3: Login to ACR

```bash
az acr login --name your-acr-name
```

### Step 4: Install Using Helm

You have **three options** for providing configuration:

---

## Option A: Using Custom Values File (Recommended)

**1. Update the values file:**

```bash
# Edit values-acr.yaml
vi values-acr.yaml

# Replace 'your-acr-name' with your actual ACR name
sed -i 's/your-acr-name/mycompanyacr/g' values-acr.yaml
```

**2. Install:**

```bash
helm install wiz-integration \
  oci://your-acr-name.azurecr.io/helm/wiz-kubernetes-integration \
  --version 0.2.142 \
  --namespace wiz \
  --values values-acr.yaml \
  --wait \
  --timeout 10m
```

**3. Verify:**

```bash
helm list -n wiz
kubectl get all -n wiz
```

---

## Option B: Using --set Flags

For simpler deployments or scripts:

```bash
helm install wiz-integration \
  oci://your-acr-name.azurecr.io/helm/wiz-kubernetes-integration \
  --version 0.2.142 \
  --namespace wiz \
  --set global.wizApiToken.secret.create=false \
  --set global.wizApiToken.secret.name=wiz-api-token \
  --set global.image.registry=your-acr-name.azurecr.io/wiz \
  --set global.imagePullSecrets[0].name=acr-credentials \
  --set wiz-kubernetes-connector.enabled=true \
  --set wiz-kubernetes-connector.autoCreateConnector.clusterFlavor=AKS \
  --set wiz-kubernetes-connector.Wiz-broker.enabled=true \
  --set wiz-admission-controller.enabled=true \
  --set wiz-admission-controller.image.registry=your-acr-name.azurecr.io/wiz \
  --set wiz-admission-controller.kubernetesAuditLogsWebhook.enabled=true \
  --set wiz-sensor.enabled=true \
  --set wiz-sensor.image.registry=your-acr-name.azurecr.io/wiz \
  --set wiz-sensor.imagePullSecret.required=true \
  --set wiz-sensor.imagePullSecret.create=false \
  --set wiz-sensor.imagePullSecret.name=acr-credentials \
  --wait \
  --timeout 10m
```

---

## Option C: Hybrid Approach

Combine values file with additional --set overrides:

```bash
helm install wiz-integration \
  oci://your-acr-name.azurecr.io/helm/wiz-kubernetes-integration \
  --version 0.2.142 \
  --namespace wiz \
  --values values-acr.yaml \
  --set wiz-sensor.enabled=false \
  --wait
```

---

## Post-Installation Verification

### Check Deployment Status

```bash
# Helm release status
helm status wiz-integration -n wiz

# All resources
kubectl get all -n wiz

# Pods should be running
kubectl get pods -n wiz
```

**Expected pods:**
```
NAME                                                    READY   STATUS    RESTARTS
wiz-integration-wiz-admission-controller-xxx            1/1     Running   0
wiz-integration-wiz-kubernetes-connector-xxx            1/1     Running   0
wiz-integration-wiz-broker-xxx                          1/1     Running   0
wiz-integration-wiz-sensor-xxx                          1/1     Running   0
```

### Check Logs

```bash
# Admission controller
kubectl logs -n wiz deployment/wiz-integration-wiz-admission-controller

# Connector
kubectl logs -n wiz deployment/wiz-integration-wiz-kubernetes-connector

# Broker
kubectl logs -n wiz deployment/wiz-integration-wiz-broker

# Sensor (DaemonSet - runs on each node)
kubectl logs -n wiz daemonset/wiz-integration-wiz-sensor
```

### Verify in Wiz Portal

1. Login to [Wiz Portal](https://app.wiz.io)
2. Navigate to: **Settings > Integrations > Kubernetes**
3. Verify your cluster appears and is connected

---

## Upgrade Procedure

### Update to New Version

```bash
# Pull new chart version info
helm search repo wiz-sec/wiz-kubernetes-integration --versions

# Upgrade installation
helm upgrade wiz-integration \
  oci://your-acr-name.azurecr.io/helm/wiz-kubernetes-integration \
  --version 0.2.143 \
  --namespace wiz \
  --values values-acr.yaml \
  --wait
```

### Update Configuration Only

```bash
# Modify values-acr.yaml
vi values-acr.yaml

# Upgrade with same version but new values
helm upgrade wiz-integration \
  oci://your-acr-name.azurecr.io/helm/wiz-kubernetes-integration \
  --version 0.2.142 \
  --namespace wiz \
  --values values-acr.yaml \
  --reuse-values \
  --wait
```

---

## Rollback

If something goes wrong:

```bash
# List revisions
helm history wiz-integration -n wiz

# Rollback to previous version
helm rollback wiz-integration -n wiz

# Rollback to specific revision
helm rollback wiz-integration 1 -n wiz
```

---

## Uninstallation

```bash
# Uninstall Helm release
helm uninstall wiz-integration -n wiz

# Clean up secrets (if needed)
kubectl delete secret acr-credentials -n wiz
kubectl delete secret wiz-api-token -n wiz

# Delete namespace (if desired)
kubectl delete namespace wiz
```

---

## Troubleshooting

### Image Pull Errors

**Symptom:** Pods stuck in `ImagePullBackOff`

**Check:**
```bash
kubectl describe pod <pod-name> -n wiz

# Verify images exist in ACR
az acr repository list --name your-acr-name --output table | grep wiz
```

**Fix:**
- Ensure `mirror-images-to-acr.sh` was run successfully
- Verify ACR credentials secret is correct
- For AKS, ensure ACR is attached

### Helm Chart Not Found

**Symptom:** `Error: failed to download "oci://..."`

**Check:**
```bash
# Verify chart exists in ACR
az acr repository show-tags \
  --name your-acr-name \
  --repository helm/wiz-kubernetes-integration

# Login to ACR
az acr login --name your-acr-name
```

**Fix:**
- Ensure chart was pushed: `helm push wiz-kubernetes-integration-0.2.142.tgz oci://your-acr.azurecr.io/helm`

### Connector Not Registering

**Symptom:** Cluster doesn't appear in Wiz portal

**Check:**
```bash
kubectl logs -n wiz deployment/wiz-integration-wiz-kubernetes-connector

# Verify API token
kubectl get secret wiz-api-token -n wiz -o jsonpath='{.data.clientId}' | base64 -d
```

**Fix:**
- Verify Wiz API credentials are correct
- Check network connectivity to Wiz API
- Ensure correct `clientEndpoint` for your Wiz environment

### Values Not Applied

**Symptom:** Wrong image registry being used

**Check:**
```bash
# View effective values
helm get values wiz-integration -n wiz --all

# View manifest
helm get manifest wiz-integration -n wiz | grep image:
```

**Fix:**
- Ensure values file has correct overrides
- Use `--values` flag, not `-f` (both work, but be consistent)
- Check for typos in keys (YAML is case-sensitive)

---

## Comparison: GitOps vs Manual

| Aspect | GitOps (Flux) | Manual Helm |
|--------|---------------|-------------|
| **Deployment** | Automatic via Git commit | Manual `helm install` |
| **Configuration** | HelmRelease YAML | values.yaml or --set |
| **Updates** | Git push → auto-deploy | Manual `helm upgrade` |
| **Rollback** | Git revert | `helm rollback` |
| **Audit Trail** | Git history | Helm history |
| **Multi-Cluster** | Easy (multiple Kustomizations) | Manual per cluster |
| **Best For** | Production, multiple clusters | Development, testing |

---

## Advanced: Helm Template (Dry Run)

Before installing, preview the generated manifests:

```bash
# Generate manifests without installing
helm template wiz-integration \
  oci://your-acr-name.azurecr.io/helm/wiz-kubernetes-integration \
  --version 0.2.142 \
  --namespace wiz \
  --values values-acr.yaml \
  > wiz-manifests.yaml

# Review
less wiz-manifests.yaml

# Apply manually if desired
kubectl apply -f wiz-manifests.yaml
```

---

## CI/CD Pipeline Integration

### GitHub Actions Example

```yaml
name: Deploy Wiz to AKS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Set AKS context
        uses: azure/aks-set-context@v1
        with:
          resource-group: your-rg
          cluster-name: your-aks-cluster

      - name: Deploy Wiz
        run: |
          az acr login --name ${{ secrets.ACR_NAME }}

          helm upgrade --install wiz-integration \
            oci://${{ secrets.ACR_NAME }}.azurecr.io/helm/wiz-kubernetes-integration \
            --version 0.2.142 \
            --namespace wiz \
            --create-namespace \
            --set global.image.registry=${{ secrets.ACR_NAME }}.azurecr.io/wiz \
            --set global.wizApiToken.secret.name=wiz-api-token \
            --wait
```

---

## Key Takeaway

**You don't need to modify sub-charts for either deployment method!**

- **GitOps**: Values in `helmrelease.yaml` override sub-chart defaults
- **Manual**: Values in `values-acr.yaml` or `--set` flags override sub-chart defaults

Both use Helm's built-in value precedence to override the default registries.

---

## Additional Resources

- [Helm Values Documentation](https://helm.sh/docs/chart_template_guide/values_files/)
- [Helm OCI Registry Support](https://helm.sh/docs/topics/registries/)
- [Azure ACR with AKS](https://docs.microsoft.com/en-us/azure/aks/cluster-container-registry-integration)
