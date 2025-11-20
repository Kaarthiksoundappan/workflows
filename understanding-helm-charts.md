# Understanding Helm Charts - A Beginner's Guide

## What is Helm?

Think of **Helm** as an "app store" for Kubernetes. Just like you install apps on your phone with one click, Helm lets you install complex applications on Kubernetes clusters with simple commands.

### Simple Analogy

Imagine you want to build a LEGO house:
- **Without Helm**: You need to find each LEGO brick individually, read complex instructions, and assemble everything piece by piece
- **With Helm**: You get a pre-packaged LEGO kit with all bricks organized, clear instructions, and you can build it quickly

**Helm Chart** = The LEGO kit (pre-packaged application with all components and instructions)

## What is a Helm Chart?

A **Helm Chart** is a package that contains:
1. All the files needed to run an application on Kubernetes
2. Configuration templates
3. Default settings (that you can customize)
4. Instructions on how to deploy everything

### Real-World Example

Let's say you want to run WordPress (a website platform) on Kubernetes:

**Without Helm Chart**:
- Create a database (MySQL)
- Configure database credentials
- Create WordPress application
- Set up storage for files
- Create network rules
- Configure load balancer
- Write 10+ YAML files
- Deploy everything in correct order

**With Helm Chart**:
```bash
helm install my-wordpress wordpress
```
Done! Everything is installed and configured.

## Helm Chart Structure

Every Helm chart follows a standard folder structure:

```
my-application/
│
├── Chart.yaml              # Information about the chart
├── values.yaml             # Default configuration settings
├── charts/                 # Dependencies (other charts this needs)
├── templates/              # Kubernetes resource templates
│   ├── deployment.yaml     # How to run the application
│   ├── service.yaml        # How to expose the application
│   ├── configmap.yaml      # Configuration data
│   ├── secret.yaml         # Sensitive data (passwords, tokens)
│   ├── serviceaccount.yaml # Security permissions
│   └── NOTES.txt           # Instructions shown after installation
│
└── README.md               # Documentation
```

### Let's Break Down Each File

#### 1. Chart.yaml
The "label" on the package telling you what's inside.

```yaml
name: wordpress           # Chart name
version: 1.0.0           # Chart version
appVersion: 6.4.2        # Application version
description: WordPress website platform
keywords:
  - wordpress
  - cms
  - blog
```

#### 2. values.yaml
The "settings menu" where you can customize the application.

```yaml
# Default settings (you can override these)
replicaCount: 3          # How many copies to run

image:
  repository: wordpress  # Which container image to use
  tag: latest           # Which version

service:
  type: LoadBalancer    # How to expose the app
  port: 80             # Which port to use

resources:
  memory: "512Mi"       # How much RAM
  cpu: "500m"          # How much CPU
```

#### 3. templates/ folder
The "blueprints" for creating Kubernetes resources. This is where the magic happens!

## How to Identify: Deployment vs StatefulSet vs DaemonSet

Inside the `templates/` folder, look for these files:

### 1. Deployment (deployment.yaml)

**What it is**: Runs multiple copies of your application for reliability and load balancing.

**When to use**:
- Web applications (websites, APIs)
- Stateless applications (don't need to remember data between restarts)
- Microservices
- Applications that can scale horizontally

**How to identify**:
```yaml
# Look for this in templates/deployment.yaml
kind: Deployment

spec:
  replicas: 3    # "I want 3 copies running"
```

**Real-world examples**:
- WordPress website
- REST API backend
- NGINX web server
- Node.js application
- React/Angular frontend
- E-commerce website

**Visual representation**:
```
LoadBalancer
     |
     v
[Pod 1] [Pod 2] [Pod 3]  <- All identical, any can handle requests
  Node A   Node B   Node C
```

### 2. StatefulSet (statefulset.yaml)

**What it is**: Runs applications that need stable identity and persistent storage.

**When to use**:
- Databases
- Applications that store data
- Applications that need stable network names
- Applications that care about order (must start/stop in sequence)

**How to identify**:
```yaml
# Look for this in templates/statefulset.yaml
kind: StatefulSet

spec:
  serviceName: "mysql"    # Stable network name
  replicas: 3

  volumeClaimTemplates:   # Each pod gets its own storage
    - metadata:
        name: data
```

**Real-world examples**:
- MySQL, PostgreSQL (databases)
- MongoDB, Cassandra (NoSQL databases)
- Kafka (message queue)
- Elasticsearch (search engine)
- Redis cluster (caching)
- Zookeeper (coordination service)

**Visual representation**:
```
mysql-0 (Leader)     <- Specific identity, own storage
   |
mysql-1 (Follower)   <- Specific identity, own storage
   |
mysql-2 (Follower)   <- Specific identity, own storage

Each has:
- Stable name (mysql-0, mysql-1, mysql-2)
- Own persistent disk
- Ordered startup/shutdown
```

### 3. DaemonSet (daemonset.yaml)

**What it is**: Runs exactly one copy of your application on **every node** in the cluster.

**When to use**:
- Monitoring agents (need to monitor each server)
- Log collectors (need to collect logs from each server)
- Security scanners (need to scan each server)
- Network plugins (need to run on each server)

**How to identify**:
```yaml
# Look for this in templates/daemonset.yaml
kind: DaemonSet

spec:
  # No replica count - automatically runs on ALL nodes
```

**Real-world examples**:
- Wiz sensor (security scanning)
- Datadog agent (monitoring)
- Fluentd (log collection)
- Prometheus Node Exporter (metrics)
- Antivirus scanners
- Network policy agents
- Storage drivers

**Visual representation**:
```
Kubernetes Cluster (5 nodes)

Node 1: [Monitoring Pod]
Node 2: [Monitoring Pod]
Node 3: [Monitoring Pod]
Node 4: [Monitoring Pod]
Node 5: [Monitoring Pod]

^ One pod per node, automatically
If you add Node 6, it automatically gets a pod too!
```

### 4. Job (job.yaml)

**What it is**: Runs a task once and then completes.

**When to use**:
- Data migration
- Batch processing
- Database backups
- One-time scripts

**How to identify**:
```yaml
kind: Job

spec:
  completions: 1    # Run until completion
  backoffLimit: 3   # Retry 3 times if fails
```

**Real-world examples**:
- Database migration scripts
- Data import/export
- Image processing batch jobs
- Report generation

### 5. CronJob (cronjob.yaml)

**What it is**: Runs a task on a schedule (like cron in Linux).

**When to use**:
- Scheduled backups
- Regular cleanup tasks
- Periodic reports
- Scheduled data synchronization

**How to identify**:
```yaml
kind: CronJob

spec:
  schedule: "0 2 * * *"    # Run at 2 AM every day
```

**Real-world examples**:
- Daily database backups (2 AM every day)
- Weekly report generation (Sundays)
- Hourly data sync
- Monthly cleanup jobs

## How to Inspect a Helm Chart

### Method 1: View Chart Information
```bash
# See what the chart does
helm show chart oci://azcontainerregistry.azurecr.io/helm/wizsensor
```

### Method 2: View Default Values
```bash
# See all configuration options
helm show values oci://azcontainerregistry.azurecr.io/helm/wizsensor
```

### Method 3: Download and Explore
```bash
# Download the chart to your computer
helm pull oci://azcontainerregistry.azurecr.io/helm/wizsensor --untar

# Go into the folder
cd wizsensor

# Look at the structure
ls -la

# Check what Kubernetes resources it creates
cd templates
ls -la

# You'll see files like:
# - daemonset.yaml   (creates DaemonSet)
# - deployment.yaml  (creates Deployment)
# - service.yaml     (creates Service)
# etc.
```

### Method 4: Dry Run (Preview Before Installing)
```bash
# See what would be created WITHOUT actually creating it
helm install my-app oci://registry/chart --dry-run --debug
```

This shows you exactly what Kubernetes resources will be created!

## Where Can Helm Charts Be Used?

### 1. Application Deployment

**Scenario**: You want to deploy a complete application stack.

**Example**: E-commerce website
```bash
# One command installs:
# - Frontend (React app)
# - Backend API (Node.js)
# - Database (PostgreSQL)
# - Cache (Redis)
# - Message queue (RabbitMQ)

helm install my-store bitnami/magento
```

### 2. Development Environments

**Scenario**: Each developer needs identical development environment.

**Example**: Developer wants to test locally
```bash
# Install development stack
helm install dev-env ./my-dev-chart

# Features:
# - Database with test data
# - Mock APIs
# - Debugging tools
# - Local storage
```

### 3. CI/CD Pipelines

**Scenario**: Automated deployments when code changes.

**Example**: GitHub Actions workflow
```yaml
- name: Deploy to Staging
  run: |
    helm upgrade --install myapp ./chart \
      --set image.tag=${{ github.sha }} \
      --namespace staging
```

### 4. Multi-Environment Deployments

**Scenario**: Deploy same app to dev, staging, production with different configs.

**Example**:
```bash
# Development (small resources)
helm install myapp ./chart -f values-dev.yaml

# Staging (medium resources)
helm install myapp ./chart -f values-staging.yaml

# Production (large resources, high availability)
helm install myapp ./chart -f values-prod.yaml
```

### 5. Microservices Architecture

**Scenario**: Deploy 20+ microservices that work together.

**Example**: Umbrella chart (chart of charts)
```
my-platform/
├── Chart.yaml
└── charts/
    ├── user-service/
    ├── payment-service/
    ├── notification-service/
    ├── inventory-service/
    └── order-service/
```

One command deploys all microservices!

### 6. Third-Party Software Installation

**Scenario**: Install popular open-source software.

**Examples**:

**Monitoring Stack**:
```bash
helm install prometheus prometheus-community/kube-prometheus-stack
# Installs: Prometheus, Grafana, AlertManager
```

**Database**:
```bash
helm install mysql bitnami/mysql
```

**Message Queue**:
```bash
helm install rabbitmq bitnami/rabbitmq
```

**Container Registry**:
```bash
helm install harbor harbor/harbor
```

### 7. Security and Compliance

**Scenario**: Deploy security tools across all clusters.

**Example**: Wiz sensor deployment (from your use case!)
```bash
# Deploy security scanner to all nodes
helm install wizsensor oci://azcontainerregistry.azurecr.io/helm/wizsensor
# Creates DaemonSet - one scanner per node
```

**Other examples**:
- Antivirus scanners
- Intrusion detection systems
- Compliance monitoring
- Vulnerability scanners

### 8. Backup and Disaster Recovery

**Scenario**: Regular automated backups.

**Example**: Velero (backup tool)
```bash
helm install velero vmware-tanzu/velero
# Creates CronJob for scheduled backups
```

### 9. Logging and Observability

**Scenario**: Collect logs from all applications and nodes.

**Example**: ELK Stack
```bash
helm install elastic elastic/elasticsearch
helm install kibana elastic/kibana
helm install filebeat elastic/filebeat
# Filebeat = DaemonSet (collects logs from every node)
```

### 10. GitOps Workflows

**Scenario**: Manage infrastructure as code in Git.

**Example**: Using Flux (like in your Wiz deployment!)
```bash
# Flux monitors Git repo and auto-deploys Helm charts
az k8s-configuration flux create \
  --cluster-name mycluster \
  --kind helmrelease \
  --helm-chart-name myapp
```

## Popular Helm Chart Repositories

### 1. Bitnami (Most Popular)
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami

# Available charts:
# - WordPress, Drupal, Joomla (CMS)
# - MySQL, PostgreSQL, MongoDB (Databases)
# - NGINX, Apache (Web servers)
# - Redis, Memcached (Caching)
# - Kafka, RabbitMQ (Message queues)
```

### 2. Official Kubernetes Charts
```bash
helm repo add stable https://charts.helm.sh/stable
```

### 3. Prometheus Community
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```

### 4. Elastic
```bash
helm repo add elastic https://helm.elastic.co
```

### 5. Private Registries
```bash
# Your company's private charts
helm repo add mycompany oci://azcontainerregistry.azurecr.io/helm
```

## Quick Reference: How to Identify Resource Types

### Open the Helm Chart Templates Folder

1. **Download the chart**:
   ```bash
   helm pull <chart-url> --untar
   cd <chart-name>/templates
   ```

2. **Look for these files**:

| File Name | Resource Type | Purpose | Examples |
|-----------|---------------|---------|----------|
| `deployment.yaml` | Deployment | Stateless apps, scalable | Web apps, APIs |
| `statefulset.yaml` | StatefulSet | Stateful apps, databases | MySQL, MongoDB |
| `daemonset.yaml` | DaemonSet | One per node | Monitoring, logging |
| `job.yaml` | Job | Run once tasks | Migrations, backups |
| `cronjob.yaml` | CronJob | Scheduled tasks | Daily backups |
| `service.yaml` | Service | Networking | Load balancer |
| `configmap.yaml` | ConfigMap | Configuration | App settings |
| `secret.yaml` | Secret | Sensitive data | Passwords, keys |
| `ingress.yaml` | Ingress | External access | HTTPS routing |
| `persistentvolumeclaim.yaml` | PVC | Storage | Database storage |

3. **Inside each file, look for**:
   ```yaml
   kind: <ResourceType>
   ```

## Practical Example: WordPress Helm Chart

Let's examine a real WordPress chart:

```
wordpress/
│
├── Chart.yaml
│   └── Describes: WordPress CMS, version 1.0.0
│
├── values.yaml
│   └── Settings: replica count, database password, domain name
│
└── templates/
    ├── deployment.yaml        # WordPress app (Deployment)
    │   └── kind: Deployment
    │   └── replicas: 3
    │   └── Why? Web app needs multiple instances
    │
    ├── statefulset.yaml       # MySQL database (StatefulSet)
    │   └── kind: StatefulSet
    │   └── replicas: 1
    │   └── Why? Database needs persistent storage
    │
    ├── service.yaml           # Load balancer
    │   └── kind: Service
    │   └── type: LoadBalancer
    │
    ├── configmap.yaml         # WordPress configuration
    │   └── kind: ConfigMap
    │   └── data: php settings, WordPress config
    │
    └── secret.yaml            # Passwords
        └── kind: Secret
        └── data: database password (encrypted)
```

### What Happens When You Install This Chart

```bash
helm install myblog wordpress
```

**Kubernetes creates**:
1. **3 WordPress pods** (Deployment) - handle web traffic
2. **1 MySQL pod** (StatefulSet) - stores blog data
3. **Load balancer** (Service) - distributes traffic
4. **Configuration** (ConfigMap) - WordPress settings
5. **Secrets** (Secret) - database credentials
6. **Persistent storage** (PVC) - database files

All with one command!

## Summary: The Big Picture

### Helm Chart = Complete Application Package

```
┌─────────────────────────────────────────┐
│         HELM CHART                      │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Configuration (values.yaml)    │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Templates (Kubernetes YAML)    │   │
│  │  - Deployment                   │   │
│  │  - Service                      │   │
│  │  - ConfigMap                    │   │
│  │  - Secret                       │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Dependencies (other charts)    │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
           |
           | helm install
           v
┌─────────────────────────────────────────┐
│      KUBERNETES CLUSTER                 │
│                                         │
│  [Pods] [Services] [Storage] [Config]  │
│                                         │
│        Running Application!             │
└─────────────────────────────────────────┘
```

## Key Takeaways

1. **Helm charts package entire applications** - not just one component
2. **Resource type is defined in the chart** - you can't change Deployment to DaemonSet without modifying the chart
3. **Look in templates/ folder** to see what Kubernetes resources will be created
4. **Different resource types serve different purposes**:
   - Deployment = Web apps, APIs (scalable, stateless)
   - StatefulSet = Databases (stable identity, persistent storage)
   - DaemonSet = Monitoring, logging (one per node)
   - Job/CronJob = Batch tasks, scheduled jobs
5. **Helm makes Kubernetes easier** - complex deployments become simple commands

## Additional Resources

- [Helm Official Documentation](https://helm.sh/docs/)
- [Artifact Hub](https://artifacthub.io/) - Search for Helm charts
- [Bitnami Charts](https://github.com/bitnami/charts) - Most popular charts
- [Helm Chart Template Guide](https://helm.sh/docs/chart_template_guide/)

---

**Remember**: Helm charts are like recipes. The recipe (chart) tells you what ingredients (resources) you need and how to combine them (templates) to make a dish (running application). You can adjust the recipe (values.yaml) to taste!
