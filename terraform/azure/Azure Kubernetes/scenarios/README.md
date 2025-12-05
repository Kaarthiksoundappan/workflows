# AKS Terraform Configuration Scenarios

This folder contains example `.tfvars` files for different AKS deployment scenarios. Each file demonstrates how to configure the Terraform scripts for specific use cases.

## How to Use These Examples

1. Copy the scenario file that best matches your needs
2. Rename it to `terraform.tfvars`
3. Customize the values for your environment
4. Run `terraform plan` to preview changes
5. Run `terraform apply` to create the cluster

## Available Scenarios

### 1. Development with Kubenet ([dev-kubenet.tfvars](dev-kubenet.tfvars))

**Best for:** Development and testing environments

**Key Features:**
- Kubenet networking (most IP-efficient)
- Small node sizes (B2s)
- No auto-scaling
- No availability zones
- Monitoring disabled
- Free SKU tier

**Cost:** Lowest (~$70-100/month)

**When to use:**
- Early development
- Learning Kubernetes
- Temporary test clusters
- Budget-constrained projects

---

### 2. Production with Azure CNI ([prod-azure-cni.tfvars](prod-azure-cni.tfvars))

**Best for:** Production workloads requiring advanced networking

**Key Features:**
- Azure CNI (full Azure network integration)
- D4s_v3 nodes across 3 availability zones
- Auto-scaling enabled
- Host encryption enabled
- Log Analytics and Azure Policy enabled
- Standard SKU tier (99.95% SLA)

**Cost:** High (~$500-800/month base)

**When to use:**
- Production applications
- Integration with Azure services
- Network policies required
- High availability needed
- Compliance requirements

---

### 3. Cost-Optimized with Spot ([cost-optimized-spot.tfvars](cost-optimized-spot.tfvars))

**Best for:** Fault-tolerant workloads with tight budgets

**Key Features:**
- Kubenet networking
- Minimal system node pool (1x B2s)
- Dedicated spot instance pool
- Aggressive scale-down settings
- No monitoring or policy
- Free SKU tier

**Cost:** Very low (~$30-50/month)

**When to use:**
- Batch processing
- CI/CD workloads
- Machine learning training
- Development with production-like scale
- Non-critical applications

**Limitations:**
- Spot instances can be evicted
- Not suitable for production critical workloads
- No SLA guarantees

---

### 4. Large-Scale with Overlay ([large-scale-overlay.tfvars](large-scale-overlay.tfvars))

**Best for:** Large clusters with IP address constraints

**Key Features:**
- Azure CNI Overlay mode
- IP-efficient (pods use separate overlay network)
- Large scale (up to 50+ regular nodes, 100 spot nodes)
- D4s_v3 and D8s_v3 nodes
- Availability zones
- Standard SKU tier

**Cost:** Very high (~$1000+/month)

**When to use:**
- Large microservices architectures
- Multi-tenant platforms
- Limited IP address space
- Need Azure CNI features without IP exhaustion
- Scaling beyond 1000 pods

**Benefits:**
- Combines Azure CNI features with IP efficiency
- Can scale much larger than traditional Azure CNI
- Better than kubenet for Azure integration

---

### 5. Private Cluster ([private-cluster.tfvars](private-cluster.tfvars))

**Best for:** High-security environments

**Key Features:**
- Private API server endpoint
- User-defined routing (UDR) for outbound traffic
- No public IPs on nodes
- Host encryption enabled
- Azure Policy enabled
- Standard SKU tier

**Cost:** High (~$500-800/month)

**When to use:**
- Regulated industries (healthcare, finance)
- Compliance requirements (PCI-DSS, HIPAA)
- Internal corporate applications
- Defense-in-depth security

**Requirements:**
- VPN or ExpressRoute for cluster access
- Firewall or NVA for outbound routing
- Private DNS configuration
- Jump box or bastion host

---

## Comparison Matrix

| Scenario | Network | Zones | Spot | Private | Cost | Use Case |
|----------|---------|-------|------|---------|------|----------|
| Dev Kubenet | Kubenet | No | No | No | $ | Development |
| Prod Azure CNI | Azure CNI | Yes | No | No | $$$ | Production |
| Cost Optimized | Kubenet | No | Yes | No | $ | Batch/CI-CD |
| Large Scale | CNI Overlay | Yes | Yes | No | $$$$ | Large apps |
| Private | Azure CNI | Yes | No | Yes | $$$ | High security |

## Network Plugin Decision Guide

### Choose **Kubenet** when:
- IP addresses are not constrained
- Don't need pod-level network policies
- Development/test environment
- Cost is primary concern
- Simple networking requirements

### Choose **Azure CNI** when:
- Need pod-level Azure network integration
- Using Azure Network Policies
- Integration with Azure services
- Production environment
- Have sufficient IP addresses

### Choose **Azure CNI Overlay** when:
- Need Azure CNI features
- IP addresses are constrained
- Large cluster (>1000 pods)
- Want to avoid IP exhaustion
- Balance between efficiency and features

## Spot Instance Decision Guide

### Use Spot Instances for:
- Batch processing jobs
- CI/CD pipelines
- Machine learning training
- Development environments
- Stateless applications
- Workloads that can tolerate interruptions

### Avoid Spot Instances for:
- Production critical applications
- Databases
- Stateful applications
- Real-time processing
- Applications requiring guaranteed availability

## Customization Tips

1. **Node Sizes**: Adjust `system_node_size` and `user_node_size` based on workload requirements
2. **Auto-scaling Limits**: Modify `min_node_count` and `max_node_count` for your scale needs
3. **Availability Zones**: Set to `["1", "2", "3"]` for high availability or `[]` to reduce costs
4. **Monitoring**: Enable `enable_log_analytics = true` for production visibility
5. **Network CIDRs**: Ensure CIDRs don't overlap with your existing networks

## Migration Paths

### From Dev to Prod
1. Start with `dev-kubenet.tfvars`
2. Change network to Azure CNI
3. Enable availability zones
4. Enable monitoring and policy
5. Upgrade to Standard SKU

### From Single Pool to Multiple
1. Keep system node pool small
2. Add user node pool for applications
3. Optionally add spot pool for batch workloads

### From Public to Private
1. Ensure VPN/ExpressRoute is configured
2. Set `private_cluster_enabled = true`
3. Configure `outbound_type = "userDefinedRouting"`
4. Update firewall rules

## Additional Resources

- See [configuration-options.md](../configuration-options.md) for detailed explanations
- See [execution-guide.md](../execution-guide.md) for deployment instructions
- See [readme.md](../readme.md) for conceptual understanding
