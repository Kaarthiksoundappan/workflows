# Deploying Wiz Sensor Using GitOps with Kustomize and Flux

## Overview

This guide shows you how to deploy Wiz sensor to multiple AKS clusters using **GitOps methodology** with **Flux** and **Kustomize**. This approach stores all configuration in Git, providing version control, change tracking, and easy multi-cluster management.

## What is GitOps?

**GitOps** = Using Git as the single source of truth for your infrastructure and applications.

### Traditional Deployment vs GitOps

**Traditional (CLI commands)**:
```
You → Run kubectl/helm command → Kubernetes Cluster
```
- Configuration lives in scripts or your head
- No version control
- Hard to track who changed what
- Difficult to replicate

**GitOps (Recommended)**:
```
You → Commit to Git → Flux watches Git → Flux applies to Kubernetes
```
- Configuration in Git (version controlled)
- Full audit trail
- Easy rollback (git revert)
- Declarative and automated

## What is Kustomize?

**Kustomize** lets you customize Kubernetes configurations without duplicating files.

### The Problem It Solves

You have 10 AKS clusters (dev, staging, production, etc.). Each needs slightly different configurations:
- Production: 5 replicas, 2GB memory
- Staging: 2 replicas, 1GB memory
- Development: 1 replica, 512MB memory

**Without Kustomize**: Copy-paste the same YAML 10 times, change a few values (lots of duplication!)

**With Kustomize**:
- One base configuration (shared settings)
- Small overlay files per environment (only the differences)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Git Repository                          │
│  ┌────────────────────────────────────────────────────┐    │
│  │  helmrepository.yaml  (Where charts come from)     │    │
│  │  release.yaml         (What to deploy)            │    │
│  │  kustomization.yaml   (How to customize)          │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    Flux watches Git
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              Multiple AKS Clusters                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  Cluster 1   │  │  Cluster 2   │  │  Cluster 3   │     │
│  │              │  │              │  │              │     │
│  │ [Wiz Sensor] │  │ [Wiz Sensor] │  │ [Wiz Sensor] │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Azure CLI installed
- Multiple AKS clusters created
- Git repository (GitHub, GitLab, Azure DevOps, etc.)
- Wiz sensor Helm chart in Azure Container Registry
- Wiz client token

## Step 1: Create Git Repository Structure

### Option A: Simple Structure (All Clusters Use Same Config)

```
wiz-gitops-repo/
├── README.md
└── wiz-sensor/
    ├── helmrepository.yaml
    ├── release.yaml
    └── kustomization.yaml
```

### Option B: Multi-Environment Structure (Recommended)

```
wiz-gitops-repo/
├── README.md
├── base/
│   └── wiz-sensor/
│       ├── helmrepository.yaml
│       ├── release.yaml
│       └── kustomization.yaml
│
└── clusters/
    ├── production/
    │   └── wiz-sensor/
    │       ├── kustomization.yaml
    │       └── patches.yaml
    │
    ├── staging/
    │   └── wiz-sensor/
    │       ├── kustomization.yaml
    │       └── patches.yaml
    │
    └── development/
        └── wiz-sensor/
            ├── kustomization.yaml
            └── patches.yaml
```

Let's implement **Option B** as it's more scalable.

## Step 2: Create Base Configuration Files

### Create Directory Structure

```bash
# Create the directory structure
mkdir -p wiz-gitops-repo/base/wiz-sensor
mkdir -p wiz-gitops-repo/clusters/production/wiz-sensor
mkdir -p wiz-gitops-repo/clusters/staging/wiz-sensor
mkdir -p wiz-gitops-repo/clusters/development/wiz-sensor

cd wiz-gitops-repo
```

### File 1: `base/wiz-sensor/helmrepository.yaml`

This defines **where** to get the Wiz sensor Helm chart.

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: wiz-acr
  namespace: wiz-system
spec:
  interval: 5m0s
  type: oci
  url: oci://azcontainerregistry.azurecr.io/helm
  # If ACR requires authentication, add:
  # secretRef:
  #   name: acr-credentials
```

**Explanation**:
- `interval: 5m0s` - Check for new chart versions every 5 minutes
- `type: oci` - Azure Container Registry uses OCI format
- `url` - Your ACR Helm repository URL

### File 2: `base/wiz-sensor/release.yaml`

This defines **what** to deploy and the base configuration.

```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: wizsensor
  namespace: wiz-system
spec:
  interval: 10m0s
  timeout: 5m0s

  chart:
    spec:
      chart: wizsensor
      version: "1.0.0"  # Specify your chart version
      sourceRef:
        kind: HelmRepository
        name: wiz-acr
        namespace: wiz-system
      interval: 5m0s

  # Create namespace if it doesn't exist
  install:
    createNamespace: true
    remediation:
      retries: 3

  # Retry upgrades if they fail
  upgrade:
    remediation:
      retries: 3
      remediateLastFailure: true

  # Base Helm values (shared across all environments)
  values:
    # Image configuration
    image:
      pullPolicy: IfNotPresent

    # Resource limits (can be overridden per environment)
    resources:
      limits:
        memory: 512Mi
        cpu: 500m
      requests:
        memory: 256Mi
        cpu: 250m

    # Wiz sensor configuration
    wiz:
      # This will be substituted from environment variables or secrets
      clientToken: ${WIZ_CLIENT_TOKEN}

    # DaemonSet configuration (runs on every node)
    # Most Wiz sensors use DaemonSet
    updateStrategy:
      type: RollingUpdate
      rollingUpdate:
        maxUnavailable: 1
```

**Explanation**:
- `interval: 10m0s` - Check for drift every 10 minutes
- `install.createNamespace: true` - Auto-create `wiz-system` namespace
- `remediation.retries: 3` - Retry 3 times if deployment fails
- `${WIZ_CLIENT_TOKEN}` - Variable substitution (explained later)

### File 3: `base/wiz-sensor/kustomization.yaml`

This tells Kustomize which files to include.

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: wiz-system

resources:
  - helmrepository.yaml
  - release.yaml

# Add common labels to all resources
commonLabels:
  app: wizsensor
  managed-by: flux

# Add common annotations
commonAnnotations:
  documentation: "https://docs.wiz.io/wiz-docs/docs/wiz-sensor"
```

**Explanation**:
- `namespace: wiz-system` - All resources go to this namespace
- `resources` - List of YAML files to include
- `commonLabels` - Added to all resources for easy filtering

## Step 3: Create Environment-Specific Overlays

Now create customizations for each environment.

### Production Configuration

**File: `clusters/production/wiz-sensor/kustomization.yaml`**

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: wiz-system

# Use base configuration
resources:
  - ../../../base/wiz-sensor

# Add production-specific labels
labels:
  - pairs:
      environment: production
      tier: critical

# Patches for production (higher resources)
patches:
  - patch: |-
      apiVersion: helm.toolkit.fluxcd.io/v2beta1
      kind: HelmRelease
      metadata:
        name: wizsensor
        namespace: wiz-system
      spec:
        values:
          resources:
            limits:
              memory: 1Gi
              cpu: 1000m
            requests:
              memory: 512Mi
              cpu: 500m

          # Production-specific settings
          nodeSelector:
            environment: production

          tolerations:
            - key: "critical"
              operator: "Equal"
              value: "true"
              effect: "NoSchedule"

# Variable substitution for production
postBuild:
  substitute:
    WIZ_CLIENT_TOKEN: "prod-wiz-token-here"
  substituteFrom:
    - kind: Secret
      name: wiz-credentials
      optional: true
```

**Explanation**:
- `resources: ../../../base/wiz-sensor` - Inherit base configuration
- `patches` - Override specific values for production
- Higher memory/CPU limits for production workloads
- `postBuild.substitute` - Replace `${WIZ_CLIENT_TOKEN}` with actual token

### Staging Configuration

**File: `clusters/staging/wiz-sensor/kustomization.yaml`**

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: wiz-system

resources:
  - ../../../base/wiz-sensor

labels:
  - pairs:
      environment: staging
      tier: non-critical

# Staging uses moderate resources
patches:
  - patch: |-
      apiVersion: helm.toolkit.fluxcd.io/v2beta1
      kind: HelmRelease
      metadata:
        name: wizsensor
        namespace: wiz-system
      spec:
        values:
          resources:
            limits:
              memory: 512Mi
              cpu: 500m
            requests:
              memory: 256Mi
              cpu: 250m

          nodeSelector:
            environment: staging

postBuild:
  substitute:
    WIZ_CLIENT_TOKEN: "staging-wiz-token-here"
```

### Development Configuration

**File: `clusters/development/wiz-sensor/kustomization.yaml`**

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: wiz-system

resources:
  - ../../../base/wiz-sensor

labels:
  - pairs:
      environment: development
      tier: non-critical

# Development uses minimal resources
patches:
  - patch: |-
      apiVersion: helm.toolkit.fluxcd.io/v2beta1
      kind: HelmRelease
      metadata:
        name: wizsensor
        namespace: wiz-system
      spec:
        values:
          resources:
            limits:
              memory: 256Mi
              cpu: 250m
            requests:
              memory: 128Mi
              cpu: 100m

postBuild:
  substitute:
    WIZ_CLIENT_TOKEN: "dev-wiz-token-here"
```

## Step 4: Commit to Git Repository

```bash
# Initialize git repository (if not already)
cd wiz-gitops-repo
git init

# Add all files
git add .

# Commit
git commit -m "Add Wiz sensor GitOps configuration with Kustomize"

# Add remote (replace with your repository URL)
git remote add origin https://github.com/yourusername/wiz-gitops-repo.git

# Push to GitHub
git branch -M main
git push -u origin main
```

## Step 5: Deploy to AKS Clusters Using Flux

Now configure each AKS cluster to watch the Git repository.

### Install Flux and Configure GitOps

**For Production Cluster:**

```bash
az k8s-configuration flux create \
  --cluster-name aks-production \
  --resource-group rg-production \
  --cluster-type managedClusters \
  --name wiz-sensor-gitops \
  --namespace flux-system \
  --scope cluster \
  --url https://github.com/yourusername/wiz-gitops-repo \
  --branch main \
  --kustomization name=wiz-sensor path=./clusters/production/wiz-sensor prune=true interval=5m
```

**For Staging Cluster:**

```bash
az k8s-configuration flux create \
  --cluster-name aks-staging \
  --resource-group rg-staging \
  --cluster-type managedClusters \
  --name wiz-sensor-gitops \
  --namespace flux-system \
  --scope cluster \
  --url https://github.com/yourusername/wiz-gitops-repo \
  --branch main \
  --kustomization name=wiz-sensor path=./clusters/staging/wiz-sensor prune=true interval=5m
```

**For Development Cluster:**

```bash
az k8s-configuration flux create \
  --cluster-name aks-development \
  --resource-group rg-development \
  --cluster-type managedClusters \
  --name wiz-sensor-gitops \
  --namespace flux-system \
  --scope cluster \
  --url https://github.com/yourusername/wiz-gitops-repo \
  --branch main \
  --kustomization name=wiz-sensor path=./clusters/development/wiz-sensor prune=true interval=5m
```

**What This Does**:
1. Installs Flux on each cluster
2. Configures Flux to watch your Git repository
3. Points each cluster to its specific environment path
4. Checks for changes every 5 minutes
5. Automatically applies any changes from Git

### Alternative: Using Flux CLI Directly

If you prefer using Flux CLI instead of Azure CLI:

```bash
# Get AKS credentials
az aks get-credentials --resource-group rg-production --name aks-production

# Install Flux
flux install --namespace flux-system

# Create Git source
flux create source git wiz-sensor \
  --url=https://github.com/yourusername/wiz-gitops-repo \
  --branch=main \
  --interval=1m \
  --namespace=flux-system

# Create Kustomization
flux create kustomization wiz-sensor \
  --source=GitRepository/wiz-sensor \
  --path="./clusters/production/wiz-sensor" \
  --prune=true \
  --interval=5m \
  --namespace=flux-system
```

## Step 6: Create Wiz Credentials Secret

For security, don't hardcode tokens in Git. Use Kubernetes secrets:

```bash
# For each cluster, create the secret
az aks get-credentials --resource-group rg-production --name aks-production

kubectl create namespace wiz-system

kubectl create secret generic wiz-credentials \
  --from-literal=clientToken='your-production-wiz-token' \
  --namespace wiz-system
```

Update your kustomization to use the secret:

```yaml
postBuild:
  substituteFrom:
    - kind: Secret
      name: wiz-credentials
```

## Step 7: Verify Deployment

### Check Flux Status

```bash
# Check if Flux is running
kubectl get pods -n flux-system

# Check GitRepository source
flux get sources git

# Check Kustomization status
flux get kustomizations

# Check HelmRelease status
flux get helmreleases -n wiz-system
```

### Check Wiz Sensor Pods

```bash
# Check if pods are running
kubectl get pods -n wiz-system

# Check DaemonSet (if Wiz uses DaemonSet)
kubectl get daemonset -n wiz-system

# View logs
kubectl logs -n wiz-system -l app=wizsensor
```

### View Applied Configuration

```bash
# See what Flux applied
kubectl get helmrelease -n wiz-system wizsensor -o yaml

# See the actual Kubernetes resources created
kubectl get all -n wiz-system
```

## Step 8: Making Changes (The GitOps Way)

### Scenario: Update Wiz Sensor Version

**Old Way (CLI)**:
```bash
helm upgrade wizsensor --set image.tag=2.0.0
# Do this 10 times for 10 clusters
```

**GitOps Way**:

1. **Edit the file in Git**:
   ```yaml
   # Edit: base/wiz-sensor/release.yaml
   spec:
     chart:
       spec:
         version: "2.0.0"  # Changed from 1.0.0
   ```

2. **Commit and push**:
   ```bash
   git add base/wiz-sensor/release.yaml
   git commit -m "Update Wiz sensor to version 2.0.0"
   git push
   ```

3. **Wait for Flux** (or trigger manually):
   ```bash
   # Flux auto-detects in ~1 minute
   # Or force immediate reconciliation:
   flux reconcile kustomization wiz-sensor --with-source
   ```

4. **All clusters update automatically** ✅

### Scenario: Increase Memory in Production Only

1. **Edit production overlay**:
   ```yaml
   # Edit: clusters/production/wiz-sensor/kustomization.yaml
   patches:
     - patch: |-
         spec:
           values:
             resources:
               limits:
                 memory: 2Gi  # Changed from 1Gi
   ```

2. **Commit and push**:
   ```bash
   git add clusters/production/wiz-sensor/kustomization.yaml
   git commit -m "Increase Wiz sensor memory in production to 2Gi"
   git push
   ```

3. **Only production cluster updates** ✅

## Step 9: Advanced Scenarios

### Scenario A: Deploy to New Cluster

1. **Create new overlay**:
   ```bash
   mkdir -p clusters/cluster-new/wiz-sensor
   ```

2. **Copy existing kustomization**:
   ```bash
   cp clusters/production/wiz-sensor/kustomization.yaml \
      clusters/cluster-new/wiz-sensor/
   ```

3. **Adjust as needed** (change labels, resources, etc.)

4. **Commit and push**:
   ```bash
   git add clusters/cluster-new
   git commit -m "Add Wiz sensor config for new cluster"
   git push
   ```

5. **Point new cluster to Git**:
   ```bash
   az k8s-configuration flux create \
     --cluster-name aks-new-cluster \
     --resource-group rg-new \
     --cluster-type managedClusters \
     --name wiz-sensor-gitops \
     --namespace flux-system \
     --scope cluster \
     --url https://github.com/yourusername/wiz-gitops-repo \
     --branch main \
     --kustomization name=wiz-sensor path=./clusters/cluster-new/wiz-sensor prune=true
   ```

Done! New cluster is now managed via GitOps.

### Scenario B: Rollback to Previous Version

```bash
# View git history
git log --oneline

# Rollback to previous commit
git revert HEAD

# Or rollback to specific commit
git revert abc123

# Push
git push

# Flux automatically applies the rollback
```

### Scenario C: Test Changes in Staging First

```bash
# Create a new branch
git checkout -b test-new-version

# Make changes in staging overlay
# Edit: clusters/staging/wiz-sensor/kustomization.yaml

# Commit
git commit -am "Test Wiz sensor 2.0 in staging"
git push origin test-new-version

# Update staging cluster to watch the test branch
az k8s-configuration flux update \
  --cluster-name aks-staging \
  --resource-group rg-staging \
  --cluster-type managedClusters \
  --name wiz-sensor-gitops \
  --branch test-new-version

# Test in staging
# If successful, merge to main
git checkout main
git merge test-new-version
git push

# Staging and all other clusters now get the update
```

## Automation Script for Multiple Clusters

**PowerShell Script: `deploy-all-clusters.ps1`**

```powershell
# Configuration
$gitRepo = "https://github.com/yourusername/wiz-gitops-repo"
$branch = "main"

$clusters = @(
    @{ Name = "aks-prod-1"; ResourceGroup = "rg-prod"; Environment = "production" },
    @{ Name = "aks-prod-2"; ResourceGroup = "rg-prod"; Environment = "production" },
    @{ Name = "aks-staging"; ResourceGroup = "rg-staging"; Environment = "staging" },
    @{ Name = "aks-dev"; ResourceGroup = "rg-dev"; Environment = "development" }
)

foreach ($cluster in $clusters) {
    Write-Host "Configuring cluster: $($cluster.Name)"

    az k8s-configuration flux create `
      --cluster-name $cluster.Name `
      --resource-group $cluster.ResourceGroup `
      --cluster-type managedClusters `
      --name wiz-sensor-gitops `
      --namespace flux-system `
      --scope cluster `
      --url $gitRepo `
      --branch $branch `
      --kustomization name=wiz-sensor path=./clusters/$($cluster.Environment)/wiz-sensor prune=true interval=5m

    Write-Host "Configured $($cluster.Name) successfully!"
    Write-Host "-----------------------------------"
}

Write-Host "All clusters configured with GitOps!"
```

**Bash Script: `deploy-all-clusters.sh`**

```bash
#!/bin/bash

GIT_REPO="https://github.com/yourusername/wiz-gitops-repo"
BRANCH="main"

declare -A CLUSTERS=(
    ["aks-prod-1"]="rg-prod:production"
    ["aks-prod-2"]="rg-prod:production"
    ["aks-staging"]="rg-staging:staging"
    ["aks-dev"]="rg-dev:development"
)

for CLUSTER_NAME in "${!CLUSTERS[@]}"; do
    IFS=':' read -r RG ENV <<< "${CLUSTERS[$CLUSTER_NAME]}"

    echo "Configuring cluster: $CLUSTER_NAME"

    az k8s-configuration flux create \
      --cluster-name "$CLUSTER_NAME" \
      --resource-group "$RG" \
      --cluster-type managedClusters \
      --name wiz-sensor-gitops \
      --namespace flux-system \
      --scope cluster \
      --url "$GIT_REPO" \
      --branch "$BRANCH" \
      --kustomization name=wiz-sensor path=./clusters/$ENV/wiz-sensor prune=true interval=5m

    echo "Configured $CLUSTER_NAME successfully!"
    echo "-----------------------------------"
done

echo "All clusters configured with GitOps!"
```

## Troubleshooting

### Issue 1: Flux Not Syncing

```bash
# Check Flux logs
kubectl logs -n flux-system -l app=source-controller
kubectl logs -n flux-system -l app=kustomize-controller
kubectl logs -n flux-system -l app=helm-controller

# Force reconciliation
flux reconcile source git wiz-sensor
flux reconcile kustomization wiz-sensor
```

### Issue 2: HelmRelease Stuck

```bash
# Check HelmRelease status
kubectl describe helmrelease -n wiz-system wizsensor

# Check Helm release
kubectl get helmrelease -n wiz-system

# Force reconciliation
flux reconcile helmrelease -n wiz-system wizsensor
```

### Issue 3: Authentication to ACR Fails

Create a secret with ACR credentials:

```bash
kubectl create secret docker-registry acr-credentials \
  --docker-server=azcontainerregistry.azurecr.io \
  --docker-username=<ACR_USERNAME> \
  --docker-password=<ACR_PASSWORD> \
  --namespace=wiz-system

# Reference in helmrepository.yaml
spec:
  secretRef:
    name: acr-credentials
```

### Issue 4: Kustomize Build Fails

Test locally before committing:

```bash
# Install kustomize CLI
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash

# Test build
kustomize build clusters/production/wiz-sensor

# Should output valid Kubernetes YAML
```

## Monitoring and Observability

### View All Flux Resources

```bash
# Get all Flux sources
flux get sources all

# Get all Kustomizations
flux get kustomizations --all-namespaces

# Get all HelmReleases
flux get helmreleases --all-namespaces

# Get detailed status
flux get all
```

### Set Up Notifications

Get notified when deployments succeed or fail:

```yaml
# Add to your Git repo: notifications/slack.yaml
---
apiVersion: notification.toolkit.fluxcd.io/v1beta1
kind: Provider
metadata:
  name: slack
  namespace: flux-system
spec:
  type: slack
  channel: wiz-deployments
  address: https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK

---
apiVersion: notification.toolkit.fluxcd.io/v1beta1
kind: Alert
metadata:
  name: wiz-sensor-alert
  namespace: flux-system
spec:
  providerRef:
    name: slack
  eventSeverity: info
  eventSources:
    - kind: HelmRelease
      name: wizsensor
      namespace: wiz-system
```

## Comparison: Direct CLI vs GitOps with Kustomize

| Feature | Direct CLI | GitOps with Kustomize |
|---------|-----------|----------------------|
| **Configuration Storage** | Azure or local scripts | Git repository |
| **Version Control** | ❌ No | ✅ Full history |
| **Multi-Cluster Management** | Repeat commands | Single commit |
| **Environment Differences** | Separate scripts | Kustomize overlays |
| **Rollback** | Manual | `git revert` |
| **Audit Trail** | Limited | Complete Git log |
| **Change Review** | None | Pull requests |
| **Automation** | Manual scripts | Automatic sync |
| **Disaster Recovery** | Re-run scripts | Re-apply from Git |
| **Team Collaboration** | Share scripts | Git workflow |
| **Drift Detection** | None | Automatic correction |
| **Learning Curve** | Easy | Moderate |

## Best Practices

### 1. Repository Organization
✅ Separate base configurations from environment overlays
✅ Use meaningful directory names
✅ Keep environment-specific values in overlays
✅ Document your structure in README

### 2. Security
✅ Never commit secrets to Git
✅ Use Kubernetes secrets or Azure Key Vault
✅ Use RBAC to control who can modify production
✅ Require pull request reviews for production changes

### 3. Change Management
✅ Always test in staging/dev first
✅ Use pull requests for all changes
✅ Write descriptive commit messages
✅ Tag releases for important milestones

### 4. Monitoring
✅ Set up Flux notifications (Slack, email)
✅ Monitor HelmRelease status
✅ Check Flux logs regularly
✅ Use metrics and dashboards

### 5. Git Workflow
✅ Main branch = production
✅ Feature branches for testing
✅ Merge after successful testing
✅ Use semantic versioning for tags

## Summary

### What You Learned

1. **GitOps** = Git as single source of truth
2. **Kustomize** = Customize configs without duplication
3. **Flux** = Automatically syncs Git to Kubernetes
4. **HelmRepository** = Defines where charts come from
5. **HelmRelease** = Defines what to deploy
6. **Kustomization** = Defines how to customize

### The Power of This Approach

- ✅ Change one file → All clusters update
- ✅ Git history = Audit trail
- ✅ `git revert` = Instant rollback
- ✅ Pull requests = Change reviews
- ✅ Automatic drift correction
- ✅ Scalable to 100+ clusters

### When to Use GitOps

- ✅ Multiple clusters
- ✅ Production environments
- ✅ Team collaboration
- ✅ Compliance requirements
- ✅ Change tracking needed

### When Direct CLI is OK

- Single cluster
- Quick testing
- Personal development
- Learning Kubernetes

## Additional Resources

- [Flux Documentation](https://fluxcd.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [GitOps Principles](https://opengitops.dev/)
- [Azure Flux Extension](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2)
- [Helm Documentation](https://helm.sh/docs/)

---

**Remember**: GitOps is not just a tool, it's a methodology. Git becomes your control plane for Kubernetes!
