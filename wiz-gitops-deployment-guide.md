# Wiz Security Integration - GitOps Deployment Guide for AKS

## Overview
This guide provides instructions for deploying Wiz security integration to AKS using GitOps with Flux CD.

## Prerequisites
- AKS cluster with Flux extension installed
- `wiz` namespace already created in the cluster
- ACR pull secret already configured in the cluster
- Wiz API token secret (`wiz-api-token`) created in the `wiz` namespace
- Git repository to store GitOps manifests

## Directory Structure

```
.
├── wiz-helm-chart-extracted/          # Extracted Helm chart for reference
│   ├── wiz-kubernetes-integration-0.2.137.tgz
│   └── wiz-kubernetes-integration/    # Unpacked chart structure
│
└── wiz-gitops-manifests/              # GitOps manifests for Flux
    ├── kustomization.yaml
    ├── wiz-helmrepo.yaml
    └── wiz-helmrelease.yaml
```

## ACR Pull Secrets Configuration

The Wiz Helm chart requires container image pull secrets. Based on chart analysis, `imagePullSecrets` are used in:

- **Global level**: `global.imagePullSecrets` - applies to all components
- **Component level**: Individual components (wiz-kubernetes-connector, wiz-admission-controller, wiz-sensor, wiz-broker)

The GitOps manifests configure `global.imagePullSecrets` which will be inherited by all components.

### Where ACR Pull Secrets Are Required:
1. wiz-kubernetes-connector (Jobs: create-connector, refresh-token, delete-connector)
2. wiz-admission-controller (Deployments: sensor, enforcement, audit logs, debug)
3. wiz-broker (Deployment)
4. wiz-sensor (DaemonSets: Linux and Windows)

## Configuration Files

### 1. kustomization.yaml
Located at: [wiz-gitops-manifests/kustomization.yaml](wiz-gitops-manifests/kustomization.yaml)

Defines the Flux resources to deploy.

### 2. wiz-helmrepo.yaml
Located at: [wiz-gitops-manifests/wiz-helmrepo.yaml](wiz-gitops-manifests/wiz-helmrepo.yaml)

Configures the Wiz Helm repository source.

### 3. wiz-helmrelease.yaml
Located at: [wiz-gitops-manifests/wiz-helmrelease.yaml](wiz-gitops-manifests/wiz-helmrelease.yaml)

Defines the Helm release configuration with:
- Chart version specification
- ACR pull secrets reference (update `acr-credentials` to match your secret name)
- Wiz API token secret reference
- Component enablement (connector, broker, admission controller)
- AKS-specific configuration

## Deployment Steps

### Step 1: Update Configuration

Edit [wiz-gitops-manifests/wiz-helmrelease.yaml](wiz-gitops-manifests/wiz-helmrelease.yaml) and update:

```yaml
global:
  imagePullSecrets:
    - name: acr-credentials  # Replace with your actual ACR secret name
```

### Step 2: Commit Manifests to Git Repository

```bash
# Navigate to your Git repository
cd /path/to/your/gitops-repo

# Copy the GitOps manifests
cp -r wiz-gitops-manifests/* .

# Commit and push
git add .
git commit -m "Add Wiz security integration GitOps manifests"
git push origin main
```

### Step 3: Create Flux Configuration

Use the Azure CLI to create the Flux configuration:

```bash
# Set variables
CLUSTER_NAME="your-aks-cluster-name"
RESOURCE_GROUP="your-resource-group"
GIT_REPO_URL="https://github.com/your-org/your-gitops-repo"
GIT_BRANCH="main"
GIT_PATH="./wiz-gitops-manifests"

# Create Flux configuration
az k8s-configuration flux create \
  --name wiz-integration \
  --cluster-name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --cluster-type managedClusters \
  --scope namespace \
  --namespace wiz \
  --url $GIT_REPO_URL \
  --branch $GIT_BRANCH \
  --kustomization name=wiz-integration path=$GIT_PATH prune=true
```

### Step 4: Verify Deployment

Monitor the Flux deployment:

```bash
# Check Flux configuration status
az k8s-configuration flux show \
  --name wiz-integration \
  --cluster-name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --cluster-type managedClusters

# Check HelmRepository status
kubectl get helmrepositories -n wiz

# Check HelmRelease status
kubectl get helmreleases -n wiz

# Check Wiz pods
kubectl get pods -n wiz

# Check HelmRelease details
kubectl describe helmrelease wiz-integration -n wiz
```

## Troubleshooting

### Image Pull Errors
If you encounter image pull errors:

1. Verify ACR secret exists:
   ```bash
   kubectl get secret acr-credentials -n wiz
   ```

2. Verify the secret name matches in [wiz-helmrelease.yaml](wiz-gitops-manifests/wiz-helmrelease.yaml:27)

3. Check if the secret has the correct format:
   ```bash
   kubectl get secret acr-credentials -n wiz -o yaml
   ```

### HelmRelease Failed
Check HelmRelease events:
```bash
kubectl describe helmrelease wiz-integration -n wiz
```

Check Helm controller logs:
```bash
kubectl logs -n flux-system deployment/helm-controller -f
```

### Wiz API Token Issues
Verify the secret exists and has correct keys:
```bash
kubectl get secret wiz-api-token -n wiz -o yaml
# Should contain: clientId and clientToken
```

## Chart Package (.tgz)

The Helm chart package is available at:
- [wiz-helm-chart-extracted/wiz-kubernetes-integration-0.2.137.tgz](wiz-helm-chart-extracted/wiz-kubernetes-integration-0.2.137.tgz)

This can be uploaded to an OCI registry or HTTP server if you prefer to use a private chart repository instead of the public Wiz repository.

## Updating the Deployment

To update the configuration:

1. Modify [wiz-helmrelease.yaml](wiz-gitops-manifests/wiz-helmrelease.yaml)
2. Commit and push changes
3. Flux will automatically reconcile within 10 minutes (or use `flux reconcile` to force)

```bash
# Force reconciliation
kubectl annotate helmrelease wiz-integration -n wiz \
  reconcile.fluxcd.io/requestedAt="$(date +%s)"
```

## Additional Notes

- The chart version in [wiz-helmrelease.yaml](wiz-gitops-manifests/wiz-helmrelease.yaml:15) is set to `0.2.137`. Update to match your requirements or use `">= 0.0.0"` for the latest version.
- The namespace is assumed to already exist. `createNamespace: false` is set in the HelmRelease.
- All Wiz components are configured according to your original [values.yaml](values.yaml).
- The `global.imagePullSecrets` configuration ensures all components can pull images from your ACR.
