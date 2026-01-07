# Configuration Guide

Complete setup instructions for clusters.json, GitHub Secrets, and Wiz Kubernetes configuration files.

**Related Guides:** [README](README.md) | [Workflow Guide](workflow-guide.md) | [Troubleshooting](troubleshooting-guide.md)

---

## Table of Contents

1. [clusters.json Configuration](#clustersjson-configuration)
2. [GitHub Secrets Setup](#github-secrets-setup)
3. [Wiz Kubernetes Files](#wiz-kubernetes-files)
4. [Key Vault Integration (Optional)](#key-vault-integration-optional)

---

## clusters.json Configuration

This file defines all clusters and their configurations. The workflow uses this to determine deployment targets.

### File Location

**File:** `config/clusters.json`

### Example Configuration

```json
{
  "clusters": [
    {
      "portfolio": "Selling Data",
      "environment": "Non Production",
      "cluster_name": "sellingdataaks",
      "resource_group": "sellingdata-nonprod-rg",
      "subscription_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
      "wiz_secret_prefix": "SELLINGDATA_NONPROD",
      "acr_server": "sellingdataacr.azurecr.io"
    },
    {
      "portfolio": "Selling Data",
      "environment": "Production",
      "cluster_name": "sellingdataprodaks",
      "resource_group": "sellingdata-prod-rg",
      "subscription_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
      "wiz_secret_prefix": "SELLINGDATA_PROD",
      "acr_server": "sellingdataacr.azurecr.io"
    },
    {
      "portfolio": "Another Portfolio",
      "environment": "Non Production",
      "cluster_name": "anotheraks",
      "resource_group": "another-nonprod-rg",
      "subscription_id": "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy",
      "wiz_secret_prefix": "ANOTHER_NONPROD",
      "acr_server": "anotheracr.azurecr.io"
    },
    {
      "portfolio": "Another Portfolio",
      "environment": "Production",
      "cluster_name": "anotherprodaks",
      "resource_group": "another-prod-rg",
      "subscription_id": "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy",
      "wiz_secret_prefix": "ANOTHER_PROD",
      "acr_server": "anotheracr.azurecr.io"
    }
  ]
}
```

### Configuration Fields

| Field | Description | Example | Required |
|-------|-------------|---------|----------|
| `portfolio` | Portfolio/Project name (must match folder structure) | `Selling Data` | ✅ Yes |
| `environment` | Environment type (must match folder structure) | `Non Production` or `Production` | ✅ Yes |
| `cluster_name` | AKS cluster name in Azure | `sellingdataaks` | ✅ Yes |
| `resource_group` | Azure resource group containing the cluster | `sellingdata-nonprod-rg` | ✅ Yes |
| `subscription_id` | Azure subscription ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` | ✅ Yes |
| `wiz_secret_prefix` | Prefix for GitHub secret names | `SELLINGDATA_NONPROD` | ✅ Yes |
| `acr_server` | Azure Container Registry server URL | `sellingdataacr.azurecr.io` | ✅ Yes |

### Important Notes

- **Portfolio and Environment** values must exactly match your folder structure
- **wiz_secret_prefix** determines which GitHub Secrets are used for each cluster
- All clusters in the same environment/portfolio can share the same ACR server

---

## GitHub Secrets Setup

GitHub Secrets are used to securely store credentials needed for deployment.

### How to Add Secrets

1. Navigate to your GitHub repository
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret below

### Required Secrets

#### Global Secrets (Shared Across All Clusters)

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AZURE_CREDENTIALS` | Service Principal JSON for Azure authentication | See format below |
| `ACR_USERNAME` | Azure Container Registry username | `sellingdataacr` |
| `ACR_PASSWORD` | Azure Container Registry password or access token | `xxxxxxxxxxxxxxxx` |

#### Per-Environment Wiz Secrets

Naming convention: `{wiz_secret_prefix}_WIZ_CLIENT_ID` and `{wiz_secret_prefix}_WIZ_CLIENT_TOKEN`

Based on the example clusters.json above, you would need:

| Secret Name | Description |
|-------------|-------------|
| `SELLINGDATA_NONPROD_WIZ_CLIENT_ID` | Wiz Client ID for Selling Data Non-Production |
| `SELLINGDATA_NONPROD_WIZ_CLIENT_TOKEN` | Wiz Client Token for Selling Data Non-Production |
| `SELLINGDATA_PROD_WIZ_CLIENT_ID` | Wiz Client ID for Selling Data Production |
| `SELLINGDATA_PROD_WIZ_CLIENT_TOKEN` | Wiz Client Token for Selling Data Production |
| `ANOTHER_NONPROD_WIZ_CLIENT_ID` | Wiz Client ID for Another Portfolio Non-Production |
| `ANOTHER_NONPROD_WIZ_CLIENT_TOKEN` | Wiz Client Token for Another Portfolio Non-Production |
| `ANOTHER_PROD_WIZ_CLIENT_ID` | Wiz Client ID for Another Portfolio Production |
| `ANOTHER_PROD_WIZ_CLIENT_TOKEN` | Wiz Client Token for Another Portfolio Production |

### AZURE_CREDENTIALS Format

The `AZURE_CREDENTIALS` secret should contain a JSON object with the following structure:

```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "your-client-secret-here",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

### Generate Azure Service Principal

To create the Service Principal and get the JSON for `AZURE_CREDENTIALS`:

```bash
az ad sp create-for-rbac \
  --name "github-aks-wiz-deploy" \
  --role "Contributor" \
  --scopes /subscriptions/<your-subscription-id> \
  --sdk-auth
```

**Required Azure Roles:**
- `Azure Kubernetes Service Contributor` - For AKS cluster access
- `Azure Kubernetes Service Cluster User Role` - For kubectl operations
- `Contributor` - For managing resources

Copy the entire JSON output and paste it into the `AZURE_CREDENTIALS` secret.

### Get Wiz API Credentials

1. Log in to your Wiz account
2. Go to **Settings** → **Service Accounts**
3. Create a new Service Account for Kubernetes integration
4. Copy the **Client ID** and **Client Secret**
5. Add them to GitHub Secrets using the naming convention above

---

## Wiz Kubernetes Files

Create these three files in each cluster's Wiz folder following the structure:
`{Portfolio}/{Environment}/{Cluster}/Wiz/`

### kustomization.yaml

**File:** `{Portfolio}/{Environment}/{Cluster}/Wiz/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: wiz

resources:
  - repo.yaml
  - release.yaml
```

**Purpose:** Kustomize configuration that defines which resources to deploy in the wiz namespace.

---

### repo.yaml

**File:** `{Portfolio}/{Environment}/{Cluster}/Wiz/repo.yaml`

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: wiz
  namespace: wiz
spec:
  interval: 1h
  url: oci://your-acr.azurecr.io/helm
  type: oci
  secretRef:
    name: acr-secret
```

**Purpose:** Defines the Helm repository source for Wiz charts.

**Customization Required:**
- Replace `your-acr.azurecr.io` with your actual ACR server URL (from clusters.json)

**Options:**
- For public Wiz repository: `url: https://charts.wiz.io` (remove `secretRef` and `type: oci`)
- For private ACR: Use OCI format as shown above

---

### release.yaml

**File:** `{Portfolio}/{Environment}/{Cluster}/Wiz/release.yaml`

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: wiz-kubernetes-integration
  namespace: wiz
spec:
  interval: 1h
  chart:
    spec:
      chart: wiz-kubernetes-integration
      version: "0.3.6"  # Specify your version
      sourceRef:
        kind: HelmRepository
        name: wiz
        namespace: wiz
  values:
    global:
      wizApiToken:
        secret:
          name: wiz-api-token
          clientIdKey: clientId
          clientTokenKey: clientToken

    wiz-kubernetes-connector:
      enabled: true
      autoCreateConnector:
        enabled: true
        connectorName: "sellingdataaks-connector"  # Update per cluster
        clusterFlavor: "AKS"

    wiz-admission-controller:
      enabled: true

    wiz-sensor:
      enabled: true
      imagePullSecrets:
        - name: acr-secret
```

**Purpose:** Defines the Helm release configuration for Wiz Kubernetes Integration.

**Customization Required:**
1. **version:** Set to your desired Wiz chart version (e.g., `0.3.6`)
2. **connectorName:** Update with cluster-specific name (e.g., `sellingdataprodaks-connector`)
3. **values:** Adjust component enablement and configuration as needed

**Component Options:**
- `wiz-kubernetes-connector`: Connects cluster to Wiz platform
- `wiz-admission-controller`: Policy enforcement and admission control
- `wiz-sensor`: Runtime security and vulnerability scanning

---

## Key Vault Integration (Optional)

For enhanced security, you can retrieve secrets from Azure Key Vault instead of GitHub Secrets.

### Benefits

- Centralized secret management
- Rotation capabilities
- Audit logging
- RBAC policies

### Implementation

#### Step 1: Store Secrets in Key Vault

```bash
# Define Key Vault name
KV_NAME="my-keyvault"

# Store ACR credentials
az keyvault secret set --vault-name $KV_NAME --name acr-username --value "my-acr-username"
az keyvault secret set --vault-name $KV_NAME --name acr-password --value "my-acr-password"

# Store Wiz credentials
az keyvault secret set --vault-name $KV_NAME --name wiz-client-id --value "wiz-client-id-value"
az keyvault secret set --vault-name $KV_NAME --name wiz-client-token --value "wiz-client-token-value"
```

#### Step 2: Grant Service Principal Access

```bash
# Get Service Principal Object ID
SP_OBJECT_ID=$(az ad sp show --id <service-principal-client-id> --query id -o tsv)

# Grant Key Vault access
az keyvault set-policy \
  --name $KV_NAME \
  --object-id $SP_OBJECT_ID \
  --secret-permissions get list
```

#### Step 3: Modify Workflow

Replace the secret creation steps in `.github/workflows/deploy-wiz.yml` with:

```yaml
      - name: Get Secrets from Key Vault
        run: |
          # Define Key Vault name (adjust naming convention as needed)
          KV_NAME="${{ matrix.cluster_name }}-kv"

          echo "Retrieving secrets from Key Vault: $KV_NAME"

          # Get ACR credentials
          ACR_USERNAME=$(az keyvault secret show --vault-name $KV_NAME --name acr-username --query value -o tsv)
          ACR_PASSWORD=$(az keyvault secret show --vault-name $KV_NAME --name acr-password --query value -o tsv)

          # Get Wiz credentials
          WIZ_CLIENT_ID=$(az keyvault secret show --vault-name $KV_NAME --name wiz-client-id --query value -o tsv)
          WIZ_CLIENT_TOKEN=$(az keyvault secret show --vault-name $KV_NAME --name wiz-client-token --query value -o tsv)

          # Create ACR secret
          kubectl create secret docker-registry acr-secret \
            --namespace $WIZ_NAMESPACE \
            --docker-server=${{ matrix.acr_server }} \
            --docker-username=$ACR_USERNAME \
            --docker-password=$ACR_PASSWORD \
            --dry-run=client -o yaml | kubectl apply -f -

          # Create Wiz token secret
          kubectl create secret generic wiz-api-token \
            --namespace $WIZ_NAMESPACE \
            --from-literal=clientId=$WIZ_CLIENT_ID \
            --from-literal=clientToken=$WIZ_CLIENT_TOKEN \
            --dry-run=client -o yaml | kubectl apply -f -
```

### Key Vault Naming Conventions

You can organize Key Vaults by:
- **Per-cluster:** `{cluster_name}-kv`
- **Per-environment:** `{portfolio}-{environment}-kv`
- **Centralized:** Single Key Vault with secret naming conventions

---

## Configuration Checklist

### Initial Setup

- [ ] Create `config/clusters.json` with all cluster definitions
- [ ] Verify portfolio/environment names match folder structure
- [ ] Add `AZURE_CREDENTIALS` GitHub Secret
- [ ] Add `ACR_USERNAME` and `ACR_PASSWORD` GitHub Secrets
- [ ] Add per-environment Wiz secrets (CLIENT_ID and CLIENT_TOKEN)

### Per-Cluster Setup

- [ ] Create folder: `{Portfolio}/{Environment}/{Cluster}/Wiz/`
- [ ] Create `kustomization.yaml`
- [ ] Create `repo.yaml` (update ACR URL)
- [ ] Create `release.yaml` (update version and connectorName)
- [ ] Verify file structure matches clusters.json

### Validation

- [ ] Test with dry-run action first
- [ ] Verify all GitHub Secrets are properly named
- [ ] Confirm Service Principal has required permissions
- [ ] Check ACR credentials are valid

---

## Related Guides

- **[Workflow Guide](workflow-guide.md)** - Understand the deployment workflow
- **[Troubleshooting Guide](troubleshooting-guide.md)** - Debug configuration issues
- **[README](README.md)** - Back to overview
