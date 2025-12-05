# Troubleshooting: wiz-kubernetes-connector-create-connector Job Failure

## Error
```
Helm upgrade failed: pre-upgrade hooks failed: job wiz-kubernetes-connector-create-connector failed: BackoffLimitExceeded
Health check failed: stalled resources
```

## Root Cause Analysis

The connector job has `backoffLimit: 1`, meaning it fails after just 1 retry. Common causes:

### 1. Image Pull Failure (Most Likely)
The job cannot pull the Wiz connector image from the registry.

### 2. Invalid API Credentials
The wiz-api-token secret has incorrect clientId or clientToken.

### 3. Network Connectivity
Cannot reach Wiz API endpoints.

### 4. Missing Proxy Secret
If httpProxyConfiguration is referenced but secret doesn't exist.

## Diagnostic Commands

Run these from a machine with AKS cluster access:

### Step 1: Check the Job Status
```bash
kubectl get jobs -n wiz
kubectl describe job wiz-kubernetes-connector-create-connector -n wiz
```

### Step 2: Get Pod Logs
```bash
# Find the pod
kubectl get pods -n wiz | grep create-connector

# Get logs (use --previous if pod is in Error/CrashLoopBackOff)
kubectl logs -n wiz <pod-name>
kubectl logs -n wiz <pod-name> --previous
```

### Step 3: Check Image Pull Issues
```bash
# Describe the pod to see events
kubectl describe pod -n wiz <pod-name>

# Look for ImagePullBackOff or ErrImagePull events
kubectl get events -n wiz --sort-by='.lastTimestamp' | grep create-connector
```

### Step 4: Verify Secrets

**Check wiz-api-token:**
```bash
# Verify it exists
kubectl get secret wiz-api-token -n wiz

# Check it has the right keys (clientId and clientToken)
kubectl get secret wiz-api-token -n wiz -o jsonpath='{.data}' | jq 'keys'

# Decode and verify (be careful with sensitive data)
kubectl get secret wiz-api-token -n wiz -o jsonpath='{.data.clientId}' | base64 -d
```

**Check ACR credentials:**
```bash
kubectl get secret acr-credentials -n wiz

# Verify it's a docker-registry type secret
kubectl get secret acr-credentials -n wiz -o yaml
```

### Step 5: Check Job Template
```bash
# Get the full job spec to see what image it's trying to pull
kubectl get job wiz-kubernetes-connector-create-connector -n wiz -o yaml

# Look for:
# - image: (check the registry and image name)
# - imagePullSecrets: (should reference acr-credentials)
# - env: (check for API endpoint configuration)
```

## Common Fixes

### Fix 1: Image Pull from ACR (Most Common)

The connector job pod needs to pull the Wiz connector image. Check if the job spec includes imagePullSecrets:

```bash
kubectl get job wiz-kubernetes-connector-create-connector -n wiz -o yaml | grep -A10 imagePullSecrets
```

If imagePullSecrets is missing or incorrect, the global.imagePullSecrets in the HelmRelease might not be applying to the job. The job template needs to be updated in the chart.

### Fix 2: Verify wiz-api-token Secret Format

The secret must have these exact keys:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: wiz-api-token
  namespace: wiz
type: Opaque
stringData:
  clientId: "your-client-id"
  clientToken: "your-client-token"
```

NOT `clientID` or `client_id` - it must be exactly `clientId` and `clientToken`.

### Fix 3: Check Network Policies

If you have network policies, ensure the connector job can reach:
- Wiz API endpoints (typically *.wiz.io or *.us20.app.wiz.io)
- DNS resolution
- Internet egress (unless using private endpoints)

```bash
# Check network policies
kubectl get networkpolicies -n wiz
```

### Fix 4: Delete Failed Job and Retry

Sometimes cleaning up helps:
```bash
# Delete the failed job
kubectl delete job wiz-kubernetes-connector-create-connector -n wiz

# Force Flux to reconcile
kubectl annotate helmrelease wiz-integration -n wiz reconcile.fluxcd.io/requestedAt="$(date +%s)"
```

## Check Connector Configuration

Review the autoCreateConnector settings:

```bash
# Get current HelmRelease values
kubectl get helmrelease wiz-integration -n wiz -o yaml
```

Verify:
- `autoCreateConnector.clusterFlavor: AKS`
- `wizApiToken.secret.name: wiz-api-token`
- `global.imagePullSecrets` includes acr-credentials

## Alternative: Disable Auto-Create Connector Temporarily

If the job keeps failing, you can disable autoCreateConnector temporarily to install other components:

In wiz-helmrelease.yaml, add under wiz-kubernetes-connector:
```yaml
wiz-kubernetes-connector:
  enabled: true
  autoCreateConnector:
    enabled: false  # Disable auto-creation temporarily
    clusterFlavor: AKS
```

This allows the rest of the deployment to proceed. You can manually create the connector later via the Wiz portal.

## Next Steps

1. Get the pod logs - this will tell you the exact failure reason
2. Check for ImagePullBackOff - indicates ACR secret issue
3. Check for authentication errors in logs - indicates wiz-api-token issue
4. Share the pod logs for further diagnosis

## Example Debug Output

When you run the commands, look for:

**Successful image pull:**
```
Normal  Pulling    10s   kubelet  Pulling image "wizcr.azurecr.io/wiz-kubernetes-connector:..."
Normal  Pulled     8s    kubelet  Successfully pulled image
```

**Failed image pull:**
```
Warning  Failed     2m    kubelet  Failed to pull image "wizcr.azurecr.io/...": rpc error: code = Unknown desc = failed to pull and unpack image...
Warning  Failed     2m    kubelet  Error: ImagePullBackOff
```

**Authentication error in logs:**
```
ERROR: Failed to authenticate with Wiz API
ERROR: Invalid client credentials
```

**Network error in logs:**
```
ERROR: Failed to connect to api.wiz.io
ERROR: dial tcp: lookup api.wiz.io: no such host
```
