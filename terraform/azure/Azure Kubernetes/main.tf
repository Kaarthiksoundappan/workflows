terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "aks" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

resource "azurerm_virtual_network" "aks" {
  count               = var.create_vnet ? 1 : 0
  name                = "${var.cluster_name}-vnet"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  address_space       = [var.vnet_address_space]

  tags = var.tags
}

resource "azurerm_subnet" "aks" {
  count                = var.create_vnet ? 1 : 0
  name                 = "${var.cluster_name}-subnet"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks[0].name
  address_prefixes     = [var.subnet_address_prefix]
}

resource "azurerm_log_analytics_workspace" "aks" {
  count               = var.enable_log_analytics ? 1 : 0
  name                = "${var.cluster_name}-logs"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                    = var.cluster_name
  location                = azurerm_resource_group.aks.location
  resource_group_name     = azurerm_resource_group.aks.name
  dns_prefix              = var.dns_prefix
  kubernetes_version      = var.kubernetes_version
  private_cluster_enabled = var.private_cluster_enabled
  sku_tier                = var.sku_tier

  default_node_pool {
    name                   = "system"
    node_count             = var.enable_auto_scaling ? null : var.system_node_count
    vm_size                = var.system_node_size
    os_disk_size_gb        = var.os_disk_size_gb
    vnet_subnet_id         = var.create_vnet ? azurerm_subnet.aks[0].id : var.existing_subnet_id
    type                   = "VirtualMachineScaleSets"
    enable_auto_scaling    = var.enable_auto_scaling
    min_count              = var.enable_auto_scaling ? var.min_node_count : null
    max_count              = var.enable_auto_scaling ? var.max_node_count : null
    zones                  = var.availability_zones
    enable_host_encryption = var.enable_host_encryption
    enable_node_public_ip  = var.enable_node_public_ip

    upgrade_settings {
      max_surge = var.max_surge
    }

    tags = var.tags
  }

  identity {
    type         = var.identity_type
    identity_ids = var.identity_type == "UserAssigned" ? var.identity_ids : null
  }

  network_profile {
    network_plugin     = var.network_plugin
    network_mode       = var.network_plugin == "azure" && var.network_mode == "overlay" ? "overlay" : null
    network_policy     = var.network_policy
    load_balancer_sku  = var.load_balancer_sku
    outbound_type      = var.outbound_type
    service_cidr       = var.network_plugin != "none" ? var.service_cidr : null
    dns_service_ip     = var.network_plugin != "none" ? var.dns_service_ip : null
    pod_cidr           = var.network_plugin == "kubenet" || (var.network_plugin == "azure" && var.network_mode == "overlay") ? var.pod_cidr : null
  }

  dynamic "oms_agent" {
    for_each = var.enable_log_analytics ? [1] : []
    content {
      log_analytics_workspace_id = azurerm_log_analytics_workspace.aks[0].id
    }
  }

  azure_policy_enabled = var.enable_azure_policy

  dynamic "auto_scaler_profile" {
    for_each = var.enable_auto_scaling && var.configure_auto_scaler_profile ? [1] : []
    content {
      balance_similar_node_groups = var.auto_scaler_profile.balance_similar_node_groups
      max_graceful_termination_sec = var.auto_scaler_profile.max_graceful_termination_sec
      scale_down_delay_after_add   = var.auto_scaler_profile.scale_down_delay_after_add
      scale_down_unneeded          = var.auto_scaler_profile.scale_down_unneeded
      scale_down_utilization_threshold = var.auto_scaler_profile.scale_down_utilization_threshold
    }
  }

  tags = var.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count                  = var.create_user_node_pool ? 1 : 0
  name                   = "user"
  kubernetes_cluster_id  = azurerm_kubernetes_cluster.aks.id
  vm_size                = var.user_node_size
  node_count             = var.enable_auto_scaling ? null : var.user_node_count
  vnet_subnet_id         = var.create_vnet ? azurerm_subnet.aks[0].id : var.existing_subnet_id
  enable_auto_scaling    = var.enable_auto_scaling
  min_count              = var.enable_auto_scaling ? var.min_node_count : null
  max_count              = var.enable_auto_scaling ? var.max_node_count : null
  zones                  = var.availability_zones
  priority               = var.user_node_pool_priority
  eviction_policy        = var.user_node_pool_priority == "Spot" ? var.spot_eviction_policy : null
  spot_max_price         = var.user_node_pool_priority == "Spot" ? var.spot_max_price : null
  enable_host_encryption = var.enable_host_encryption
  enable_node_public_ip  = var.enable_node_public_ip
  os_disk_size_gb        = var.os_disk_size_gb

  upgrade_settings {
    max_surge = var.max_surge
  }

  tags = var.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  count                  = var.create_spot_node_pool ? 1 : 0
  name                   = "spot"
  kubernetes_cluster_id  = azurerm_kubernetes_cluster.aks.id
  vm_size                = var.spot_node_size
  node_count             = var.enable_auto_scaling ? null : var.spot_node_count
  vnet_subnet_id         = var.create_vnet ? azurerm_subnet.aks[0].id : var.existing_subnet_id
  enable_auto_scaling    = var.enable_auto_scaling
  min_count              = var.enable_auto_scaling ? var.spot_min_node_count : null
  max_count              = var.enable_auto_scaling ? var.spot_max_node_count : null
  zones                  = var.availability_zones
  priority               = "Spot"
  eviction_policy        = var.spot_eviction_policy
  spot_max_price         = var.spot_max_price
  enable_host_encryption = var.enable_host_encryption
  enable_node_public_ip  = var.enable_node_public_ip
  os_disk_size_gb        = var.os_disk_size_gb

  upgrade_settings {
    max_surge = var.max_surge
  }

  node_labels = {
    "kubernetes.azure.com/scalesetpriority" = "spot"
  }

  node_taints = [
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]

  tags = merge(var.tags, {
    NodeType = "Spot"
  })
}

resource "azurerm_role_assignment" "aks_network" {
  count                = var.create_vnet && var.identity_type == "SystemAssigned" ? 1 : 0
  scope                = azurerm_virtual_network.aks[0].id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}
