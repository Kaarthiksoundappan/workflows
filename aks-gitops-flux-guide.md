# AKS GitOps & Flux Extension - Comprehensive Guide

## What is AKS GitOps & Flux Extension?

### Overview

**AKS GitOps with Flux** is a Microsoft Azure-managed extension that enables GitOps workflows in Azure Kubernetes Service (AKS) clusters. It uses **Flux v2** (also known as Flux CD v2), a CNCF graduated project, to implement continuous delivery and automated synchronization between your Git repository and Kubernetes clusters.

### Key Concepts

#### GitOps Principles
GitOps is a modern approach to continuous deployment where:
- **Git is the single source of truth** for declarative infrastructure and applications
- **Automated delivery** of infrastructure/application changes from Git to clusters
- **Self-healing** - clusters automatically reconcile to match Git state
- **Audit trail** - all changes tracked via Git commits

#### Flux v2 Architecture
Flux v2 is composed of specialized controllers:
- **Source Controller** - Handles Git repositories, Helm repositories, and buckets
- **Kustomize Controller** - Reconciles Kustomize configurations
- **Helm Controller** - Reconciles Helm releases
- **Notification Controller** - Sends events and handles webhooks
- **Image Automation Controller** - Updates container images automatically

---

## Why Use AKS GitOps & Flux Extension?

### Benefits

1. **Fully Managed Service**
   - Microsoft manages Flux installation, updates, and lifecycle
   - Integrated with Azure Resource Manager (ARM)
   - No manual Flux installation required

2. **Azure Integration**
   - Native integration with Azure Monitor and Azure Policy
   - Azure RBAC for access control
   - Managed identity support for secure authentication

3. **Multi-Cluster Management**
   - Manage multiple AKS clusters from a single Git repository
   - Consistent configurations across environments
   - Fleet management capabilities with Azure Arc

4. **Declarative Configuration**
   - All cluster state defined in Git
   - Infrastructure as Code (IaC) approach
   - Version control for all changes

5. **Security & Compliance**
   - Git-based audit trail
   - Automated drift detection and correction
   - Policy-driven governance with Azure Policy

6. **Developer Experience**
   - GitOps workflow - developers just push to Git
   - Automated deployments without cluster access
   - Pull-based model (secure, no cluster credentials in CI/CD)

---

## How AKS GitOps & Flux Extension Works

### Architecture Flow

```
┌──────────────┐
│ Git Repository│
│  (Source of   │
│    Truth)     │
└──────┬────────┘
       │
       │ Flux monitors Git repo
       │ (pull-based)
       ▼
┌──────────────────────────┐
│  AKS Cluster with Flux   │
│  Extension               │
│  ┌────────────────────┐  │
│  │ Source Controller  │  │
│  │ (Fetches manifests)│  │
│  └─────────┬──────────┘  │
│            │              │
│            ▼              │
│  ┌────────────────────┐  │
│  │ Kustomize/Helm     │  │
│  │ Controller         │  │
│  │ (Applies changes)  │  │
│  └─────────┬──────────┘  │
│            │              │
│            ▼              │
│  ┌────────────────────┐  │
│  │ Kubernetes         │  │
│  │ Resources          │  │
│  │ (Deployed apps)    │  │
│  └────────────────────┘  │
└──────────────────────────┘
```

### Workflow Steps

1. **Developer commits changes** to Git repository
2. **Flux Source Controller** detects changes (polls or webhook)
3. **Flux downloads** manifests from Git
4. **Kustomize/Helm Controller** applies changes to cluster
5. **Cluster state** reconciles to match Git state
6. **Continuous monitoring** ensures drift detection and correction

---

## Installing AKS GitOps & Flux Extension

### Prerequisites

- Azure subscription
- AKS cluster (or Azure Arc-enabled Kubernetes cluster)
- Azure CLI (`az`) version 2.37.0 or later
- Git repository with Kubernetes manifests

### Installation Methods

#### Method 1: Azure CLI

```bash
# Install the k8s-configuration extension
az extension add --name k8s-configuration

# Verify installation
az extension list --output table

# Create Flux configuration
az k8s-configuration flux create \
  --resource-group <resource-group-name> \
  --cluster-name <cluster-name> \
  --cluster-type managedClusters \
  --name <configuration-name> \
  --namespace flux-system \
  --scope cluster \
  --url https://github.com/<org>/<repo> \
  --branch main \
  --kustomization name=apps \
    path=./apps \
    prune=true \
    retry_interval=1m
```

#### Method 2: Azure Portal

1. Navigate to your AKS cluster in Azure Portal
2. Select **GitOps** from the left menu
3. Click **Create**
4. Configure:
   - Configuration name
   - Namespace (default: flux-system)
   - Scope (Cluster or Namespace)
   - Source type (Git Repository)
   - Repository URL
   - Branch/Tag/Commit
   - Kustomization settings

#### Method 3: ARM Template / Bicep

```bicep
resource fluxConfiguration 'Microsoft.KubernetesConfiguration/fluxConfigurations@2022-03-01' = {
  name: 'flux-config'
  scope: aksCluster
  properties: {
    scope: 'cluster'
    namespace: 'flux-system'
    sourceKind: 'GitRepository'
    gitRepository: {
      url: 'https://github.com/your-org/your-repo'
      repositoryRef: {
        branch: 'main'
      }
      syncIntervalInSeconds: 60
    }
    kustomizations: {
      apps: {
        path: './apps'
        prune: true
        syncIntervalInSeconds: 60
      }
    }
  }
}
```

---

## Key Features

### 1. **Multi-Tenancy Support**
- Namespace-scoped or cluster-scoped configurations
- Multiple Flux configurations per cluster
- Isolation between teams/applications

### 2. **Kustomization Support**
- Built-in Kustomize integration
- Environment-specific overlays (dev, staging, prod)
- Variable substitution

### 3. **Helm Support**
- HelmRelease custom resources
- Helm chart repositories
- Values file management

### 4. **Secret Management**
- Integration with Azure Key Vault
- Sealed Secrets support
- SOPS (Secrets Operations) encryption

### 5. **Notification & Alerting**
- Webhook notifications
- Integration with Azure Monitor
- Slack, Teams, Discord notifications

### 6. **Image Automation**
- Automatic image updates
- Policy-based image selection
- Git commit automation for new images

---

## Common Use Cases

### 1. **Application Deployment**
Deploy applications automatically when code is pushed to Git

### 2. **Infrastructure Management**
Manage cluster infrastructure (ingress, monitoring, storage)

### 3. **Multi-Environment Management**
Maintain separate branches/folders for dev, staging, production

### 4. **Multi-Cluster Deployment**
Deploy same configurations to multiple clusters

### 5. **Compliance & Security**
Enforce policies and security configurations via Git

---

## Best Practices

### Repository Structure
```
├── clusters/
│   ├── dev/
│   ├── staging/
│   └── production/
├── infrastructure/
│   ├── base/
│   └── overlays/
├── apps/
│   ├── base/
│   └── overlays/
└── flux-system/
    ├── gotk-components.yaml
    └── gotk-sync.yaml
```

### Configuration Tips

1. **Use separate repositories or branches** for different environments
2. **Implement proper RBAC** for Git repository access
3. **Enable notifications** for deployment status
4. **Use Kustomize overlays** for environment-specific configs
5. **Implement secrets management** (Key Vault, Sealed Secrets)
6. **Set appropriate sync intervals** (default: 5 minutes)
7. **Enable pruning** to remove deleted resources
8. **Use health checks** to validate deployments

---

## Monitoring & Troubleshooting

### Check Flux Status

```bash
# List Flux configurations
az k8s-configuration flux list \
  --resource-group <rg> \
  --cluster-name <cluster> \
  --cluster-type managedClusters

# Show configuration details
az k8s-configuration flux show \
  --resource-group <rg> \
  --cluster-name <cluster> \
  --cluster-type managedClusters \
  --name <config-name>

# Check Flux pods
kubectl get pods -n flux-system

# Check GitRepository source
kubectl get gitrepositories -n flux-system

# Check Kustomizations
kubectl get kustomizations -n flux-system

# View Flux logs
kubectl logs -n flux-system deploy/source-controller
kubectl logs -n flux-system deploy/kustomize-controller
```

### Common Issues

1. **Authentication failures** - Check Git credentials, SSH keys, or tokens
2. **Path not found** - Verify Kustomization path in Git repository
3. **Drift detected** - Manual changes in cluster overwritten by Flux
4. **Reconciliation errors** - Check Flux controller logs

---

## Security Considerations

### Authentication Methods

1. **HTTPS with Personal Access Token (PAT)**
   - Store PAT in Kubernetes secret
   - Use Azure Key Vault for secret management

2. **SSH Key Authentication**
   - Generate SSH key pair
   - Add public key to Git repository
   - Store private key securely

3. **Azure DevOps Integration**
   - Use Azure DevOps PAT
   - Service Connection authentication

### Secrets Management

- **Never commit secrets** to Git repository
- Use **Sealed Secrets** or **SOPS** for encrypted secrets
- Integrate with **Azure Key Vault** using CSI driver
- Use **External Secrets Operator** for dynamic secret injection

---

## Comparison: Flux vs ArgoCD vs Jenkins

| Feature | Flux (AKS Extension) | ArgoCD | Jenkins |
|---------|---------------------|--------|---------|
| **Model** | Pull-based | Pull-based | Push-based |
| **Azure Integration** | Native | Manual setup | Manual setup |
| **Management** | Microsoft managed | Self-managed | Self-managed |
| **UI** | Azure Portal | Web UI | Web UI |
| **Multi-cluster** | Native support | Native support | Requires plugins |
| **Helm Support** | Native | Native | Via plugins |
| **GitOps Native** | Yes | Yes | No |

---

## Resources

### Official Documentation
- [Microsoft Docs - GitOps with Flux](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/conceptual-gitops-flux2)
- [Flux CD Documentation](https://fluxcd.io/docs/)
- [CNCF Flux Project](https://github.com/fluxcd/flux2)

### Community
- [Flux Slack Channel](https://cloud-native.slack.com/)
- [Flux GitHub Discussions](https://github.com/fluxcd/flux2/discussions)

---

## Summary

**AKS GitOps & Flux Extension** provides a fully managed, Azure-native GitOps solution that:
- Automates Kubernetes deployments from Git
- Ensures cluster state matches Git declarations
- Integrates seamlessly with Azure services
- Provides enterprise-grade security and compliance
- Simplifies multi-cluster management
- Enables true Infrastructure as Code practices

By adopting GitOps with Flux, teams can achieve faster, more reliable, and more secure deployments while maintaining full auditability and compliance.
