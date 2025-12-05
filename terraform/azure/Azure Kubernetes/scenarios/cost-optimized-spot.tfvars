# Cost-Optimized Environment with Spot Instances
# Maximum cost savings with spot instances for non-critical workloads

# Required Variables
resource_group_name = "rg-aks-cost-optimized"
cluster_name        = "aks-cost-spot"
dns_prefix          = "aks-cost"

# Azure Region
location = "East US"

# Kubernetes Version
kubernetes_version = "1.28"

# Cluster Configuration
sku_tier                = "Free"
private_cluster_enabled = false

# Network Configuration - Kubenet for IP efficiency
network_plugin = "kubenet"
network_policy = "calico"
network_mode   = "transparent"

# Pod CIDR
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

# System Node Pool - Minimum for system components (must be Regular)
system_node_count = 1
system_node_size  = "Standard_B2s"
os_disk_size_gb   = 30

# Auto-scaling
enable_auto_scaling = true
min_node_count      = 1
max_node_count      = 3

# Availability Zones - Not used to reduce costs
availability_zones = []

# Security
enable_host_encryption = false
enable_node_public_ip  = false

# User Node Pool - Not creating separate user pool
create_user_node_pool = false

# Spot Instance Node Pool - Primary workload pool
create_spot_node_pool = true
spot_node_count       = 3
spot_node_size        = "Standard_D2s_v3"
spot_min_node_count   = 0
spot_max_node_count   = 20

# Spot Instance Configuration
spot_eviction_policy = "Delete"
spot_max_price       = -1  # Pay up to on-demand price

# Upgrade Settings
max_surge = "1"

# Monitoring - Minimal for cost savings
enable_log_analytics = false
enable_azure_policy  = false

# Identity
identity_type = "SystemAssigned"

# Auto-scaler Configuration - Aggressive scaling down
configure_auto_scaler_profile = true
auto_scaler_profile = {
  balance_similar_node_groups      = false
  max_graceful_termination_sec     = 300
  scale_down_delay_after_add       = "5m"
  scale_down_unneeded              = "5m"
  scale_down_utilization_threshold = 0.3
}

# Tags
tags = {
  Environment = "Development"
  CostCenter  = "Engineering"
  ManagedBy   = "Terraform"
  NodeType    = "Spot"
  Purpose     = "Cost Optimization"
}
