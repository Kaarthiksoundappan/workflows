# Flux GitOps Deployment Repository

This repository contains Kubernetes manifests managed by Flux for GitOps-based deployments.

## Repository Structure

```
flux-deployments/
├── clusters/              # Cluster-specific configurations
│   ├── dev/              # Development cluster
│   ├── staging/          # Staging cluster
│   └── production/       # Production cluster
├── infrastructure/       # Infrastructure components
│   ├── base/            # Base infrastructure manifests
│   └── overlays/        # Environment-specific overlays
│       ├── dev/
│       ├── staging/
│       └── production/
├── apps/                # Application deployments
│   ├── base/           # Base application manifests
│   └── overlays/       # Environment-specific overlays
│       ├── dev/
│       ├── staging/
│       └── production/
└── flux-system/        # Flux configuration files
```

## How to Use This Repository

### 1. Bootstrap Flux on AKS Cluster

```bash
# Install Flux extension on AKS
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
    prune=true \
    retry_interval=1m \
  --kustomization name=apps \
    path=./flux-deployments/apps/overlays/dev \
    depends_on=infrastructure \
    prune=true \
    retry_interval=1m
```

### 2. Add New Applications

1. Create manifests in `apps/base/`
2. Create environment-specific overlays in `apps/overlays/<env>/`
3. Update kustomization.yaml to include new app
4. Commit and push to Git
5. Flux will automatically deploy

### 3. Monitor Deployments

```bash
# Check Flux configurations
kubectl get kustomizations -n flux-system

# Check GitRepository source
kubectl get gitrepositories -n flux-system

# View Flux logs
kubectl logs -n flux-system deploy/kustomize-controller -f
```

## Deployment Workflow

1. **Developer** commits changes to Git
2. **Flux Source Controller** detects changes
3. **Flux Kustomize Controller** applies changes
4. **Kubernetes** reconciles cluster state
5. **Notifications** sent on success/failure

## Best Practices

- ✅ Never commit secrets in plain text
- ✅ Use Kustomize overlays for environment differences
- ✅ Enable pruning to clean up deleted resources
- ✅ Set up notifications for deployment status
- ✅ Use health checks for critical applications
- ✅ Tag images with specific versions (avoid :latest)

## Environment Promotion

To promote from dev → staging → production:

1. Test in dev environment
2. Merge dev branch to staging branch (or update overlays)
3. Verify staging deployment
4. Merge to production branch
5. Monitor production deployment

## Troubleshooting

### Flux not syncing
```bash
# Force reconciliation
flux reconcile source git flux-system
flux reconcile kustomization apps
```

### Check errors
```bash
kubectl describe kustomization <name> -n flux-system
kubectl logs -n flux-system deploy/source-controller
```

## Resources

- [Flux Documentation](https://fluxcd.io/docs/)
- [AKS GitOps Guide](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/conceptual-gitops-flux2)
- [Kustomize Documentation](https://kustomize.io/)
