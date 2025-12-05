output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.fqdn
}

output "kube_config_raw" {
  description = "Raw Kubernetes config for kubectl access"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "client_certificate" {
  description = "Client certificate for cluster authentication"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate
  sensitive   = true
}

output "kube_config" {
  description = "Kubernetes configuration"
  value       = azurerm_kubernetes_cluster.aks.kube_config
  sensitive   = true
}

output "cluster_identity" {
  description = "Identity of the AKS cluster"
  value = {
    principal_id = azurerm_kubernetes_cluster.aks.identity[0].principal_id
    tenant_id    = azurerm_kubernetes_cluster.aks.identity[0].tenant_id
  }
}

output "node_resource_group" {
  description = "Auto-generated resource group containing AKS cluster nodes"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.aks.name
}

output "location" {
  description = "Azure region where resources are deployed"
  value       = azurerm_resource_group.aks.location
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.aks.id
}

output "subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace (if enabled)"
  value       = var.enable_log_analytics ? azurerm_log_analytics_workspace.aks[0].id : null
}
