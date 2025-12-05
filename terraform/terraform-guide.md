# Terraform Guide

## What is Terraform?

Terraform is an open-source Infrastructure as Code (IaC) tool created by HashiCorp. It allows you to define, provision, and manage infrastructure resources across multiple cloud providers and services using a declarative configuration language called HashiCorp Configuration Language (HCL).

Key characteristics:
- **Declarative**: You describe the desired end state, and Terraform figures out how to achieve it
- **Cloud-agnostic**: Works with AWS, Azure, GCP, Kubernetes, and 100+ other providers
- **Version-controlled**: Infrastructure definitions can be stored in Git
- **Idempotent**: Running the same configuration multiple times produces the same result

## Current Version (2025)

**Latest Stable Release**: Terraform **1.14.1** (as of December 2025)
**Development Release**: Terraform 1.15.0-alpha available

To check your installed version:
```bash
terraform version
```

## How Terraform Works

Terraform follows a workflow with several key phases:

### 1. Write Configuration
Define infrastructure resources in `.tf` files using HCL syntax:
```hcl
resource "azurerm_resource_group" "example" {
  name     = "my-resource-group"
  location = "East US"
}
```

### 2. Initialize (`terraform init`)
- Downloads required provider plugins
- Initializes the backend for state storage
- Prepares the working directory

### 3. Plan (`terraform plan`)
- Compares desired state (configuration) with current state
- Creates an execution plan showing what will be created, modified, or destroyed
- No actual changes are made

### 4. Apply (`terraform apply`)
- Executes the plan to reach the desired state
- Creates, updates, or deletes resources as needed
- Updates the state file with current infrastructure

### 5. State Management
Terraform maintains a **state file** (`terraform.tfstate`) that:
- Tracks the current state of your infrastructure
- Maps configuration to real-world resources
- Stores metadata and resource dependencies

### Core Components

1. **Providers**: Plugins that interact with APIs (AWS, Azure, Kubernetes, etc.)
2. **Resources**: Infrastructure objects to manage (VMs, networks, storage, etc.)
3. **Modules**: Reusable Terraform configurations
4. **State**: Record of managed infrastructure
5. **Variables**: Parameterize configurations (including ephemeral variables for secrets)
6. **Outputs**: Extract information from resources
7. **Ephemeral Values**: Temporary values that exist only during planning/applying (v1.10+)

## Where Terraform Can Be Used

### Cloud Providers
- **AWS**: EC2, S3, RDS, Lambda, VPC, IAM, etc.
- **Azure**: Resource Groups, VMs, AKS, Storage Accounts, Virtual Networks
- **Google Cloud Platform**: Compute Engine, GKE, Cloud Storage, VPC
- **Oracle Cloud**: Compute, Networking, Database
- **Alibaba Cloud**: ECS, VPC, RDS

### Container Orchestration
- **Kubernetes**: Deployments, Services, ConfigMaps, Namespaces
- **Docker**: Containers, Images, Networks
- **Nomad**: Jobs, Job specifications
- **Amazon ECS/EKS**: Task definitions, Services, Clusters

### Platform as a Service
- **Heroku**: Apps, Add-ons, Domains
- **CloudFoundry**: Applications, Services
- **Azure App Service**: Web Apps, Function Apps

### SaaS & Tools
- **GitHub**: Repositories, Teams, Branch protection
- **Datadog**: Monitors, Dashboards, Alerts
- **PagerDuty**: Services, Escalation policies
- **Auth0**: Clients, APIs, Rules
- **Cloudflare**: DNS, Zones, Page rules

### Databases
- **MongoDB Atlas**: Clusters, Database users
- **PostgreSQL**: Databases, Roles, Extensions
- **MySQL**: Databases, Users, Grants
- **Azure SQL**: Databases, Firewall rules

### Networking
- **DNS**: Route53, Cloudflare DNS, Azure DNS
- **CDN**: CloudFront, Azure CDN
- **Load Balancers**: ALB, NLB, Azure Load Balancer

### Security & Identity
- **Vault**: Secrets, Policies, Auth backends
- **Active Directory**: Users, Groups
- **Okta**: Users, Groups, Applications

## Available Terraform Commands

### Essential Commands

#### `terraform init`
Initialize a Terraform working directory
```bash
terraform init
terraform init -upgrade  # Upgrade provider plugins
```

#### `terraform plan`
Create an execution plan showing proposed changes
```bash
terraform plan
terraform plan -out=planfile  # Save plan to file
terraform plan -var="region=us-west-2"  # Pass variables
```

#### `terraform apply`
Apply changes to reach desired state
```bash
terraform apply
terraform apply planfile  # Apply saved plan
terraform apply -auto-approve  # Skip confirmation
terraform apply -target=resource_type.name  # Apply specific resource
```

#### `terraform destroy`
Destroy all managed infrastructure
```bash
terraform destroy
terraform destroy -auto-approve
terraform destroy -target=resource_type.name  # Destroy specific resource
```

### State Management

#### `terraform state list`
List resources in state
```bash
terraform state list
```

#### `terraform state show`
Show details of a resource
```bash
terraform state show resource_type.name
```

#### `terraform state mv`
Move/rename resources in state
```bash
terraform state mv old_name new_name
```

#### `terraform state rm`
Remove resource from state (doesn't destroy actual resource)
```bash
terraform state rm resource_type.name
```

#### `terraform state pull`
Download and display remote state
```bash
terraform state pull
```

#### `terraform state push`
Upload local state to remote backend
```bash
terraform state push
```

### Workspace Management

#### `terraform workspace list`
List available workspaces
```bash
terraform workspace list
```

#### `terraform workspace new`
Create a new workspace
```bash
terraform workspace new dev
```

#### `terraform workspace select`
Switch to a different workspace
```bash
terraform workspace select prod
```

### Validation & Formatting

#### `terraform validate`
Validate configuration syntax
```bash
terraform validate
```

#### `terraform fmt`
Format configuration files to canonical style
```bash
terraform fmt
terraform fmt -recursive  # Format all files in subdirectories
```

### Information & Output

#### `terraform show`
Display current state or saved plan
```bash
terraform show
terraform show planfile
```

#### `terraform output`
Display output values
```bash
terraform output
terraform output resource_name
terraform output -json  # JSON format
```

#### `terraform graph`
Generate visual dependency graph
```bash
terraform graph | dot -Tpng > graph.png
```

#### `terraform version`
Show Terraform version
```bash
terraform version
```

### Import & Refresh

#### `terraform import`
Import existing infrastructure into state
```bash
terraform import resource_type.name resource_id
```

#### `terraform refresh`
Update state with real infrastructure (deprecated, use `terraform apply -refresh-only`)
```bash
terraform refresh
terraform apply -refresh-only
```

### Provider Management

#### `terraform providers`
Show provider requirements and versions
```bash
terraform providers
terraform providers lock  # Generate provider lock file
```

### Troubleshooting

#### `terraform console`
Interactive console for evaluating expressions
```bash
terraform console
```

#### `terraform taint`
Mark resource for recreation (deprecated, use `terraform apply -replace`)
```bash
terraform taint resource_type.name
terraform apply -replace="resource_type.name"  # Modern approach
```

#### `terraform untaint`
Remove taint from resource (deprecated)
```bash
terraform untaint resource_type.name
```

### Advanced Commands

#### `terraform force-unlock`
Manually unlock state if locked
```bash
terraform force-unlock LOCK_ID
```

#### `terraform login`
Save API token for Terraform Cloud
```bash
terraform login
```

#### `terraform logout`
Remove stored credentials
```bash
terraform logout
```

#### `terraform query`
Execute list operations against existing infrastructure (New in recent versions)
```bash
terraform query
```
This command allows you to query existing infrastructure and optionally generate configuration for importing results into Terraform.

## Common Command Flags

### Global Flags
- `-chdir=DIR`: Change working directory
- `-var="key=value"`: Set input variable
- `-var-file=FILE`: Load variables from file
- `-no-color`: Disable colored output
- `-json`: Output in JSON format

### Planning & Applying
- `-auto-approve`: Skip interactive approval
- `-lock=false`: Disable state locking
- `-parallelism=n`: Limit concurrent operations (default 10)
- `-refresh=false`: Skip refreshing state
- `-target=resource`: Operate on specific resource

## Latest Features in Terraform 1.9 - 1.14

### Terraform 1.9 (June 2024)

#### Enhanced Input Variable Validations
Previously, validation conditions could only reference the variable itself. Now conditions can reference:
- Other input variables
- Data sources
- Local values

```hcl
variable "instance_type" {
  type = string
  validation {
    condition     = var.instance_type != var.deprecated_type
    error_message = "Cannot use deprecated instance type."
  }
}
```

#### New `templatestring` Function
Render templates dynamically without saving to disk:
```hcl
locals {
  template = templatestring(
    data.external.template.result.content,
    { name = "example" }
  )
}
```

#### Cross-Type Refactoring
Refactor `null_resource` to `terraform_data` using moved blocks:
```hcl
moved {
  from = null_resource.example
  to   = terraform_data.example
}
```

#### Provisioners in `removed` Blocks
Execute destroy-time provisioners when removing resources:
```hcl
removed {
  from = aws_instance.example

  provisioner "local-exec" {
    when    = destroy
    command = "cleanup-script.sh"
  }
}
```

### Terraform 1.10 (2024) - Ephemeral Values

#### Major Security Improvement: Secrets Handling
**Problem**: Previously, secrets were stored in plaintext in state and plan files.

**Solution**: Ephemeral values exist only during planning/applying and are never persisted.

#### Ephemeral Input Variables
```hcl
variable "database_password" {
  type      = string
  ephemeral = true
}
```

#### Ephemeral Output Values
```hcl
output "temp_token" {
  value     = data.vault_token.example.token
  ephemeral = true
}
```

#### Ephemeral Resources
Temporarily reference external data without persisting:
```hcl
ephemeral "vault_secret" "example" {
  path = "secret/data/myapp"
}
```

#### New Functions for Ephemeral Values
- `ephemeralasnull()`: Convert ephemeral values to null in contexts requiring persistent values
- `terraform.applying`: Check if currently in apply phase

### Terraform 1.11 (2024)

#### Write-Only Arguments for Managed Resources
Ephemeral values can now be used with managed resources:
```hcl
resource "aws_db_instance" "example" {
  password = var.database_password  # ephemeral variable
}
```

The password is used to create/update the resource but never stored in state.

### Terraform 1.12-1.14

Additional improvements to stability, performance, and provider ecosystem support.

### Migration Notes

**Deprecated Commands** (use modern alternatives):
- `terraform taint` → `terraform apply -replace="resource_address"`
- `terraform untaint` → Remove manual taint markers (deprecated workflow)
- `terraform refresh` → `terraform apply -refresh-only` or `terraform plan -refresh-only`

## Best Practices

1. **Always run `terraform plan`** before `apply`
2. **Use remote state** (S3, Azure Storage, Terraform Cloud) for team collaboration
3. **Version control** your `.tf` files
4. **Use variables** for environment-specific values
5. **Never commit** `terraform.tfstate` or `.tfvars` files with secrets
6. **Use ephemeral values** for sensitive data like passwords and tokens (Terraform 1.10+)
7. **Use modules** for reusable components
8. **Implement state locking** to prevent concurrent modifications
9. **Tag resources** for organization and cost tracking
10. **Use workspaces** for environment separation
11. **Enable provider version constraints** in configuration
12. **Use `terraform apply -replace`** instead of deprecated `taint` command
13. **Implement enhanced variable validations** to catch errors early (Terraform 1.9+)

## Example Workflow

```bash
# 1. Initialize project
terraform init

# 2. Validate configuration
terraform validate

# 3. Format code
terraform fmt

# 4. Create execution plan
terraform plan -out=tfplan

# 5. Review plan output

# 6. Apply changes
terraform apply tfplan

# 7. View outputs
terraform output

# 8. When done, destroy resources
terraform destroy
```
