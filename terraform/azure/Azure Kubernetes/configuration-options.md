# AKS Configuration Options and Terraform Flexibility

This document explains the various configuration choices available when creating an Azure Kubernetes Service (AKS) cluster and how the Terraform scripts can be adapted to support different scenarios.

## Current Script Limitations

The basic Terraform script provided has these hardcoded choices:
- **Network Plugin**: Azure CNI (hardcoded)
- **Network Policy**: Azure Network Policy (hardcoded)
- **Identity Type**: System-assigned managed identity only
- **Node Pool Type**: Regular (on-demand) VMs only
- **Load Balancer**: Standard SKU (hardcoded)

## Major Configuration Choices in AKS

### 1. Network Configuration Options

#### Network Plugin (CNI)

**Kubenet (Basic Networking)**
- Nodes get IPs from the VNet subnet
- Pods get IPs from a separate CIDR (internal)
- Uses route tables and user-defined routes
- More IP-efficient but limited features
- Best for: Small clusters, development environments

**Azure CNI (Advanced Networking)**
- Both nodes and pods get IPs from the VNet subnet
- Full integration with Azure networking
- Requires more IP addresses
- Supports network policies and advanced features
- Best for: Production environments, integration with Azure services

**Azure CNI Overlay**
- Nodes get IPs from VNet subnet
- Pods get IPs from an overlay network (separate CIDR)
- More IP-efficient than standard Azure CNI
- Supports most Azure CNI features
- Best for: Large clusters with IP constraints

**Azure CNI Powered by Cilium**
- Enhanced version with Cilium dataplane
- Advanced network policies and observability
- eBPF-based networking
- Best for: Advanced networking requirements, service mesh

#### Current Script Support
The current script **only supports Azure CNI** (line 76 in main.tf is hardcoded).

#### How to Make It Flexible
Add a variable for network plugin choice and use conditional logic in the network_profile block.

---

### 2. Node Pool Types

#### Regular (On-Demand) Instances
- Standard Azure VMs
- Guaranteed availability
- Pay standard rates
- Best for: System node pools, production workloads

#### Spot Instances
- Use Azure's excess capacity
- Up to 90% cost savings
- Can be evicted when Azure needs capacity
- Best for: Batch processing, fault-tolerant workloads, dev/test

#### Current Script Support
The current script **only supports regular instances**. There's no `priority` or `eviction_policy` configuration.

#### How to Make It Flexible
Add spot instance support variables for node pools.

---

### 3. Identity Options

#### System-Assigned Managed Identity
- Created and managed by Azure
- Lifecycle tied to the cluster
- Simpler setup
- Current script uses this (line 71-73)

#### User-Assigned Managed Identity
- Pre-created identity
- Can be shared across resources
- More control over permissions
- Survives cluster deletion

#### Service Principal (Legacy)
- Requires manual secret management
- Less secure
- Not recommended for new clusters

#### Current Script Support
Only **System-Assigned Managed Identity**.

---

### 4. Availability Zones

- Distributes nodes across multiple Azure availability zones
- Provides higher availability
- Protects against datacenter failures
- Not all regions support availability zones

#### Current Script Support
**Not supported** - no availability zone configuration.

#### How to Make It Flexible
Add `zones` parameter to node pools.

---

### 5. Node Pool Operating Systems

#### Linux
- Default option
- Supports most Kubernetes workloads
- Lighter weight

#### Windows
- Required for Windows container workloads
- Requires a Linux system node pool
- Higher resource requirements

#### Current Script Support
**Linux only** - no Windows node pool option.

---

### 6. Private vs Public Clusters

#### Public Cluster
- API server accessible from internet
- Default configuration
- Easier to manage

#### Private Cluster
- API server only accessible from private network
- Enhanced security
- Requires private DNS integration
- Current script creates public clusters

#### Current Script Support
**Public clusters only**.

#### How to Make It Flexible
Add `private_cluster_enabled` option.

---

### 7. Load Balancer Options

#### Standard Load Balancer
- Supports availability zones
- More features
- Required for production
- Current script uses this

#### Basic Load Balancer (Deprecated)
- Limited features
- Being phased out
- Not recommended

---

### 8. Outbound Connectivity

#### Load Balancer
- Uses load balancer for egress traffic
- Default option
- Azure provides public IPs

#### User-Defined Routing (UDR)
- Route egress through firewall/NVA
- More control over outbound traffic
- Required for private clusters

#### NAT Gateway
- Dedicated outbound connectivity
- Better for high-scale scenarios
- More predictable IPs

#### Current Script Support
**Load Balancer only** (default).

---

### 9. Additional Features Not in Current Script

- **Automatic Channel Upgrades**: Auto-upgrade Kubernetes versions
- **Node OS Automatic Upgrades**: Auto-patch node OS
- **Maintenance Windows**: Control when updates happen
- **HTTP Application Routing**: Simple ingress (not for production)
- **Azure Active Directory Integration**: RBAC with Azure AD
- **Azure Key Vault Provider**: Secrets from Key Vault
- **Workload Identity**: Pod-level Azure AD authentication
- **Confidential Computing**: Encrypted VM nodes
- **Multiple Node Pools with Different Configurations**: Mix of spot/regular, different sizes

---

## How Terraform Makes This Flexible

### 1. Variables for All Options
Define variables for each configuration choice, with sensible defaults.

### 2. Conditional Blocks
Use Terraform's `dynamic` blocks and conditionals to include/exclude configurations based on variables.

### 3. Validation
Use variable validation to ensure valid combinations.

### 4. Multiple tfvars Files
Create different `.tfvars` files for different scenarios:
- `dev.tfvars` - Development configuration (kubenet, smaller nodes)
- `prod.tfvars` - Production configuration (Azure CNI, availability zones)
- `spot.tfvars` - Cost-optimized with spot instances
- `private.tfvars` - Private cluster configuration

### 5. Modules
Break configurations into reusable modules for different patterns.

---

## Practical Example: How Current Script Limits You

### Scenario 1: You Want to Use Spot Instances
**Current Script**: Cannot do this without manual code changes to add `priority = "Spot"` and `eviction_policy = "Delete"` to node pool blocks.

**Flexible Script**: Set `use_spot_instances = true` in your tfvars file.

### Scenario 2: You Want to Use Kubenet Instead of Azure CNI
**Current Script**: Cannot do this without editing main.tf line 76 from `network_plugin = "azure"` to `network_plugin = "kubenet"` and removing subnet configuration.

**Flexible Script**: Set `network_plugin = "kubenet"` in your tfvars file.

### Scenario 3: You Want a Private Cluster
**Current Script**: Cannot do this without adding `private_cluster_enabled = true` to the cluster resource.

**Flexible Script**: Set `private_cluster_enabled = true` in your tfvars file.

---

## Making the Script More Flexible

To make the current Terraform script support all these options, we need to:

1. **Add more variables** for each configuration option
2. **Update main.tf** with conditional logic using `dynamic` blocks
3. **Add validation** to ensure compatible options are selected
4. **Create example tfvars files** for common scenarios
5. **Update documentation** to explain each option

---

## Decision Matrix for Your Use Case

| Requirement | Recommended Configuration |
|------------|--------------------------|
| Development/Testing | Kubenet, smaller VMs, no zones, spot instances OK |
| Production Standard | Azure CNI, Standard LB, availability zones, regular instances |
| Production High-Scale | Azure CNI Overlay, NAT Gateway, availability zones |
| Cost-Optimized | Kubenet or Azure CNI Overlay, spot instances for workloads |
| High Security | Private cluster, Azure CNI, user-defined routing |
| Hybrid Workloads | Azure CNI, Windows + Linux node pools |
| IP-Constrained | Azure CNI Overlay or Kubenet |

---

## Next Steps

I can enhance the Terraform scripts to support these options by:

1. Creating an enhanced `main.tf` with flexible network and node pool configurations
2. Adding comprehensive variables for all options
3. Creating scenario-based `.tfvars` example files
4. Adding a configuration decision guide

This will allow you to use the same Terraform code base but configure different cluster types by simply changing variable values.
