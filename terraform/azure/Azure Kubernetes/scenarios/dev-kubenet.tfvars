# Development Environment with Kubenet
# Lower cost, basic networking, suitable for dev/test

# Required Variables
resource_group_name = "rg-aks-dev"
cluster_name        = "aks-dev-kubenet"
dns_prefix          = "aks-dev"

# Azure Region
location = "East US"

# Kubernetes Version
kubernetes_version = "1.28"

# Cluster Configuration
sku_tier                = "Free"
private_cluster_enabled = false

# Network Configuration - Kubenet (Basic)
network_plugin = "kubenet"
network_policy = "calico"
network_mode   = "transparent"

# Pod CIDR (required for kubenet)
pod_cidr = "10.244.0.0/16"

# VNet Configuration
create_vnet           = true
vnet_address_space    = "10.0.0.0/16"
subnet_address_prefix = "10.0.1.0/24"

# Service Network
service_cidr   = "10.1.0.0/16"
dns_service_ip = "10.1.0.10"

# Load Balancer
load_balancer_sku = "standard"
outbound_type     = "loadBalancer"

# System Node Pool - Small for dev
system_node_count = 2
system_node_size  = "Standard_B2s"
os_disk_size_gb   = 30

# Auto-scaling - Disabled for predictable costs
enable_auto_scaling = false

# Availability Zones - Not needed for dev
availability_zones = []

# Security
enable_host_encryption = false
enable_node_public_ip  = false

# User Node Pool - Not needed for dev
create_user_node_pool = false

# Spot Instances - Not needed for dev
create_spot_node_pool = false

# Monitoring
enable_log_analytics = false
enable_azure_policy  = false

# Identity
identity_type = "SystemAssigned"

# Tags
tags = {
  Environment = "Development"
  CostCenter  = "Engineering"
  ManagedBy   = "Terraform"
  NetworkType = "Kubenet"
}
