# Flux CLI Commands Cheat Sheet

## Installation & Setup

### Install Flux CLI
```bash
# macOS/Linux
curl -s https://fluxcd.io/install.sh | sudo bash

# Windows (using Chocolatey)
choco install flux

# Verify installation
flux --version
```

### Bootstrap Flux on AKS

```bash
# Using Azure CLI
az k8s-configuration flux create \
  --resource-group <resource-group> \
  --cluster-name <cluster-name> \
  --cluster-type managedClusters \
  --name flux-config \
  --namespace flux-system \
  --scope cluster \
  --url https://github.com/<your-org>/<your-repo> \
  --branch main \
  --kustomization name=infrastructure \
    path=./flux-deployments/infrastructure/overlays/dev \
    prune=true

# Using Flux CLI (bootstraps Flux to cluster and Git)
flux bootstrap github \
  --owner=<github-username> \
  --repository=<repo-name> \
  --branch=main \
  --path=flux-deployments/clusters/dev \
  --personal
```

## Source Management

### Git Repository

```bash
# Create Git source
flux create source git <name> \
  --url=https://github.com/<org>/<repo> \
  --branch=main \
  --interval=1m

# List Git sources
flux get sources git

# Reconcile (force sync) Git source
flux reconcile source git flux-system

# Delete Git source
flux delete source git <name>
```

### Helm Repository

```bash
# Create Helm repository source
flux create source helm <name> \
  --url=https://charts.example.com \
  --interval=10m

# List Helm sources
flux get sources helm

# Reconcile Helm source
flux reconcile source helm <name>
```

## Kustomization Management

```bash
# Create Kustomization
flux create kustomization <name> \
  --source=GitRepository/flux-system \
  --path="./apps/dev" \
  --prune=true \
  --interval=5m

# List Kustomizations
flux get kustomizations

# Get Kustomization details
flux get kustomization <name>

# Reconcile Kustomization (force sync)
flux reconcile kustomization <name>

# Suspend Kustomization
flux suspend kustomization <name>

# Resume Kustomization
flux resume kustomization <name>

# Delete Kustomization
flux delete kustomization <name>
```

## Helm Release Management

```bash
# Create Helm release
flux create helmrelease <name> \
  --source=HelmRepository/<repo-name> \
  --chart=<chart-name> \
  --target-namespace=<namespace> \
  --interval=5m

# List Helm releases
flux get helmreleases

# Get Helm release details
flux get helmrelease <name> -n <namespace>

# Reconcile Helm release
flux reconcile helmrelease <name> -n <namespace>

# Suspend Helm release
flux suspend helmrelease <name> -n <namespace>

# Resume Helm release
flux resume helmrelease <name> -n <namespace>
```

## Monitoring & Troubleshooting

### Check Flux Status

```bash
# Check Flux components
flux check

# Get all Flux resources
flux get all

# Get events
flux events

# Check logs
flux logs --all-namespaces
flux logs --kind=Kustomization --name=apps
flux logs --kind=HelmRelease --name=nginx
```

### Debugging

```bash
# Describe Kustomization
kubectl describe kustomization <name> -n flux-system

# Describe HelmRelease
kubectl describe helmrelease <name> -n <namespace>

# Check Flux controller logs
kubectl logs -n flux-system deploy/source-controller -f
kubectl logs -n flux-system deploy/kustomize-controller -f
kubectl logs -n flux-system deploy/helm-controller -f
kubectl logs -n flux-system deploy/notification-controller -f

# Check GitRepository status
kubectl get gitrepositories -n flux-system
kubectl describe gitrepository flux-system -n flux-system
```

## Reconciliation (Force Sync)

```bash
# Reconcile everything
flux reconcile source git flux-system
flux reconcile kustomization flux-system

# Reconcile specific resources
flux reconcile kustomization infrastructure
flux reconcile kustomization apps
flux reconcile helmrelease nginx -n ingress-nginx

# Watch reconciliation
watch flux get kustomizations
```

## Image Automation

```bash
# Create image repository
flux create image repository <name> \
  --image=<registry>/<image> \
  --interval=1m

# Create image policy
flux create image policy <name> \
  --image-ref=<name> \
  --select-semver=">=1.0.0"

# Create image update automation
flux create image update <name> \
  --git-repo-ref=flux-system \
  --checkout-branch=main \
  --push-branch=main \
  --author-name=fluxbot \
  --author-email=fluxbot@example.com \
  --commit-template="{{range .Updated.Images}}{{println .}}{{end}}"

# List image resources
flux get images all
```

## Notifications

```bash
# Create alert provider (Slack)
flux create alert-provider slack \
  --type=slack \
  --channel=<channel-name> \
  --address=<webhook-url>

# Create alert
flux create alert <name> \
  --provider-ref=slack \
  --event-source=Kustomization/* \
  --event-severity=info

# List alerts
flux get alerts
```

## Export & Backup

```bash
# Export Flux configuration
flux export source git flux-system > flux-system.yaml
flux export kustomization apps > apps-ks.yaml
flux export helmrelease nginx > nginx-hr.yaml

# Export all Flux resources
flux export source git --all > all-sources.yaml
flux export kustomization --all > all-kustomizations.yaml
```

## Azure-Specific Commands

### List Flux Configurations on AKS

```bash
# List all configurations
az k8s-configuration flux list \
  --resource-group <rg> \
  --cluster-name <cluster> \
  --cluster-type managedClusters

# Show specific configuration
az k8s-configuration flux show \
  --resource-group <rg> \
  --cluster-name <cluster> \
  --cluster-type managedClusters \
  --name <config-name>

# Delete configuration
az k8s-configuration flux delete \
  --resource-group <rg> \
  --cluster-name <cluster> \
  --cluster-type managedClusters \
  --name <config-name>
```

## Useful One-Liners

```bash
# Force reconcile all
flux reconcile source git flux-system && flux reconcile kustomization flux-system

# Watch all Flux resources
watch -n 2 'flux get all'

# Check for pending reconciliations
kubectl get kustomizations -A -o json | jq -r '.items[] | select(.status.conditions[] | select(.type=="Ready" and .status=="False")) | "\(.metadata.namespace)/\(.metadata.name): \(.status.conditions[] | select(.type=="Ready") | .message)"'

# Suspend all Kustomizations
flux get kustomizations --all-namespaces -o json | jq -r '.[] | .name' | xargs -I {} flux suspend kustomization {}

# Resume all Kustomizations
flux get kustomizations --all-namespaces -o json | jq -r '.[] | .name' | xargs -I {} flux resume kustomization {}
```

## Best Practices

1. **Always test in dev first** before promoting to production
2. **Use `--dry-run`** when available to preview changes
3. **Monitor reconciliation intervals** - shorter intervals consume more resources
4. **Set up notifications** for production environments
5. **Use semantic versioning** for image automation
6. **Enable pruning** to clean up deleted resources
7. **Set timeouts** appropriately for large deployments
8. **Use health checks** for critical applications

## Resources

- [Flux CLI Documentation](https://fluxcd.io/flux/cmd/)
- [Flux Guides](https://fluxcd.io/flux/guides/)
- [AKS GitOps Documentation](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2)
