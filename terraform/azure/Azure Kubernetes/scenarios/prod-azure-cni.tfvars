# Production Environment with Azure CNI
# High availability, advanced networking, production-ready

# Required Variables
resource_group_name = "rg-aks-prod"
cluster_name        = "aks-prod-azurecni"
dns_prefix          = "aks-prod"

# Azure Region
location = "East US 2"

# Kubernetes Version
kubernetes_version = "1.28"

# Cluster Configuration
sku_tier                = "Standard"
private_cluster_enabled = false

# Network Configuration - Azure CNI (Advanced)
network_plugin = "azure"
network_policy = "azure"
network_mode   = "transparent"

# VNet Configuration - Larger subnet for Azure CNI
create_vnet           = true
vnet_address_space    = "10.0.0.0/8"
subnet_address_prefix = "10.240.0.0/16"

# Service Network
service_cidr   = "10.1.0.0/16"
dns_service_ip = "10.1.0.10"

# Load Balancer
load_balancer_sku = "standard"
outbound_type     = "loadBalancer"

# System Node Pool - Production sizing
system_node_count = 3
system_node_size  = "Standard_D4s_v3"
os_disk_size_gb   = 100

# Auto-scaling - Enabled for production
enable_auto_scaling = true
min_node_count      = 3
max_node_count      = 10

# Availability Zones - High availability
availability_zones = ["1", "2", "3"]

# Security
enable_host_encryption = true
enable_node_public_ip  = false

# User Node Pool - For application workloads
create_user_node_pool     = true
user_node_count           = 3
user_node_size            = "Standard_D4s_v3"
user_node_pool_priority   = "Regular"

# Spot Instances - Not for production critical workloads
create_spot_node_pool = false

# Upgrade Settings
max_surge = "33%"

# Monitoring
enable_log_analytics = true
enable_azure_policy  = true

# Identity
identity_type = "SystemAssigned"

# Auto-scaler Configuration
configure_auto_scaler_profile = true
auto_scaler_profile = {
  balance_similar_node_groups      = true
  max_graceful_termination_sec     = 600
  scale_down_delay_after_add       = "10m"
  scale_down_unneeded              = "10m"
  scale_down_utilization_threshold = 0.5
}

# Tags
tags = {
  Environment = "Production"
  CostCenter  = "Operations"
  ManagedBy   = "Terraform"
  NetworkType = "Azure CNI"
  SLA         = "99.95%"
}
