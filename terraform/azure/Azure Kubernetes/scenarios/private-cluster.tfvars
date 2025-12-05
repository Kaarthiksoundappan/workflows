# Private Cluster Configuration
# Enhanced security with private API server endpoint

# Required Variables
resource_group_name = "rg-aks-private"
cluster_name        = "aks-private-secure"
dns_prefix          = "aks-private"

# Azure Region
location = "East US"

# Kubernetes Version
kubernetes_version = "1.28"

# Cluster Configuration - Private Cluster
sku_tier                = "Standard"
private_cluster_enabled = true

# Network Configuration - Azure CNI for private networking
network_plugin = "azure"
network_mode   = "transparent"
network_policy = "azure"

# VNet Configuration - Use existing VNet in private network scenario
# Set create_vnet = false and provide existing_subnet_id if using existing network
create_vnet           = true
vnet_address_space    = "10.0.0.0/16"
subnet_address_prefix = "10.0.1.0/24"

# Service Network
service_cidr   = "10.1.0.0/16"
dns_service_ip = "10.1.0.10"

# Load Balancer and Outbound
load_balancer_sku = "standard"
outbound_type     = "userDefinedRouting"  # Route through firewall/NVA

# System Node Pool
system_node_count = 3
system_node_size  = "Standard_D4s_v3"
os_disk_size_gb   = 100

# Auto-scaling
enable_auto_scaling = true
min_node_count      = 3
max_node_count      = 10

# Availability Zones
availability_zones = ["1", "2", "3"]

# Security - Enhanced
enable_host_encryption = true
enable_node_public_ip  = false  # No public IPs on nodes

# User Node Pool
create_user_node_pool   = true
user_node_count         = 3
user_node_size          = "Standard_D4s_v3"
user_node_pool_priority = "Regular"

# Spot Instances - Not recommended for private/secure clusters
create_spot_node_pool = false

# Upgrade Settings
max_surge = "1"

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
  CostCenter  = "Security"
  ManagedBy   = "Terraform"
  NetworkType = "Private Cluster"
  Compliance  = "High Security"
}
