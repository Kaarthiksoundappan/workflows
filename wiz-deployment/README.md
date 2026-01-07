# Wiz Kubernetes Integration - Deployment Guide

Automated deployment of Wiz Kubernetes Integration using GitHub Actions and Flux GitOps across multiple portfolios and environments.

---

## 📚 Documentation

This guide is split into focused sections for easier navigation:

| Guide | Description |
|-------|-------------|
| **[README](README.md)** (This file) | Overview, architecture, and quick start |
| **[Workflow Guide](workflow-guide.md)** | GitHub Actions workflow, flowcharts, and execution details |
| **[Configuration Guide](configuration-guide.md)** | Setup instructions for clusters.json, secrets, and Wiz files |
| **[Troubleshooting Guide](troubleshooting-guide.md)** | Common issues, debug commands, and solutions |

---

## Overview

This solution provides a reusable, automated approach for deploying Wiz Kubernetes Integration across multiple AKS clusters using:

- **GitHub Actions** - CI/CD automation
- **Flux** - GitOps continuous delivery
- **Kustomize** - Kubernetes configuration management

### Key Features

| Feature | Description |
|---------|-------------|
| Multi-Portfolio Support | Deploy across different portfolios (Selling Data, etc.) |
| Multi-Environment Support | Handle Production and Non-Production environments |
| Selective Deployment | Deploy to specific clusters or all at once |
| Dry Run Mode | Preview changes before applying |
| Auto-Trigger | Automatic deployment on Git push to Wiz folders |
| Independent Deployment | Wiz deployment doesn't affect other Flux components |

---

## Architecture

### How It Works

```
┌─────────────────────────────────────────────────────────────────────┐
│                         GitHub Repository                           │
│                                                                     │
│  ┌─────────────────┐    ┌─────────────────────────────────────┐    │
│  │ .github/        │    │ Selling Data/                       │    │
│  │   workflows/    │    │   ├── Non Production/               │    │
│  │     deploy-     │    │   │     └── sellingdataaks/         │    │
│  │     wiz.yml     │    │   │           └── Wiz/              │    │
│  └────────┬────────┘    │   └── Production/                   │    │
│           │             │         └── sellingdataprodaks/     │    │
│           │             │               └── Wiz/              │    │
│           │             └─────────────────────────────────────┘    │
└───────────┼─────────────────────────────────────────────────────────┘
            │
            │ Triggers on:
            │ - Manual dispatch
            │ - Push to **/Wiz/**
            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      GitHub Actions Workflow                        │
│                                                                     │
│  1. Read clusters.json to determine targets                         │
│  2. Azure Login                                                     │
│  3. For each target cluster:                                        │
│     ├── Get AKS credentials                                         │
│     ├── Create namespace & secrets                                  │
│     └── Setup/Update Flux configuration                             │
└─────────────────────────────────────────────────────────────────────┘
            │
            │ Creates Flux Kustomization
            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         AKS Cluster                                 │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Flux Controller                           │   │
│  │                                                              │   │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │   │
│  │  │ Kustomization│ │ Kustomization│ │ Kustomization│        │   │
│  │  │   velero     │ │  dynatrace   │ │     wiz      │ ← NEW  │   │
│  │  └──────────────┘ └──────────────┘ └──────────────┘        │   │
│  │         │                │                │                 │   │
│  │         ▼                ▼                ▼                 │   │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │   │
│  │  │ HelmRelease  │ │ HelmRelease  │ │ HelmRelease  │        │   │
│  │  │   Velero     │ │  Dynatrace   │ │     Wiz      │        │   │
│  │  └──────────────┘ └──────────────┘ └──────────────┘        │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Why Wiz Deployment Won't Affect Other Components

Each Flux Kustomization operates independently:

- Separate Git paths
- Separate reconciliation cycles
- Separate namespaces
- No shared dependencies

---

## Prerequisites

### Required Tools & Access

- [ ] GitHub repository with Actions enabled
- [ ] Azure subscription with AKS clusters
- [ ] Azure Service Principal with appropriate permissions
- [ ] Wiz API credentials (Client ID and Token)
- [ ] Azure Container Registry (ACR) access
- [ ] Flux already configured on AKS clusters

### Azure Service Principal Permissions

```bash
# Create Service Principal with required permissions
az ad sp create-for-rbac \
  --name "github-aks-wiz-deploy" \
  --role "Azure Kubernetes Service Contributor" \
  --scopes /subscriptions/<subscription-id> \
  --sdk-auth
```

Required roles:
- `Azure Kubernetes Service Contributor` - For AKS access
- `Azure Kubernetes Service Cluster User Role` - For kubectl access
- `Reader` - For reading resources

---

## Repository Structure

```
gitops/                                    # Repository root
├── .github/
│   └── workflows/
│       └── deploy-wiz.yml                 # GitHub Actions workflow
│
├── config/
│   └── clusters.json                      # Cluster configuration
│
├── Selling Data/                          # Portfolio folder
│   ├── Non Production/                    # Environment folder
│   │   └── sellingdataaks/                # Cluster folder
│   │       ├── Velero/                    # Existing component
│   │       ├── Dynatrace/                 # Existing component
│   │       ├── Nginx/                     # Existing component
│   │       └── Wiz/                       # NEW - Wiz component
│   │           ├── kustomization.yaml
│   │           ├── release.yaml
│   │           └── repo.yaml
│   │
│   └── Production/                        # Environment folder
│       └── sellingdataprodaks/            # Cluster folder
│           └── Wiz/
│               ├── kustomization.yaml
│               ├── release.yaml
│               └── repo.yaml
│
├── Another Portfolio/                     # Another portfolio
│   ├── Non Production/
│   │   └── anotheraks/
│   │       └── Wiz/
│   └── Production/
│       └── anotherprodaks/
│           └── Wiz/
│
└── README.md
```

---

## Quick Start Checklist

### Initial Setup

- [ ] Fork/clone repository
- [ ] Create `.github/workflows/deploy-wiz.yml` (see [Workflow Guide](workflow-guide.md))
- [ ] Create `config/clusters.json` (see [Configuration Guide](configuration-guide.md))
- [ ] Add GitHub Secrets (see [Configuration Guide](configuration-guide.md#github-secrets-setup)):
  - [ ] `AZURE_CREDENTIALS`
  - [ ] `ACR_USERNAME`
  - [ ] `ACR_PASSWORD`
  - [ ] Per-environment Wiz secrets

### Per-Cluster Setup

- [ ] Create folder structure: `{Portfolio}/{Environment}/{Cluster}/Wiz/`
- [ ] Add `kustomization.yaml` (see [Configuration Guide](configuration-guide.md#wiz-kubernetes-files))
- [ ] Add `repo.yaml`
- [ ] Add `release.yaml`
- [ ] Update `release.yaml` with cluster-specific values

### Deployment

- [ ] Run workflow with `dry-run` action first (see [Workflow Guide](workflow-guide.md#usage))
- [ ] Verify dry-run output
- [ ] Run workflow with `deploy` action
- [ ] Verify deployment success
- [ ] Check Wiz pods are running

### Validation Commands

```bash
# Verify secrets created
kubectl get secrets -n wiz

# Verify Flux configuration
az aks flux configuration show \
  --resource-group <rg> \
  --cluster-name <cluster> \
  --cluster-type managedClusters \
  --name wiz-integration

# Verify HelmRelease
kubectl get helmrelease -n wiz

# Verify Wiz pods
kubectl get pods -n wiz
```

---

## Usage Examples

### Deploy to Single Cluster
```
Portfolio: Selling Data
Environment: Non Production
Cluster: sellingdataaks
Action: deploy
```

### Deploy to All Non-Production Clusters
```
Portfolio: ALL
Environment: Non Production
Cluster: (empty)
Action: deploy
```

### Dry Run for Production
```
Portfolio: Selling Data
Environment: Production
Cluster: (empty)
Action: dry-run
```

### Automatic Deployment

Push changes to any `**/Wiz/**` folder:

```bash
git add "Selling Data/Non Production/sellingdataaks/Wiz/release.yaml"
git commit -m "Update Wiz version"
git push origin main
```

The workflow automatically detects which cluster was affected and deploys only to that cluster.

---

## Next Steps

- 📖 **[Workflow Guide](workflow-guide.md)** - Understand the GitHub Actions workflow and see detailed flowcharts
- ⚙️ **[Configuration Guide](configuration-guide.md)** - Set up clusters.json, secrets, and Wiz configuration files
- 🔧 **[Troubleshooting Guide](troubleshooting-guide.md)** - Debug common issues and errors

---

## Support

For issues or questions:
1. Check [Troubleshooting Guide](troubleshooting-guide.md)
2. Review workflow logs in GitHub Actions
3. Check Flux logs: `flux logs -n flux-system`

---

**Document Version:** 1.0
**Last Updated:** 2026-01-07
**Maintainer:** DevOps Team
