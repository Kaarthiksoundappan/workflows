# Deploying Wiz Sensor to Multiple AKS Clusters Using Microsoft Flux Extension

## Overview
This guide will walk you through deploying Wiz sensor to multiple Azure Kubernetes Service (AKS) clusters using the Microsoft Flux extension. The deployment will pull the Wiz sensor Helm chart from your Azure Container Registry.

## Prerequisites

Before starting, ensure you have:
- Azure CLI installed on your local machine
- Access to Azure subscription with appropriate permissions
- Multiple AKS clusters already created
- Wiz sensor Helm chart available in Azure Container Registry (azcontainerregistry)
- Wiz credentials (sensor token/connection details)

## Step 1: Install Azure CLI (if not already installed)

Download and install Azure CLI from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

After installation, open a command prompt or PowerShell and verify:
```bash
az --version
```

## Step 2: Login to Azure

```bash
az login
```

This will open a browser window for authentication. Select your Azure account.

## Step 3: Set Your Azure Subscription

If you have multiple subscriptions, set the correct one:
```bash
az account list --output table
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

## Step 4: Gather Required Information

You'll need the following information:
- **Resource Group Name(s)**: Where your AKS clusters are located
- **AKS Cluster Names**: Names of all clusters where you want to deploy Wiz sensor
- **Azure Container Registry Name**: "azcontainerregistry"
- **Helm Chart Details**:
  - Chart name (e.g., `wizsensor`)
  - Chart version (if specific version required)
- **Wiz Credentials**: Sensor token or connection string from Wiz portal

## Step 5: List Your AKS Clusters

To see all your AKS clusters:
```bash
az aks list --output table
```

Note down the resource group and cluster names.

## Step 6: Grant AKS Access to Azure Container Registry

For each AKS cluster, you need to grant access to pull images from your ACR.

```bash
# Get the ACR resource ID
ACR_ID=$(az acr show --name azcontainerregistry --query id --output tsv)

# For each cluster, attach the ACR
az aks update --name <CLUSTER_NAME> --resource-group <RESOURCE_GROUP> --attach-acr azcontainerregistry
```

Repeat for each cluster or use a loop (see Step 9 for automation).

## Step 7: Install Flux Extension on Each AKS Cluster

For each AKS cluster, install the Microsoft Flux extension:

```bash
az k8s-extension create \
  --cluster-name <CLUSTER_NAME> \
  --resource-group <RESOURCE_GROUP> \
  --cluster-type managedClusters \
  --extension-type microsoft.flux \
  --name flux
```

Wait for the extension to be fully installed (this may take 2-5 minutes):
```bash
az k8s-extension show \
  --cluster-name <CLUSTER_NAME> \
  --resource-group <RESOURCE_GROUP> \
  --cluster-type managedClusters \
  --name flux
```

Look for `"provisioningState": "Succeeded"` in the output.

## Step 8: Create Wiz Sensor Configuration

Create a Kubernetes namespace and secret for Wiz credentials. You'll need to connect to each cluster:

### 8.1: Get AKS Credentials
```bash
az aks get-credentials --resource-group <RESOURCE_GROUP> --name <CLUSTER_NAME>
```

### 8.2: Create Namespace
```bash
kubectl create namespace wiz-system
```

### 8.3: Create Secret with Wiz Credentials
```bash
kubectl create secret generic wiz-credentials \
  --from-literal=clientToken='YOUR_WIZ_CLIENT_TOKEN' \
  --namespace wiz-system
```

Replace `YOUR_WIZ_CLIENT_TOKEN` with your actual Wiz sensor token.

## Step 9: Create Flux Configuration for Wiz Sensor Deployment

Now create a Flux configuration that will deploy the Wiz sensor Helm chart:

```bash
az k8s-configuration flux create \
  --cluster-name <CLUSTER_NAME> \
  --resource-group <RESOURCE_GROUP> \
  --cluster-type managedClusters \
  --name wiz-sensor \
  --namespace wiz-system \
  --scope cluster \
  --kind helmrelease \
  --helm-release-name wizsensor \
  --helm-chart-name wizsensor \
  --helm-chart-version <CHART_VERSION> \
  --source-kind HelmRepository \
  --helm-repo-url "https://azcontainerregistry.azurecr.io/helm/v1/repo"
```

**Note**: You may need to configure authentication for the Helm repository. If the ACR requires authentication:

```bash
az k8s-configuration flux create \
  --cluster-name <CLUSTER_NAME> \
  --resource-group <RESOURCE_GROUP> \
  --cluster-type managedClusters \
  --name wiz-sensor \
  --namespace wiz-system \
  --scope cluster \
  --kind helmrelease \
  --helm-release-name wizsensor \
  --helm-chart-name wizsensor \
  --helm-chart-version <CHART_VERSION> \
  --source-kind HelmRepository \
  --helm-repo-url "oci://azcontainerregistry.azurecr.io/helm/wizsensor" \
  --helm-repo-username <ACR_USERNAME> \
  --helm-repo-password <ACR_PASSWORD>
```

## Step 10: Verify Deployment

Check the Flux configuration status:
```bash
az k8s-configuration flux show \
  --cluster-name <CLUSTER_NAME> \
  --resource-group <RESOURCE_GROUP> \
  --cluster-type managedClusters \
  --name wiz-sensor
```

Check pods are running:
```bash
kubectl get pods -n wiz-system
```

You should see Wiz sensor pods in `Running` state.

## Step 11: Automation Script for Multiple Clusters

To deploy to multiple clusters automatically, create a PowerShell or Bash script:

### PowerShell Script (deploy-wiz-all-clusters.ps1)

```powershell
# Configuration
$resourceGroups = @("rg-cluster-1", "rg-cluster-2")
$clusters = @("aks-cluster-1", "aks-cluster-2", "aks-cluster-3")
$acrName = "azcontainerregistry"
$wizToken = "YOUR_WIZ_CLIENT_TOKEN"
$chartVersion = "1.0.0"  # Update with actual version

# Loop through each cluster
for ($i = 0; $i -lt $clusters.Length; $i++) {
    $clusterName = $clusters[$i]
    $rgName = $resourceGroups[$i]

    Write-Host "Processing cluster: $clusterName in RG: $rgName"

    # 1. Attach ACR to AKS
    Write-Host "Attaching ACR to AKS cluster..."
    az aks update --name $clusterName --resource-group $rgName --attach-acr $acrName

    # 2. Install Flux extension
    Write-Host "Installing Flux extension..."
    az k8s-extension create `
      --cluster-name $clusterName `
      --resource-group $rgName `
      --cluster-type managedClusters `
      --extension-type microsoft.flux `
      --name flux

    # 3. Get credentials
    Write-Host "Getting cluster credentials..."
    az aks get-credentials --resource-group $rgName --name $clusterName --overwrite-existing

    # 4. Create namespace
    Write-Host "Creating wiz-system namespace..."
    kubectl create namespace wiz-system --dry-run=client -o yaml | kubectl apply -f -

    # 5. Create secret
    Write-Host "Creating Wiz credentials secret..."
    kubectl create secret generic wiz-credentials `
      --from-literal=clientToken=$wizToken `
      --namespace wiz-system `
      --dry-run=client -o yaml | kubectl apply -f -

    # 6. Create Flux configuration
    Write-Host "Creating Flux configuration for Wiz sensor..."
    az k8s-configuration flux create `
      --cluster-name $clusterName `
      --resource-group $rgName `
      --cluster-type managedClusters `
      --name wiz-sensor `
      --namespace wiz-system `
      --scope cluster `
      --kind helmrelease `
      --helm-release-name wizsensor `
      --helm-chart-name wizsensor `
      --helm-chart-version $chartVersion `
      --source-kind HelmRepository `
      --helm-repo-url "oci://$acrName.azurecr.io/helm/wizsensor"

    Write-Host "Completed deployment to $clusterName"
    Write-Host "-----------------------------------"
}

Write-Host "All deployments completed!"
```

### Bash Script (deploy-wiz-all-clusters.sh)

```bash
#!/bin/bash

# Configuration
RESOURCE_GROUPS=("rg-cluster-1" "rg-cluster-2")
CLUSTERS=("aks-cluster-1" "aks-cluster-2" "aks-cluster-3")
ACR_NAME="azcontainerregistry"
WIZ_TOKEN="YOUR_WIZ_CLIENT_TOKEN"
CHART_VERSION="1.0.0"  # Update with actual version

# Loop through each cluster
for i in "${!CLUSTERS[@]}"; do
    CLUSTER_NAME="${CLUSTERS[$i]}"
    RG_NAME="${RESOURCE_GROUPS[$i]}"

    echo "Processing cluster: $CLUSTER_NAME in RG: $RG_NAME"

    # 1. Attach ACR to AKS
    echo "Attaching ACR to AKS cluster..."
    az aks update --name "$CLUSTER_NAME" --resource-group "$RG_NAME" --attach-acr "$ACR_NAME"

    # 2. Install Flux extension
    echo "Installing Flux extension..."
    az k8s-extension create \
      --cluster-name "$CLUSTER_NAME" \
      --resource-group "$RG_NAME" \
      --cluster-type managedClusters \
      --extension-type microsoft.flux \
      --name flux

    # 3. Get credentials
    echo "Getting cluster credentials..."
    az aks get-credentials --resource-group "$RG_NAME" --name "$CLUSTER_NAME" --overwrite-existing

    # 4. Create namespace
    echo "Creating wiz-system namespace..."
    kubectl create namespace wiz-system --dry-run=client -o yaml | kubectl apply -f -

    # 5. Create secret
    echo "Creating Wiz credentials secret..."
    kubectl create secret generic wiz-credentials \
      --from-literal=clientToken="$WIZ_TOKEN" \
      --namespace wiz-system \
      --dry-run=client -o yaml | kubectl apply -f -

    # 6. Create Flux configuration
    echo "Creating Flux configuration for Wiz sensor..."
    az k8s-configuration flux create \
      --cluster-name "$CLUSTER_NAME" \
      --resource-group "$RG_NAME" \
      --cluster-type managedClusters \
      --name wiz-sensor \
      --namespace wiz-system \
      --scope cluster \
      --kind helmrelease \
      --helm-release-name wizsensor \
      --helm-chart-name wizsensor \
      --helm-chart-version "$CHART_VERSION" \
      --source-kind HelmRepository \
      --helm-repo-url "oci://$ACR_NAME.azurecr.io/helm/wizsensor"

    echo "Completed deployment to $CLUSTER_NAME"
    echo "-----------------------------------"
done

echo "All deployments completed!"
```

## Step 12: Monitor and Troubleshoot

### Check Flux Status
```bash
kubectl get helmreleases -n wiz-system
kubectl get helmcharts -n wiz-system
```

### View Flux Logs
```bash
kubectl logs -n flux-system -l app=helm-controller
```

### Check Wiz Sensor Pods
```bash
kubectl get pods -n wiz-system
kubectl describe pod <POD_NAME> -n wiz-system
kubectl logs <POD_NAME> -n wiz-system
```

### Common Issues

**Issue 1**: Helm chart not found
- Verify the ACR URL format: `oci://azcontainerregistry.azurecr.io/helm/wizsensor`
- Check ACR authentication is configured correctly

**Issue 2**: Pods not starting
- Check secret is created correctly: `kubectl get secret wiz-credentials -n wiz-system`
- View pod logs for specific errors

**Issue 3**: Flux extension installation fails
- Ensure AKS cluster has outbound internet connectivity
- Check Azure subscription has sufficient permissions

## Step 13: Update or Modify Deployment

To update the Wiz sensor version across all clusters:

```bash
az k8s-configuration flux update \
  --cluster-name <CLUSTER_NAME> \
  --resource-group <RESOURCE_GROUP> \
  --cluster-type managedClusters \
  --name wiz-sensor \
  --helm-chart-version <NEW_VERSION>
```

## Step 14: Remove Wiz Sensor (if needed)

To remove from a specific cluster:

```bash
# Delete Flux configuration
az k8s-configuration flux delete \
  --cluster-name <CLUSTER_NAME> \
  --resource-group <RESOURCE_GROUP> \
  --cluster-type managedClusters \
  --name wiz-sensor \
  --yes

# Delete namespace (optional)
kubectl delete namespace wiz-system
```

## Additional Resources

- [Microsoft Flux Extension Documentation](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2)
- [AKS and ACR Integration](https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration)
- [Wiz Kubernetes Sensor Documentation](https://docs.wiz.io/)

## Summary

This guide covered:
1. Installing prerequisites (Azure CLI)
2. Authenticating with Azure
3. Granting AKS access to ACR
4. Installing Flux extension on each cluster
5. Deploying Wiz sensor using Flux Helm releases
6. Automating deployment across multiple clusters
7. Monitoring and troubleshooting

The Flux extension will continuously monitor and maintain the Wiz sensor deployment, automatically reconciling any drift from the desired state.
