# Wiz Security Sensor Deployment with Flux

This guide explains how to deploy the Wiz Kubernetes Connector using Flux GitOps.

## Overview

The Wiz Kubernetes Connector has been configured in this repository with:
- **Helm Repository**: `wiz-sec` pointing to `https://charts.wiz.io`
- **Multi-environment support**: Separate configurations for dev, staging, and production
- **Automated GitOps deployment**: Managed by Flux

## Repository Structure

```
flux-deployments/infrastructure/
├── base/
│   ├── wiz-helm-repository.yaml      # Wiz Helm repo configuration
│   ├── wiz-sensor-namespace.yaml     # wiz-system namespace
│   └── wiz-sensor-helmrelease.yaml   # Base HelmRelease configuration
└── overlays/
    ├── dev/
    │   └── wiz-sensor-patch.yaml     # Dev-specific configuration
    ├── staging/
    │   └── wiz-sensor-patch.yaml     # Staging-specific configuration
    └── production/
        └── wiz-sensor-patch.yaml     # Production-specific configuration
```

## Prerequisites

Before deploying, you need:

1. **Wiz Connector ID and Secret**
   - Obtain from Wiz portal: Settings → Integrations → Kubernetes
   - Create a new connector for each environment (dev, staging, production)

2. **Secret Management**
   - Secrets should NOT be committed in plain text
   - Use one of these methods:
     - Sealed Secrets
     - External Secrets Operator with Azure Key Vault
     - SOPS encryption

## Deployment Steps

### Step 1: Configure Secrets

#### Option A: Using Sealed Secrets

```bash
# Create a secret
kubectl create secret generic wiz-connector-secret \
  --namespace=wiz-system \
  --from-literal=clientId=<your-client-id> \
  --from-literal=clientToken=<your-client-token> \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > wiz-secret-sealed.yaml

# Add to Git
git add wiz-secret-sealed.yaml
git commit -m "Add Wiz connector sealed secret"
git push
```

#### Option B: Using Azure Key Vault + External Secrets Operator

```yaml
# Create SecretStore
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-keyvault
  namespace: wiz-system
spec:
  provider:
    azurekv:
      authType: ManagedIdentity
      vaultUrl: "https://<your-keyvault>.vault.azure.net"

---
# Create ExternalSecret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: wiz-connector-secret
  namespace: wiz-system
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: azure-keyvault
    kind: SecretStore
  target:
    name: wiz-connector-secret
  data:
    - secretKey: clientId
      remoteRef:
        key: wiz-client-id
    - secretKey: clientToken
      remoteRef:
        key: wiz-client-token
```

### Step 2: Update HelmRelease Values

Edit the environment-specific patch file to reference your secrets:

**For Dev** - Edit `flux-deployments/infrastructure/overlays/dev/wiz-sensor-patch.yaml`:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: wiz-sensor
  namespace: wiz-system
spec:
  values:
    # Add Wiz connector configuration
    wizConnector:
      clientId:
        valueFrom:
          secretKeyRef:
            name: wiz-connector-secret
            key: clientId
      clientToken:
        valueFrom:
          secretKeyRef:
            name: wiz-connector-secret
            key: clientToken

    # Or using values directly (if your Helm chart supports it)
    global:
      wizApiToken:
        secret: wiz-connector-secret
        clientIdKey: clientId
        clientTokenKey: clientToken
```

Repeat for staging and production with their respective connector credentials.

### Step 3: Commit and Push

```bash
# Add all changes
git add flux-deployments/infrastructure/

# Commit
git commit -m "Configure Wiz sensor deployment with Flux"

# Push to trigger Flux reconciliation
git push origin main
```

### Step 4: Verify Deployment

```bash
# Check Flux reconciliation
flux get helmreleases -n wiz-system

# Check HelmRelease status
kubectl get helmrelease wiz-sensor -n wiz-system

# Check pods
kubectl get pods -n wiz-system

# Check logs
kubectl logs -n wiz-system -l app.kubernetes.io/name=wiz-sensor

# Describe HelmRelease for troubleshooting
kubectl describe helmrelease wiz-sensor -n wiz-system
```

## Environment-Specific Configurations

### Development
- Reduced resource limits (50m CPU, 64Mi memory)
- Debug logging enabled
- Scan interval: 1 hour
- Single replica

### Staging
- Standard resource limits (100m CPU, 128Mi memory)
- Info logging
- Scan interval: 30 minutes
- Single replica

### Production
- Enhanced resource limits (200m CPU, 256Mi memory)
- Warn logging
- Scan interval: 15 minutes
- **2 replicas for high availability**
- Pod disruption budget enabled
- Pod anti-affinity rules
- Priority class: system-cluster-critical

## Flux Commands for Wiz Sensor

```bash
# Force reconciliation
flux reconcile source git flux-system
flux reconcile kustomization infrastructure

# Reconcile only Wiz HelmRelease
flux reconcile helmrelease wiz-sensor -n wiz-system

# Suspend Wiz deployment (stop reconciliation)
flux suspend helmrelease wiz-sensor -n wiz-system

# Resume Wiz deployment
flux resume helmrelease wiz-sensor -n wiz-system

# Check Helm repository status
flux get sources helm wiz-sec

# View Wiz HelmRelease
kubectl get helmrelease wiz-sensor -n wiz-system -o yaml
```

## Troubleshooting

### Issue: HelmRelease not reconciling

```bash
# Check Flux logs
kubectl logs -n flux-system deploy/helm-controller -f

# Check HelmRelease status
kubectl describe helmrelease wiz-sensor -n wiz-system

# Force reconciliation
flux reconcile helmrelease wiz-sensor -n wiz-system
```

### Issue: Chart not found

```bash
# Check Helm repository
flux get sources helm wiz-sec

# Verify repository URL
kubectl get helmrepository wiz-sec -n flux-system -o yaml

# Reconcile Helm repository
flux reconcile source helm wiz-sec
```

### Issue: Authentication failure with Wiz

```bash
# Verify secret exists
kubectl get secret wiz-connector-secret -n wiz-system

# Check secret values (base64 encoded)
kubectl get secret wiz-connector-secret -n wiz-system -o yaml

# Check pod logs for authentication errors
kubectl logs -n wiz-system -l app.kubernetes.io/name=wiz-sensor
```

### Issue: Pod not starting

```bash
# Check pod status
kubectl get pods -n wiz-system

# Describe pod
kubectl describe pod <pod-name> -n wiz-system

# Check events
kubectl get events -n wiz-system --sort-by='.lastTimestamp'
```

## Security Best Practices

1. **Never commit secrets in plain text**
   - Use Sealed Secrets, SOPS, or External Secrets Operator

2. **Use separate connectors per environment**
   - Different credentials for dev, staging, production
   - Principle of least privilege

3. **Enable RBAC**
   - Wiz sensor requires specific Kubernetes permissions
   - Review and audit the service account permissions

4. **Network policies**
   - Restrict egress traffic to Wiz API endpoints only
   - Apply network policies in production

5. **Resource limits**
   - Always set resource requests and limits
   - Monitor resource usage and adjust as needed

6. **Regular updates**
   - Keep Wiz sensor chart version updated
   - Monitor Flux for automatic updates (if configured)

## Chart Version Management

To update the Wiz sensor version:

1. **Option A: Specific version**
   ```yaml
   spec:
     chart:
       spec:
         version: '1.2.3'
   ```

2. **Option B: Version range**
   ```yaml
   spec:
     chart:
       spec:
         version: '>=1.0.0 <2.0.0'
   ```

3. **Option C: Automatic updates**
   ```yaml
   spec:
     chart:
       spec:
         version: '*'  # Not recommended for production
   ```

## Monitoring

### Health Checks

The HelmRelease includes built-in health checks. View status:

```bash
# Check overall health
kubectl get helmrelease wiz-sensor -n wiz-system

# Check detailed status
kubectl describe helmrelease wiz-sensor -n wiz-system | grep -A 10 "Status:"
```

### Metrics

If Prometheus is deployed:

```bash
# Check if metrics are exposed
kubectl get servicemonitor -n wiz-system

# Port-forward to check metrics
kubectl port-forward -n wiz-system svc/wiz-sensor 9090:9090
curl localhost:9090/metrics
```

### Alerts

Configure alerts in Wiz portal and/or Prometheus AlertManager for:
- Sensor connectivity issues
- Failed scans
- Resource exhaustion
- Pod restarts

## Integration with CI/CD

### Automated Promotion Flow

```bash
# Dev → Staging
# 1. Test in dev
# 2. Update staging overlay with tested version
# 3. Create PR to staging branch

# Staging → Production
# 1. Validate in staging
# 2. Update production overlay
# 3. Create PR to main branch with approvals
```

### GitHub Actions Example

```yaml
name: Promote Wiz Config to Production
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Wiz chart version to deploy'
        required: true

jobs:
  promote:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Update production config
        run: |
          sed -i 's/version: .*/version: "${{ github.event.inputs.version }}"/' \
            flux-deployments/infrastructure/base/wiz-sensor-helmrelease.yaml
      - name: Create PR
        uses: peter-evans/create-pull-request@v5
        with:
          title: "Promote Wiz sensor to ${{ github.event.inputs.version }}"
```

## References

- [Wiz Kubernetes Integration Documentation](https://docs.wiz.io/wiz-docs/docs/kubernetes-integration)
- [Flux Helm Controller Documentation](https://fluxcd.io/docs/components/helm/)
- [Flux GitRepository Documentation](https://fluxcd.io/docs/components/source/gitrepositories/)
- [Kustomize Documentation](https://kustomize.io/)

## Support

For issues related to:
- **Wiz sensor**: Contact Wiz support or check [Wiz documentation](https://docs.wiz.io)
- **Flux**: Check [Flux documentation](https://fluxcd.io) or [GitHub discussions](https://github.com/fluxcd/flux2/discussions)
- **AKS**: Contact Azure support or check [AKS documentation](https://learn.microsoft.com/en-us/azure/aks/)
