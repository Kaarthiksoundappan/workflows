# AKS Cluster Execution Guide

This guide provides step-by-step instructions for deploying an Azure Kubernetes Service (AKS) cluster using the provided Terraform configuration.

## Prerequisites

Before you begin, ensure you have the following installed and configured:

1. **Terraform**: Version 1.0 or higher installed on your machine
2. **Azure CLI**: Installed and configured for authentication
3. **Azure Subscription**: Active subscription with appropriate permissions
4. **kubectl**: For interacting with the cluster after creation (optional but recommended)

## File Overview

The Terraform configuration consists of the following files:

- **main.tf**: Core infrastructure definitions including AKS cluster, networking, and Log Analytics
- **variables.tf**: Input variable declarations with descriptions and defaults
- **outputs.tf**: Output values that will be displayed after successful deployment
- **terraform.tfvars.example**: Example variable values template

## Step-by-Step Execution

### Step 1: Authentication

Authenticate to Azure using the Azure CLI. This establishes your credentials for Terraform to use.

The Azure CLI will open a browser window for authentication. Sign in with your Azure account credentials.

### Step 2: Set Active Subscription

If you have multiple Azure subscriptions, set the subscription you want to use for deployment.

You can list available subscriptions and then select the appropriate one.

### Step 3: Prepare Configuration Files

Create your own variables file by copying the example file and customizing the values to match your requirements.

Edit the newly created file to update the required values:
- Resource group name
- Cluster name
- DNS prefix
- Location
- Node pool sizes and counts
- Network configuration
- Tags

### Step 4: Initialize Terraform

Initialize the Terraform working directory. This downloads the Azure provider and prepares the backend.

This step:
- Downloads the azurerm provider plugin
- Initializes the backend for state storage
- Prepares the working directory

### Step 5: Validate Configuration

Validate the Terraform configuration files to check for syntax errors and configuration issues.

This catches configuration errors before attempting to create resources.

### Step 6: Review the Execution Plan

Generate and review an execution plan. This shows exactly what Terraform will create, modify, or destroy.

Carefully review the plan output to ensure it matches your expectations. The plan will show:
- Resources to be created (indicated with +)
- Number of resources to add
- Estimated changes

### Step 7: Apply the Configuration

Execute the plan to create the infrastructure. Terraform will provision all resources defined in the configuration.

Terraform will prompt for confirmation. Type 'yes' to proceed with the deployment.

This process typically takes 10-15 minutes to complete. Terraform will create:
- Resource group
- Virtual network and subnet
- Log Analytics workspace (if enabled)
- AKS cluster with system node pool
- Additional user node pool (if configured)
- Network role assignments

### Step 8: Retrieve Outputs

After successful deployment, Terraform displays output values including cluster name, resource group, and other important information.

You can view outputs at any time without making changes to infrastructure.

## Post-Deployment Steps

### Configure kubectl Access

To interact with your new AKS cluster, configure kubectl with the cluster credentials.

This merges the AKS cluster credentials into your kubeconfig file.

### Verify Cluster Access

Test connectivity to your cluster.

This should display information about your nodes and confirm successful access.

### View Cluster Resources

Explore the deployed resources in the Azure Portal or via Azure CLI.

## Managing the Cluster

### Updating the Cluster

To modify the cluster configuration:

1. Edit the terraform.tfvars file with your desired changes
2. Run plan to preview the changes
3. Review the plan output carefully
4. Run apply to execute the changes

Terraform will only modify the resources that have changed.

### Scaling Node Pools

To scale the cluster:
- Modify the node count values in terraform.tfvars
- Run plan and apply

If auto-scaling is enabled, you can adjust the min and max count values.

### Viewing Current State

To see the current state of your infrastructure as managed by Terraform.

This displays all resources currently tracked in the Terraform state.

### Destroying the Cluster

When you no longer need the cluster, you can destroy all resources.

Type 'yes' when prompted to confirm destruction. This will delete:
- AKS cluster
- Node pools
- Virtual network and subnet
- Log Analytics workspace
- Resource group
- All associated resources

## State Management

### Local State

By default, Terraform stores state locally in a terraform.tfstate file. This file:
- Contains sensitive information
- Should never be committed to version control
- Should be backed up regularly

Add to your .gitignore file to prevent accidental commits.

### Remote State (Recommended for Teams)

For team environments, use remote state storage in Azure Storage Account:

1. Create a storage account and container for state files
2. Configure the backend in a separate backend.tf file
3. Initialize Terraform with the backend configuration

This provides:
- State locking to prevent concurrent modifications
- Centralized state storage
- Better collaboration capabilities

## Troubleshooting

### Authentication Issues

If you encounter authentication errors, re-authenticate with Azure CLI and verify your subscription is set correctly.

### Insufficient Permissions

Ensure your Azure account has the necessary permissions:
- Contributor or Owner role on the subscription or resource group
- Ability to create service principals and role assignments

### Quota Limits

Check Azure quota limits in your region if you receive quota-related errors. You may need to request quota increases for specific VM families.

### State Lock Issues

If the state file becomes locked, you can force unlock it, but only do this if you're certain no other process is running.

## Best Practices

1. **Version Control**: Store Terraform files in Git, excluding tfstate and tfvars files
2. **Environment Separation**: Use separate state files for dev, staging, and production
3. **Variable Files**: Use different tfvars files for each environment
4. **Plan Before Apply**: Always review the plan before applying changes
5. **State Backups**: Regularly backup your state files
6. **Module Usage**: Consider extracting common configurations into reusable modules
7. **Sensitive Data**: Never hardcode sensitive values; use Azure Key Vault integration
8. **Resource Tagging**: Consistently tag all resources for cost tracking and management

## Additional Resources

- **Terraform AKS Provider Documentation**: Official reference for azurerm_kubernetes_cluster
- **Azure AKS Documentation**: Best practices and operational guidance
- **Kubernetes Documentation**: Understanding cluster operations
- **Azure CLI Reference**: Command reference for Azure management

## Support and Maintenance

### Regular Updates

Keep your Terraform configuration up to date:
- Update Kubernetes version regularly for security patches
- Update Terraform provider versions
- Review and apply Azure security recommendations

### Monitoring

Enable and configure monitoring:
- Review Log Analytics workspace data
- Set up Azure Monitor alerts
- Configure cost alerts for budget management

### Backup Strategy

Implement a backup strategy:
- Regular state file backups
- Cluster workload backups (Velero or similar)
- Network configuration documentation
