# Large-Scale Cluster with Azure CNI Overlay
# IP-efficient Azure CNI with overlay networking for large clusters

# Required Variables
resource_group_name = "rg-aks-large-scale"
cluster_name        = "aks-overlay-large"
dns_prefix          = "aks-overlay"

# Azure Region
location = "West US 2"

# Kubernetes Version
kubernetes_version = "1.28"

# Cluster Configuration
sku_tier                = "Standard"
private_cluster_enabled = false

# Network Configuration - Azure CNI Overlay
network_plugin = "azure"
network_mode   = "overlay"
network_policy = "azure"

# Pod CIDR (required for overlay mode)
pod_cidr = "10.244.0.0/16"

# VNet Configuration - Smaller subnet needed than traditional Azure CNI
create_vnet           = true
vnet_address_space    = "10.0.0.0/16"
subnet_address_prefix = "10.0.1.0/24"

# Service Network
service_cidr   = "10.1.0.0/16"
dns_service_ip = "10.1.0.10"

# Load Balancer
load_balancer_sku = "standard"
outbound_type     = "loadBalancer"

# System Node Pool - Production ready
system_node_count = 3
system_node_size  = "Standard_D4s_v3"
os_disk_size_gb   = 100

# Auto-scaling - Large scale
enable_auto_scaling = true
min_node_count      = 3
max_node_count      = 50

# Availability Zones
availability_zones = ["1", "2", "3"]

# Security
enable_host_encryption = true
enable_node_public_ip  = false

# User Node Pool - For large-scale application workloads
create_user_node_pool   = true
user_node_count         = 10
user_node_size          = "Standard_D8s_v3"
user_node_pool_priority = "Regular"

# Spot Instances - Additional capacity for burst workloads
create_spot_node_pool = true
spot_node_count       = 5
spot_node_size        = "Standard_D4s_v3"
spot_min_node_count   = 0
spot_max_node_count   = 100
spot_eviction_policy  = "Delete"
spot_max_price        = -1

# Upgrade Settings
max_surge = "33%"

# Monitoring
enable_log_analytics = true
enable_azure_policy  = true

# Identity
identity_type = "SystemAssigned"

# Auto-scaler Configuration - Optimized for large scale
configure_auto_scaler_profile = true
auto_scaler_profile = {
  balance_similar_node_groups      = true
  max_graceful_termination_sec     = 600
  scale_down_delay_after_add       = "15m"
  scale_down_unneeded              = "15m"
  scale_down_utilization_threshold = 0.6
}

# Tags
tags = {
  Environment = "Production"
  CostCenter  = "Platform"
  ManagedBy   = "Terraform"
  NetworkType = "Azure CNI Overlay"
  Scale       = "Large"
}
