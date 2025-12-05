variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "system_node_count" {
  description = "Number of nodes in the system node pool"
  type        = number
  default     = 3
}

variable "system_node_size" {
  description = "VM size for system nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for node pools"
  type        = bool
  default     = true
}

variable "min_node_count" {
  description = "Minimum number of nodes when auto-scaling is enabled"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes when auto-scaling is enabled"
  type        = number
  default     = 5
}

variable "create_user_node_pool" {
  description = "Whether to create an additional user node pool"
  type        = bool
  default     = false
}

variable "user_node_count" {
  description = "Number of nodes in the user node pool"
  type        = number
  default     = 2
}

variable "user_node_size" {
  description = "VM size for user nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_address_prefix" {
  description = "Address prefix for the AKS subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services"
  type        = string
  default     = "10.1.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for Kubernetes DNS service"
  type        = string
  default     = "10.1.0.10"
}

variable "enable_log_analytics" {
  description = "Enable Log Analytics workspace and monitoring"
  type        = bool
  default     = true
}

variable "enable_azure_policy" {
  description = "Enable Azure Policy for AKS"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}

# Network Configuration Variables
variable "network_plugin" {
  description = "Network plugin to use (azure, kubenet, or none)"
  type        = string
  default     = "azure"
  validation {
    condition     = contains(["azure", "kubenet", "none"], var.network_plugin)
    error_message = "Network plugin must be 'azure', 'kubenet', or 'none'."
  }
}

variable "network_mode" {
  description = "Network mode for Azure CNI (transparent or overlay)"
  type        = string
  default     = "transparent"
  validation {
    condition     = contains(["transparent", "overlay"], var.network_mode)
    error_message = "Network mode must be 'transparent' or 'overlay'."
  }
}

variable "network_policy" {
  description = "Network policy to use (azure, calico, or cilium)"
  type        = string
  default     = "azure"
  validation {
    condition     = contains(["azure", "calico", "cilium", ""], var.network_policy)
    error_message = "Network policy must be 'azure', 'calico', 'cilium', or empty string."
  }
}

variable "pod_cidr" {
  description = "CIDR for pod IPs (required for kubenet or Azure CNI Overlay)"
  type        = string
  default     = "10.244.0.0/16"
}

variable "load_balancer_sku" {
  description = "SKU of the load balancer (standard or basic)"
  type        = string
  default     = "standard"
  validation {
    condition     = contains(["standard", "basic"], var.load_balancer_sku)
    error_message = "Load balancer SKU must be 'standard' or 'basic'."
  }
}

variable "outbound_type" {
  description = "Outbound routing method (loadBalancer, userDefinedRouting, managedNATGateway, or userAssignedNATGateway)"
  type        = string
  default     = "loadBalancer"
  validation {
    condition     = contains(["loadBalancer", "userDefinedRouting", "managedNATGateway", "userAssignedNATGateway"], var.outbound_type)
    error_message = "Outbound type must be one of: loadBalancer, userDefinedRouting, managedNATGateway, userAssignedNATGateway."
  }
}

# Virtual Network Variables
variable "create_vnet" {
  description = "Whether to create a new VNet or use an existing one"
  type        = bool
  default     = true
}

variable "existing_subnet_id" {
  description = "ID of existing subnet to use when create_vnet is false"
  type        = string
  default     = null
}

# Cluster Configuration Variables
variable "private_cluster_enabled" {
  description = "Enable private cluster (API server only accessible via private network)"
  type        = bool
  default     = false
}

variable "sku_tier" {
  description = "SKU tier for the cluster (Free, Standard, or Premium)"
  type        = string
  default     = "Free"
  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "SKU tier must be 'Free', 'Standard', or 'Premium'."
  }
}

variable "identity_type" {
  description = "Type of managed identity (SystemAssigned or UserAssigned)"
  type        = string
  default     = "SystemAssigned"
  validation {
    condition     = contains(["SystemAssigned", "UserAssigned"], var.identity_type)
    error_message = "Identity type must be 'SystemAssigned' or 'UserAssigned'."
  }
}

variable "identity_ids" {
  description = "List of user-assigned identity IDs (required when identity_type is UserAssigned)"
  type        = list(string)
  default     = []
}

# Node Pool Configuration Variables
variable "os_disk_size_gb" {
  description = "OS disk size in GB for nodes"
  type        = number
  default     = 30
}

variable "availability_zones" {
  description = "List of availability zones for node pools"
  type        = list(string)
  default     = []
}

variable "enable_host_encryption" {
  description = "Enable host-based encryption for nodes"
  type        = bool
  default     = false
}

variable "enable_node_public_ip" {
  description = "Enable public IP for nodes"
  type        = bool
  default     = false
}

variable "max_surge" {
  description = "Maximum number of nodes that can be added during an upgrade"
  type        = string
  default     = "1"
}

# User Node Pool Variables
variable "user_node_pool_priority" {
  description = "Priority for user node pool (Regular or Spot)"
  type        = string
  default     = "Regular"
  validation {
    condition     = contains(["Regular", "Spot"], var.user_node_pool_priority)
    error_message = "User node pool priority must be 'Regular' or 'Spot'."
  }
}

# Spot Node Pool Variables
variable "create_spot_node_pool" {
  description = "Whether to create a dedicated spot instance node pool"
  type        = bool
  default     = false
}

variable "spot_node_count" {
  description = "Number of nodes in the spot node pool"
  type        = number
  default     = 2
}

variable "spot_node_size" {
  description = "VM size for spot nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "spot_min_node_count" {
  description = "Minimum number of spot nodes when auto-scaling is enabled"
  type        = number
  default     = 0
}

variable "spot_max_node_count" {
  description = "Maximum number of spot nodes when auto-scaling is enabled"
  type        = number
  default     = 10
}

variable "spot_eviction_policy" {
  description = "Eviction policy for spot instances (Delete or Deallocate)"
  type        = string
  default     = "Delete"
  validation {
    condition     = contains(["Delete", "Deallocate"], var.spot_eviction_policy)
    error_message = "Spot eviction policy must be 'Delete' or 'Deallocate'."
  }
}

variable "spot_max_price" {
  description = "Maximum price for spot instances (-1 means pay up to on-demand price)"
  type        = number
  default     = -1
}

# Auto-scaler Profile Variables
variable "configure_auto_scaler_profile" {
  description = "Whether to configure advanced auto-scaler settings"
  type        = bool
  default     = false
}

variable "auto_scaler_profile" {
  description = "Auto-scaler profile configuration"
  type = object({
    balance_similar_node_groups      = optional(bool, false)
    max_graceful_termination_sec     = optional(number, 600)
    scale_down_delay_after_add       = optional(string, "10m")
    scale_down_unneeded              = optional(string, "10m")
    scale_down_utilization_threshold = optional(number, 0.5)
  })
  default = {
    balance_similar_node_groups      = false
    max_graceful_termination_sec     = 600
    scale_down_delay_after_add       = "10m"
    scale_down_unneeded              = "10m"
    scale_down_utilization_threshold = 0.5
  }
}
