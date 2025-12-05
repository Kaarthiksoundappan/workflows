# Wiz Kubernetes Integration - ACR Deployment Guide

This folder contains all the necessary files to deploy Wiz Kubernetes Integration using Azure Container Registry (ACR) instead of public registries.

## Contents

- `helmrepo.yaml` - Flux HelmRepository pointing to ACR OCI registry
- `helmrelease.yaml` - Flux HelmRelease with ACR image overrides
- `kustomization.yaml` - Kustomize manifest for GitOps deployment
- `wiz-kubernetes-integration-0.2.142.tgz` - Wiz Helm chart package
- `wiz-kubernetes-integration/` - Extracted chart for reference
- `mirror-images-to-acr.sh` - Script to mirror all images to ACR

## Prerequisites

- Azure Container Registry (ACR) created
- Azure CLI installed and logged in
- Docker installed
- Helm 3.x installed
- kubectl configured for target cluster
- Flux CD installed on cluster (for GitOps deployment)
- Wiz API token (obtain from Wiz portal)
- Wiz sensor registry credentials (obtain from Wiz support)

## Deployment Methods

This folder supports **two deployment approaches**:

1. **GitOps (Flux CD)** - Automated, declarative deployments via Git
   - Uses: `helmrepo.yaml`, `helmrelease.yaml`, `kustomization.yaml`
   - See: This README (below)

2. **Manual Helm Install** - Direct helm commands
   - Uses: `values-acr.yaml`
   - See: [MANUAL-INSTALL.md](MANUAL-INSTALL.md)

---

## GitOps Deployment (Recommended for Production)

### Step 1: Mirror Container Images to ACR

All Wiz component images must be mirrored to your ACR:

```bash
# Configure the script
vi mirror-images-to-acr.sh

# Update these values:
ACR_NAME="your-acr-name"
WIZ_SENSOR_USERNAME="<from-wiz-support>"
WIZ_SENSOR_PASSWORD="<from-wiz-support>"

# Make executable and run
chmod +x mirror-images-to-acr.sh
./mirror-images-to-acr.sh
```

**Images that will be mirrored:**
- `wiz-admission-controller:2.11` - Policy enforcement webhook
- `wiz-kubernetes-connector:3.0` - Cluster connector
- `wiz-broker:latest` - Communication broker
- `sensor:v1` - Runtime sensor (requires Wiz credentials)
- `wiz-workload-scanner:v1` - Disk scanner (requires Wiz credentials)

### Step 2: Push Helm Chart to ACR

```bash
# Login to ACR
az acr login --name your-acr-name

# Push the chart to ACR OCI registry
helm push wiz-kubernetes-integration-0.2.142.tgz oci://your-acr-name.azurecr.io/helm
```

**Verify chart upload:**
```bash
az acr repository list --name your-acr-name --output table
az acr repository show-tags --name your-acr-name --repository helm/wiz-kubernetes-integration
```

### Step 3: Create Kubernetes Secrets

#### ACR Pull Secret

```bash
# Create namespace
kubectl create namespace wiz

# Create ACR credentials secret
kubectl create secret docker-registry acr-credentials \
  --docker-server=your-acr-name.azurecr.io \
  --docker-username=<acr-username> \
  --docker-password=<acr-password> \
  --namespace=wiz

# Verify secret
kubectl get secret acr-credentials -n wiz
```

**For Azure AKS with Managed Identity:**
```bash
# Attach ACR to AKS cluster (no secret needed)
az aks update \
  --name your-aks-cluster \
  --resource-group your-resource-group \
  --attach-acr your-acr-name
```

#### Wiz API Token Secret

```bash
# Obtain from Wiz Portal: Settings > Service Accounts > Create Service Account
kubectl create secret generic wiz-api-token \
  --from-literal=clientId=<wiz-client-id> \
  --from-literal=clientToken=<wiz-client-secret> \
  --namespace=wiz

# Verify secret
kubectl get secret wiz-api-token -n wiz
```

### Step 4: Update Configuration Files

#### Update `helmrepo.yaml`

```yaml
spec:
  url: oci://your-acr-name.azurecr.io/helm  # Replace your-acr-name
  secretRef:
    name: acr-credentials
```

#### Update `helmrelease.yaml`

Replace all instances of `your-acr-name` with your actual ACR name:

```yaml
values:
  global:
    image:
      registry: your-acr-name.azurecr.io/wiz  # Update here

  wiz-admission-controller:
    image:
      registry: your-acr-name.azurecr.io/wiz  # Update here

  wiz-sensor:
    image:
      registry: your-acr-name.azurecr.io/wiz  # Update here
```

### Step 5: Deploy via GitOps (Flux CD)

#### Option A: Using Kustomization

```bash
# Apply kustomization directly
kubectl apply -k .
```

#### Option B: Flux GitOps

1. Commit files to your Git repository:
```bash
git add helmrepo.yaml helmrelease.yaml kustomization.yaml
git commit -m "Add Wiz ACR deployment configuration"
git push
```

2. Create Flux Kustomization:
```bash
flux create kustomization wiz-integration \
  --source=GitRepository/your-repo \
  --path=./path/to/acrurl \
  --prune=true \
  --interval=10m \
  --namespace=wiz
```

3. Monitor deployment:
```bash
# Watch Flux reconciliation
flux get kustomizations wiz-integration

# Check HelmRelease status
flux get helmreleases -n wiz

# View pods
kubectl get pods -n wiz
```

### Step 6: Verify Deployment

```bash
# Check all Wiz components
kubectl get all -n wiz

# Expected deployments:
kubectl get deployments -n wiz
# - wiz-integration-wiz-admission-controller
# - wiz-integration-wiz-kubernetes-connector
# - wiz-integration-wiz-broker

# Check DaemonSet (sensor runs on every node)
kubectl get daemonsets -n wiz
# - wiz-integration-wiz-sensor

# Check component logs
kubectl logs -n wiz deployment/wiz-integration-wiz-admission-controller
kubectl logs -n wiz deployment/wiz-integration-wiz-broker
kubectl logs -n wiz daemonset/wiz-integration-wiz-sensor
```

## Image Registry Structure in ACR

After mirroring, your ACR will have:

```
your-acr-name.azurecr.io/
├── helm/
│   └── wiz-kubernetes-integration:0.2.142
└── wiz/
    ├── wiz-admission-controller:2.11
    ├── wiz-kubernetes-connector:3.0
    ├── wiz-broker:latest
    ├── sensor:v1
    └── wiz-workload-scanner:v1
```

## Troubleshooting

### Image Pull Errors

```bash
# Check if images exist in ACR
az acr repository list --name your-acr-name --output table

# Verify secret is correct
kubectl get secret acr-credentials -n wiz -o yaml

# Check pod events
kubectl describe pod <pod-name> -n wiz
```

### Authentication Errors

```bash
# For wiz-sensor image pull issues:
# 1. Verify you have valid Wiz sensor credentials
# 2. Ensure credentials are set in mirror-images-to-acr.sh
# 3. Re-run the mirror script

# Check if image was mirrored
az acr repository show-tags \
  --name your-acr-name \
  --repository wiz/sensor
```

### HelmRelease Failures

```bash
# Check HelmRelease status
kubectl get helmrelease wiz-integration -n wiz -o yaml

# View Flux logs
flux logs --level=error

# Check if chart exists in ACR
az acr repository show-tags \
  --name your-acr-name \
  --repository helm/wiz-kubernetes-integration
```

### Connector Not Registering

```bash
# Check connector logs
kubectl logs -n wiz deployment/wiz-integration-wiz-kubernetes-connector

# Verify Wiz API token is correct
kubectl get secret wiz-api-token -n wiz -o jsonpath='{.data.clientId}' | base64 -d

# Check connectivity to Wiz API
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v https://api.wiz.io/health
```

## Updating to New Versions

When a new Wiz chart version is released:

1. Download new chart version
2. Mirror new image versions to ACR
3. Push new chart to ACR
4. Update `helmrelease.yaml` version
5. Commit and push to Git (Flux auto-deploys)

```bash
# Example update process
helm repo update wiz-sec
helm pull wiz-sec/wiz-kubernetes-integration --version 0.2.143

# Run mirror script with updated versions
./mirror-images-to-acr.sh

# Push new chart
helm push wiz-kubernetes-integration-0.2.143.tgz oci://your-acr-name.azurecr.io/helm

# Update helmrelease.yaml
sed -i 's/version: 0.2.142/version: 0.2.143/' helmrelease.yaml

# Commit and push
git add helmrelease.yaml
git commit -m "Update Wiz to v0.2.143"
git push
```

## Security Best Practices

1. **Use Managed Identity** (AKS): Attach ACR to AKS cluster instead of using secrets
2. **Rotate credentials**: Regularly rotate ACR and Wiz API credentials
3. **Restrict ACR access**: Use Azure RBAC to limit who can push images
4. **Enable vulnerability scanning**: Use Azure Defender for container registries
5. **Use separate ACR repos**: Consider using different repos for dev/staging/prod

## Key Differences: ACR vs Public Registry

| Aspect | Public Registry | ACR Deployment |
|--------|----------------|----------------|
| **Helm Chart Source** | https://charts.wiz.io | oci://your-acr.azurecr.io/helm |
| **Image Source** | wiziopublic.azurecr.io, wizio.azurecr.io | your-acr.azurecr.io/wiz |
| **Authentication** | Only for wiz-sensor | For all components |
| **Air-gap Support** | No | Yes |
| **Version Control** | Wiz controls | You control |
| **Network Requirements** | Internet access to Wiz registries | Internal ACR access only |

## References

- [Wiz Kubernetes Integration Documentation](https://docs.wiz.io/)
- [Azure Container Registry Documentation](https://docs.microsoft.com/en-us/azure/container-registry/)
- [Flux CD Documentation](https://fluxcd.io/docs/)
- [Helm OCI Support](https://helm.sh/docs/topics/registries/)

## Support

For issues related to:
- **Wiz platform**: Contact Wiz support at support@wiz.io
- **Azure/ACR**: Contact Azure support
- **This deployment**: Check [wiz-chart-latest documentation](../README.md)
