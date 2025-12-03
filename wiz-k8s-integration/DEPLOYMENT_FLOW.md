# Wiz Kubernetes Integration - Complete Deployment Flow Analysis

## Chart Structure

The wiz-kubernetes-integration umbrella chart contains 3 sub-charts:
1. **wiz-kubernetes-connector** (with nested wiz-broker chart)
2. **wiz-admission-controller**
3. **wiz-sensor**

---

## Deployment Flow Overview

```
Phase 1: Pre-Install Hooks (Weight -10 to -1)
    ↓
Phase 2: Pre-Install Hooks (Weight 0 - create-connector job)
    ↓
Phase 3: Main Resources (Deployments, DaemonSets)
    ↓
Phase 4: Post-Install Hooks (Webhooks, etc.)
```

---

## PHASE 1: Pre-Install Hooks (Secrets & ServiceAccounts)

These run BEFORE everything else, with weight `-1` or `-10` (lower numbers run first).

### Step 1.1: Create ServiceAccounts (Hook Weight: -1)

**Purpose**: ServiceAccounts needed by pre-install jobs

1. `wiz-auto-modify-connector` - Used by create/delete connector jobs
   - File: `charts/wiz-kubernetes-connector/templates/service-account-modify-connector.yaml`
   - Includes RBAC (Role + RoleBinding)
   - Permissions: manage secrets, configmaps in namespace

2. `wiz-cluster-reader` - Used by connector to read cluster resources
   - File: `charts/wiz-kubernetes-connector/templates/service-account-cluster-reader.yaml`
   - Includes ClusterRole with read-only access to all resources

3. `wiz-broker-service-account` - Used by broker deployment
   - File: `charts/wiz-kubernetes-connector/charts/wiz-broker/templates/serviceaccount.yaml`

### Step 1.2: Create Secrets (Hook Weight: -1)

**Purpose**: Secrets needed by the create-connector job and deployments

1. **wiz-api-token** (if global.wizApiToken.secret.create = true)
   - File: `templates/secrets-wiz-api-token.yaml`
   - Contains: clientId, clientToken
   - Used by: create-connector job to authenticate with Wiz API
   - **CRITICAL**: Must exist before create-connector job runs

2. **Proxy secrets** (if proxy configured)
   - Files: Multiple `secret-proxy.yaml` files
   - Contains: HTTP_PROXY, HTTPS_PROXY, NO_PROXY config

3. **wiz-broker secrets** (if broker enabled)
   - File: `charts/wiz-kubernetes-connector/charts/wiz-broker/templates/secrets.yaml`
   - Contains: Broker configuration

4. **Connector data secret placeholder** (if wizConnector.createSecret = true)
   - File: `charts/wiz-kubernetes-connector/templates/secret-connector.yaml`
   - Initial empty secret that will be populated by create-connector job
   - Name: Usually `wiz-broker-secret`

### Step 1.3: GKE AllowList Synchronizer (Hook Weight: -10, GKE only)
   - File: `charts/wiz-sensor/templates/gkeallowlistsynchronizer.yaml`
   - Only runs on GKE clusters
   - Creates firewall rules for sensor

---

## PHASE 2: Pre-Install Job (Weight: 0, Default)

### Step 2.1: Create-Connector Job Runs

**File**: `charts/wiz-kubernetes-connector/templates/job-create-connector.yaml`

**Trigger**: `helm.sh/hook: pre-install,pre-upgrade`

**Conditions to Run**:
```yaml
if .Values.autoCreateConnector.enabled == true
```

**What This Job Does**:
1. Authenticates to Wiz API using `wiz-api-token` secret
2. Calls Wiz API to register the Kubernetes cluster
3. Receives connector configuration data from Wiz
4. **Creates/Updates the connector data secret** with:
   - Connector ID
   - Broker credentials
   - API endpoints
   - Cluster metadata

**Requirements**:
- `wiz-api-token` secret must exist with valid credentials
- `imagePullSecrets` configured (to pull job image from ACR)
- `wiz-auto-modify-connector` ServiceAccount must exist
- Network access to Wiz API

**Validation Check** (Lines 2-14 of job template):
```yaml
# If broker is DISABLED, apiServerEndpoint MUST be provided
if (!wiz-broker.enabled && apiServerEndpoint == "") {
  FAIL: "apiServerEndpoint must be specified for public clusters when Wiz Broker is disabled"
}
```

**Key Values**:
- `autoCreateConnector.enabled`: Must be `true`
- `autoCreateConnector.clusterFlavor`: "AKS", "EKS", "GKE", etc.
- `wiz-broker.enabled`: If `true`, uses broker for connectivity
- `autoCreateConnector.apiServerEndpoint`: Required if broker disabled

**Job Execution Flow**:
```
1. Pod starts with wiz-broker image
2. Runs command: [entrypoint] + [args for create]
3. Connects to Wiz API
4. Registers cluster
5. Receives connectorData
6. Updates secret: wiz-broker-secret
7. Job completes (Success)
```

**Failure Scenarios**:
- ❌ Invalid wiz-api-token credentials → Job fails, pods never deploy
- ❌ Can't pull job image from ACR → Job pending, pods never deploy
- ❌ Network timeout to Wiz API → Job fails, pods never deploy
- ❌ Broker disabled but no apiServerEndpoint → Template rendering fails

**Success Criteria**:
- ✅ Job status: Completed
- ✅ Secret `wiz-broker-secret` contains connectorData
- ✅ Helm proceeds to deploy main resources

**Critical Dependencies**:
- Blocks ALL main deployments until successful
- If this job fails, NO pods will be created
- Helm install/upgrade will fail with error

---

## PHASE 3: Main Resources Deployment

Once the create-connector job succeeds, Helm deploys these resources:

### Step 3.1: wiz-broker Deployment

**File**: `charts/wiz-kubernetes-connector/charts/wiz-broker/templates/wiz-broker-deployment.yaml`

**Condition**: `wiz-broker.enabled = true`

**What It Does**:
- Provides secure tunnel between cluster and Wiz backend
- Handles API communication for connector components
- Acts as proxy for Wiz API requests

**Requirements**:
- Reads connector data from secret created by create-connector job
- Secret name: `wiz-broker-secret` (or configured name)
- Key: `connectorData`

**Pod Configuration**:
- Replicas: 1
- Image: wiz-broker (from ACR, needs imagePullSecrets)
- ServiceAccount: wiz-broker-service-account
- Volumes: Mounts connector-data secret

**Critical Dependency**:
```yaml
volumes:
  - name: connector-data
    secret:
      secretName: wiz-broker-secret  # Created by create-connector job!
```

### Step 3.2: wiz-sensor DaemonSet

**File**: `charts/wiz-sensor/templates/daemonset.yaml`

**Condition**: `wiz-sensor.enabled = true`

**What It Does**:
- Runs on every node in the cluster
- Performs security scanning
- Collects runtime information
- Reports to Wiz backend via broker

**Requirements**:
- ServiceAccount: wiz-sensor (with ClusterRole for read access)
- ImagePullSecrets for ACR access
- Wiz API credentials

**Pod Configuration**:
- Runs as DaemonSet (one pod per node)
- Privileged security context (needs host access)
- Mounts: /var/run/docker.sock, /var/lib/containers, etc.

### Step 3.3: wiz-admission-controller Deployments

**Files**:
- `charts/wiz-admission-controller/templates/deploymentauditlogs.yaml`
- `charts/wiz-admission-controller/templates/deploymentenforcement.yaml`
- `charts/wiz-admission-controller/templates/deploymentsensor.yaml`

**Condition**: `wiz-admission-controller.enabled = true`

**What They Do**:

1. **Enforcement Deployment**:
   - Validates Kubernetes API requests (admission webhook)
   - Enforces security policies
   - Blocks non-compliant workloads

2. **Sensor Deployment**:
   - Scans container images before deployment
   - Image vulnerability assessment

3. **Audit Logs Deployment** (if kubernetesAuditLogsWebhook.enabled):
   - Collects Kubernetes audit logs
   - Sends to Wiz for analysis

**Requirements**:
- ServiceAccount: wiz-admission-controller
- Webhooks (ValidatingWebhookConfiguration, MutatingWebhookConfiguration)
- TLS certificates for webhooks

---

## PHASE 4: Post-Install Hooks

### Step 4.1: Admission Controller Webhooks

**File**: `charts/wiz-admission-controller/templates/opawebhook.yaml`

**Hook**: `helm.sh/hook: post-install, post-upgrade`

**What It Does**:
- Creates ValidatingWebhookConfiguration
- Creates MutatingWebhookConfiguration
- Registers webhooks with Kubernetes API server
- Directs admission requests to admission-controller service

**Requirements**:
- admission-controller service must be running
- TLS certificates configured
- Webhook endpoints accessible

---

## Complete Deployment Timeline

```
T=0s    START: Helm install begins
        ↓
T=1s    PHASE 1: Pre-Install Hooks (weight -10 to -1)
        - Create ServiceAccounts (wiz-auto-modify-connector, wiz-cluster-reader, wiz-broker-sa)
        - Create Secrets (wiz-api-token if configured, proxy secrets, placeholder connector secret)
        - Create RBAC (Roles, RoleBindings, ClusterRoles, ClusterRoleBindings)
        ↓
T=5s    PHASE 2: Pre-Install Job (weight 0)
        - create-connector Job starts
        - Pod pulls wiz-broker image from ACR (needs imagePullSecrets)
        - Pod runs connector creation logic
        - Connects to Wiz API with wiz-api-token
        - Registers cluster in Wiz
        - Receives connectorData from Wiz
        - Updates wiz-broker-secret with connectorData
        - Job completes successfully
        ↓
        ⏸️  CHECKPOINT: Job must complete before continuing
        ↓
T=30s   PHASE 3: Main Resources
        - wiz-broker Deployment starts (reads connector secret)
        - wiz-broker pod pulls image from ACR
        - wiz-broker pod starts, establishes connection to Wiz
        - wiz-sensor DaemonSet starts (one pod per node)
        - wiz-sensor pods pull images from ACR
        - wiz-admission-controller Deployments start
        - admission-controller pods pull images from ACR
        ↓
T=60s   PHASE 4: Post-Install Hooks
        - ValidatingWebhookConfiguration created
        - MutatingWebhookConfiguration created
        - Webhooks registered with K8s API
        ↓
T=90s   SUCCESS: All pods running
```

---

## Critical Secrets Summary

| Secret Name | Created By | Used By | Contains | Critical? |
|------------|------------|---------|----------|-----------|
| `wiz-api-token` | User/Pre-install hook | create-connector job | clientId, clientToken | ✅ YES |
| `aks-gitops-wiz` | User (ImagePullSecret) | All pods | ACR credentials | ✅ YES |
| `wiz-broker-secret` | create-connector job | wiz-broker deployment | connectorData | ✅ YES |
| Proxy secrets | Pre-install hook | All components | Proxy config | No |

---

## Failure Points & Troubleshooting

### 1. Create-Connector Job Fails

**Symptoms**:
- Job status: Failed or Error
- Helm install stuck or fails
- No pods created

**Common Causes**:

a) **Missing or Invalid wiz-api-token**
```bash
# Check secret exists
kubectl get secret wiz-api-token -n wiz-system

# Verify keys
kubectl get secret wiz-api-token -n wiz-system -o yaml
# Must have: clientId, clientToken (base64 encoded)
```

b) **ImagePullBackOff on Job Pod**
```bash
# Check job pods
kubectl get pods -n wiz-system -l job-name=wiz-kubernetes-connector-create-connector

# If ImagePullBackOff, check:
- aks-gitops-wiz secret exists
- Secret is type: kubernetes.io/dockerconfigjson
- Secret has ACR credentials
```

c) **Network Connectivity Issues**
```bash
# Check job logs
kubectl logs -n wiz-system job/wiz-kubernetes-connector-create-connector

# Look for:
- "connection timeout"
- "unable to reach"
- DNS resolution errors
```

d) **Validation Failure: Missing apiServerEndpoint**
```bash
# If broker disabled, must provide apiServerEndpoint
# Get your cluster endpoint:
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'

# Add to values:
wiz-kubernetes-connector:
  autoCreateConnector:
    apiServerEndpoint: "https://your-cluster-api-server:443"
```

### 2. Broker Deployment Fails

**Symptoms**:
- create-connector job succeeded
- wiz-broker pod in CrashLoopBackOff or Error

**Common Causes**:

a) **Missing Connector Data**
```bash
# Check if secret was updated by job
kubectl get secret wiz-broker-secret -n wiz-system -o yaml

# Should contain: connectorData key with base64 data
```

b) **ImagePullBackOff**
```bash
# Same as job - check imagePullSecrets
kubectl describe pod -n wiz-system -l app=wiz-broker
```

### 3. Sensor DaemonSet Pods Not Starting

**Symptoms**:
- Broker running fine
- Sensor pods pending or failing

**Common Causes**:

a) **Node Selector Issues**
```bash
# Check if node selectors match your nodes
kubectl describe ds wiz-sensor -n wiz-system
```

b) **Security Context Issues**
```bash
# Sensor needs privileged access
# Check PodSecurityPolicy or PodSecurityStandards
kubectl get psp
```

### 4. Admission Controller Not Working

**Symptoms**:
- Pods running
- But policies not enforced

**Common Causes**:

a) **Webhooks Not Registered**
```bash
# Check webhooks
kubectl get validatingwebhookconfiguration | grep wiz
kubectl get mutatingwebhookconfiguration | grep wiz
```

b) **Certificate Issues**
```bash
# Check admission controller logs
kubectl logs -n wiz-system -l app=wiz-admission-controller
```

---

## Key Configuration Values

### Required Values (Must Set):

```yaml
global:
  wizApiToken:
    secret:
      create: false              # Set true if secret doesn't exist
      name: wiz-api-token       # Name of secret with Wiz credentials
  imagePullSecrets:
    - name: aks-gitops-wiz     # ACR authentication secret

wiz-kubernetes-connector:
  enabled: true
  autoCreateConnector:
    clusterFlavor: AKS         # Important for cloud provider detection
  wiz-broker:                   # ← Lowercase 'w' is CRITICAL!
    enabled: true
```

### Optional Values:

```yaml
wiz-kubernetes-connector:
  autoCreateConnector:
    connectorName: "my-aks-cluster"    # Friendly name in Wiz
    apiServerEndpoint: ""              # Required only if broker disabled
    clusterTags:                       # Optional metadata
      environment: production
      team: platform
```

---

## Flux-Specific Considerations

### Why Manual Helm Works But Flux Doesn't

**Manual Helm Install**:
- Runs synchronously
- Waits for hooks to complete
- Real-time feedback
- Can retry immediately

**Flux HelmRelease**:
- Reconciles on interval (default: 10m)
- Asynchronous operation
- Retries based on remediation config
- Depends on Git sync

### Flux Troubleshooting Commands

```bash
# Check HelmRelease status
kubectl get helmrelease wiz-kubernetes-integration -n wiz-system

# Detailed status
kubectl describe helmrelease wiz-kubernetes-integration -n wiz-system

# Check HelmRelease conditions
kubectl get helmrelease wiz-kubernetes-integration -n wiz-system -o yaml | grep -A 20 "status:"

# Force reconciliation
flux reconcile helmrelease wiz-kubernetes-integration -n wiz-system

# Check Helm controller logs
kubectl logs -n flux-system deployment/helm-controller -f
```

### Flux Retry Configuration

In your HelmRelease:
```yaml
spec:
  install:
    remediation:
      retries: 3              # Retry 3 times on failure
  upgrade:
    remediation:
      retries: 3
```

---

## Summary: What Must Happen for Pods to Deploy

1. ✅ **wiz-api-token secret exists** with valid clientId and clientToken
2. ✅ **aks-gitops-wiz secret exists** with ACR credentials
3. ✅ **create-connector job successfully runs** and completes
4. ✅ **wiz-broker-secret is populated** with connectorData by the job
5. ✅ **Images can be pulled from ACR** using imagePullSecrets
6. ✅ **Network connectivity** to Wiz API endpoints
7. ✅ **Correct configuration** (wiz-broker lowercase, proper values)

If ANY of these fail, pods will not deploy!
