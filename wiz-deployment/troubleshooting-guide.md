# Troubleshooting Guide

Common issues, solutions, and debug commands for Wiz Kubernetes Integration deployment.

**Related Guides:** [README](README.md) | [Workflow Guide](workflow-guide.md) | [Configuration](configuration-guide.md)

---

## Table of Contents

1. [Common Issues](#common-issues)
2. [Debug Commands](#debug-commands)
3. [Validation Steps](#validation-steps)
4. [Flux Troubleshooting](#flux-troubleshooting)
5. [Support Resources](#support-resources)

---

## Common Issues

### 1. Workflow Not Triggering on Push

**Symptoms:**
- Pushed changes to `Wiz` folder but workflow didn't run
- No GitHub Actions workflow execution in Actions tab

**Cause:** Path filter not matching folder names

**Solution:**

Check your folder naming - it's **case-sensitive**:

```yaml
# In .github/workflows/deploy-wiz.yml
paths:
  - '**/Wiz/**'  # Matches folders named "Wiz" (capital W)
```

✅ **Correct:** `Selling Data/Non Production/sellingdataaks/Wiz/`
❌ **Incorrect:** `Selling Data/Non Production/sellingdataaks/wiz/` (lowercase w)

**Verification:**
```bash
# Check recent workflow runs
gh run list --workflow=deploy-wiz.yml --limit 5

# Check if path matches
git ls-files | grep "/Wiz/"
```

---

### 2. Azure Login Failed

**Error Message:**
```
Error: Login failed with Error: clientId, clientSecret and tenantId must be provided.
```

**Cause:** Invalid or expired Azure Service Principal credentials

**Solution:**

1. **Regenerate Service Principal:**
```bash
az ad sp create-for-rbac \
  --name "github-aks-wiz-deploy" \
  --role "Contributor" \
  --scopes /subscriptions/<subscription-id> \
  --sdk-auth
```

2. **Update GitHub Secret:**
   - Go to **Repository → Settings → Secrets → Actions**
   - Update `AZURE_CREDENTIALS` with the new JSON output
   - Ensure JSON is valid (test with `jq` or JSON validator)

3. **Verify Format:**
```json
{
  "clientId": "...",
  "clientSecret": "...",
  "subscriptionId": "...",
  "tenantId": "..."
}
```

**Verification:**
```bash
# Test authentication locally
az login --service-principal \
  --username <clientId> \
  --password <clientSecret> \
  --tenant <tenantId>

# List accessible subscriptions
az account list
```

---

### 3. Wiz Secrets Not Found

**Error Message:**
```
Error: Wiz credentials not found for prefix: SELLINGDATA_NONPROD
Expected secrets:
  - SELLINGDATA_NONPROD_WIZ_CLIENT_ID
  - SELLINGDATA_NONPROD_WIZ_CLIENT_TOKEN
```

**Cause:** Missing or incorrectly named GitHub Secrets

**Solution:**

1. **Check Secret Names:**
   - Go to **Repository → Settings → Secrets → Actions**
   - Verify exact naming matches the error message
   - Check for typos or extra spaces

2. **Verify Naming Convention:**
   - Format: `{wiz_secret_prefix}_WIZ_CLIENT_ID` and `{wiz_secret_prefix}_WIZ_CLIENT_TOKEN`
   - Prefix comes from `clusters.json` → `wiz_secret_prefix` field
   - Example: If prefix is `SELLINGDATA_NONPROD`, secrets must be:
     - `SELLINGDATA_NONPROD_WIZ_CLIENT_ID`
     - `SELLINGDATA_NONPROD_WIZ_CLIENT_TOKEN`

3. **Add Missing Secrets:**
   - Get Wiz credentials from Wiz portal (Settings → Service Accounts)
   - Add to GitHub Secrets with correct naming

**Verification:**
```bash
# List all repository secrets (names only, not values)
gh secret list
```

---

### 4. Flux Configuration Failed

**Error Message:**
```
Error: The flux configuration 'wiz-integration' already exists
```

**Cause:** Flux configuration already exists from previous deployment

**Solution:**

The workflow automatically handles updates, but if it fails:

**Option 1: Let Workflow Update (Recommended)**
- Re-run the workflow - it should detect existing config and update it

**Option 2: Manual Deletion**
```bash
# Delete existing Flux configuration
az aks flux configuration delete \
  --resource-group <resource-group> \
  --cluster-name <cluster-name> \
  --cluster-type managedClusters \
  --name wiz-integration \
  --yes

# Re-run the workflow
```

**Option 3: Update Manually**
```bash
az aks flux configuration update \
  --resource-group <resource-group> \
  --cluster-name <cluster-name> \
  --cluster-type managedClusters \
  --name wiz-integration \
  --kustomization name=wiz path="./{Portfolio}/{Environment}/{Cluster}/Wiz" prune=true
```

---

### 5. HelmRelease Not Reconciling

**Symptoms:**
- Flux is running but Wiz pods not deploying
- HelmRelease stuck in "Reconciling" or "Failed" state

**Diagnosis:**

```bash
# Check HelmRelease status
kubectl get helmreleases -n wiz

# Get detailed status
kubectl describe helmrelease wiz-kubernetes-integration -n wiz

# Check Flux logs
flux logs --kind=HelmRelease --name=wiz-kubernetes-integration -n wiz
```

**Common Causes & Solutions:**

#### a) Missing ACR Secret

**Error in logs:**
```
Error: authentication required
```

**Solution:**
```bash
# Verify ACR secret exists
kubectl get secret acr-secret -n wiz

# If missing, re-run workflow with 'secrets-only' action

# Verify secret contains correct data
kubectl get secret acr-secret -n wiz -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq
```

#### b) Incorrect Helm Repository URL

**Error in logs:**
```
Error: repository not found
```

**Solution:**
Check [repo.yaml](configuration-guide.md#repoyaml):
- Verify ACR URL is correct
- Ensure `secretRef` points to existing secret
- For public repo, use `url: https://charts.wiz.io` without `secretRef`

#### c) Chart Version Not Found

**Error in logs:**
```
Error: chart version "X.X.X" not found
```

**Solution:**
```bash
# List available versions
helm search repo wiz-sec/wiz-kubernetes-integration --versions

# Update release.yaml with valid version
```

#### d) Invalid Wiz API Token

**Error in logs:**
```
Error: authentication failed
Error: invalid client credentials
```

**Solution:**
```bash
# Verify Wiz secret exists
kubectl get secret wiz-api-token -n wiz

# Check secret contains both keys
kubectl get secret wiz-api-token -n wiz -o jsonpath='{.data}' | jq

# Should show: clientId and clientToken

# Re-create secret with valid credentials
kubectl delete secret wiz-api-token -n wiz
# Re-run workflow with 'secrets-only' action
```

---

### 6. Pods CrashLoopBackOff

**Symptoms:**
- Wiz pods restarting repeatedly
- `kubectl get pods -n wiz` shows `CrashLoopBackOff`

**Diagnosis:**

```bash
# Check pod status
kubectl get pods -n wiz

# View pod logs
kubectl logs -n wiz <pod-name>

# Check pod events
kubectl describe pod -n wiz <pod-name>
```

**Common Causes:**

#### a) Image Pull Errors

**Error:**
```
Failed to pull image: authentication required
ErrImagePull / ImagePullBackOff
```

**Solution:**
```bash
# Verify image pull secrets
kubectl get secret acr-secret -n wiz

# Check pods are using the secret
kubectl get deployment wiz-sensor -n wiz -o yaml | grep imagePullSecrets

# Re-create ACR secret if needed
```

#### b) Invalid Wiz Credentials

**Error in logs:**
```
Failed to authenticate with Wiz API
```

**Solution:**
- Verify Wiz Client ID and Token are valid
- Check credentials haven't expired
- Re-create `wiz-api-token` secret with correct values

#### c) Network Connectivity Issues

**Error in logs:**
```
dial tcp: lookup api.wiz.io: no such host
connection refused
timeout
```

**Solution:**
```bash
# Test DNS resolution from pod
kubectl run -it --rm debug --image=busybox --restart=Never -n wiz -- nslookup api.wiz.io

# Test network connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n wiz -- curl -v https://api.wiz.io

# Check network policies
kubectl get networkpolicies -n wiz

# Verify firewall rules allow outbound to Wiz endpoints
```

---

### 7. Cluster Not Found in Matrix

**Symptoms:**
- Workflow runs but skips your cluster
- Matrix output shows empty or doesn't include expected cluster

**Cause:** Mismatch between folder structure and `clusters.json`

**Solution:**

1. **Check Folder Structure:**
```bash
# List your Wiz folders
find . -type d -name "Wiz" -not -path "./.git/*"
```

2. **Verify clusters.json:**
```bash
# Pretty-print clusters.json
cat config/clusters.json | jq .

# Check specific cluster exists
cat config/clusters.json | jq '.clusters[] | select(.cluster_name=="sellingdataaks")'
```

3. **Ensure Exact Match:**
   - **Portfolio** in `clusters.json` must match folder name exactly (case-sensitive)
   - **Environment** must match exactly
   - **cluster_name** must match exactly
   - Example: `Selling Data/Non Production/sellingdataaks` ✅
   - Example: `selling-data/non-production/SellingDataAKS` ❌

---

## Debug Commands

### GitHub Actions Workflow

```bash
# List recent workflow runs
gh run list --workflow=deploy-wiz.yml --limit 10

# View specific run logs
gh run view <run-id> --log

# Re-run failed workflow
gh run rerun <run-id>

# Watch workflow in real-time
gh run watch
```

### Azure & AKS

```bash
# List Flux configurations
az aks flux configuration list \
  --resource-group <rg> \
  --cluster-name <cluster> \
  --cluster-type managedClusters \
  --output table

# Show specific Flux configuration
az aks flux configuration show \
  --resource-group <rg> \
  --cluster-name <cluster> \
  --cluster-type managedClusters \
  --name wiz-integration

# Get AKS credentials
az aks get-credentials \
  --resource-group <rg> \
  --name <cluster> \
  --overwrite-existing
```

### Kubernetes / Flux

```bash
# Check Flux system health
flux check

# Check all Flux components
kubectl get all -n flux-system

# Check Kustomizations
kubectl get kustomizations -n flux-system

# Check HelmRepositories
kubectl get helmrepositories -A

# Check HelmReleases
kubectl get helmreleases -A

# View Kustomization status
kubectl describe kustomization wiz -n flux-system

# View HelmRepository status
kubectl describe helmrepository wiz -n wiz

# View HelmRelease status
kubectl describe helmrelease wiz-kubernetes-integration -n wiz
```

### Wiz Components

```bash
# Check all resources in wiz namespace
kubectl get all -n wiz

# Check pods with details
kubectl get pods -n wiz -o wide

# Check pod logs
kubectl logs -n wiz -l app.kubernetes.io/name=wiz-connector

# Check secrets
kubectl get secrets -n wiz

# Describe secret (shows keys but not values)
kubectl describe secret wiz-api-token -n wiz

# Check configmaps
kubectl get configmaps -n wiz

# Check service accounts
kubectl get serviceaccounts -n wiz
```

### Flux Logs

```bash
# Flux controller logs
flux logs -n flux-system

# Specific HelmRelease logs
flux logs --kind=HelmRelease --name=wiz-kubernetes-integration -n wiz

# Kustomization logs
flux logs --kind=Kustomization --name=wiz -n flux-system

# Source logs (HelmRepository)
flux logs --kind=HelmRepository --name=wiz -n wiz
```

---

## Validation Steps

### Post-Deployment Validation

```bash
# 1. Verify namespace created
kubectl get namespace wiz

# 2. Verify secrets exist
kubectl get secrets -n wiz
# Expected: acr-secret, wiz-api-token

# 3. Verify Flux configuration
az aks flux configuration show \
  --resource-group <rg> \
  --cluster-name <cluster> \
  --cluster-type managedClusters \
  --name wiz-integration

# 4. Verify Kustomization
kubectl get kustomization wiz -n flux-system

# 5. Verify HelmRepository
kubectl get helmrepository wiz -n wiz

# 6. Verify HelmRelease
kubectl get helmrelease wiz-kubernetes-integration -n wiz

# 7. Verify Wiz pods running
kubectl get pods -n wiz
# Expected: wiz-connector, wiz-sensor, wiz-admission-controller pods in Running state

# 8. Check pod health
kubectl get pods -n wiz -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[*].ready

# 9. Verify Wiz connector registration
# Check logs for successful registration
kubectl logs -n wiz -l app.kubernetes.io/name=wiz-connector --tail=50
```

### Health Check Script

```bash
#!/bin/bash
NAMESPACE="wiz"

echo "=== Wiz Deployment Health Check ==="
echo ""

echo "1. Namespace Status:"
kubectl get namespace $NAMESPACE

echo -e "\n2. Secrets:"
kubectl get secrets -n $NAMESPACE

echo -e "\n3. Pods:"
kubectl get pods -n $NAMESPACE -o wide

echo -e "\n4. HelmRelease:"
kubectl get helmrelease wiz-kubernetes-integration -n $NAMESPACE

echo -e "\n5. Pod Health:"
for pod in $(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
  echo "  - $pod:"
  kubectl get pod $pod -n $NAMESPACE -o jsonpath='    Status: {.status.phase}, Ready: {.status.containerStatuses[*].ready}{"\n"}'
done

echo -e "\n6. Recent Events:"
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -10
```

---

## Flux Troubleshooting

### Force Flux Reconciliation

```bash
# Reconcile Kustomization immediately
flux reconcile kustomization wiz -n flux-system

# Reconcile HelmRepository
flux reconcile source helm wiz -n wiz

# Reconcile HelmRelease
flux reconcile helmrelease wiz-kubernetes-integration -n wiz
```

### Suspend and Resume

```bash
# Suspend reconciliation
flux suspend kustomization wiz -n flux-system

# Resume reconciliation
flux resume kustomization wiz -n flux-system
```

### Export Flux Resources

```bash
# Export HelmRelease for inspection
flux export helmrelease wiz-kubernetes-integration -n wiz > helmrelease.yaml

# Export Kustomization
flux export kustomization wiz -n flux-system > kustomization.yaml
```

---

## Support Resources

### Documentation

- [README](README.md) - Overview and quick start
- [Workflow Guide](workflow-guide.md) - GitHub Actions workflow details
- [Configuration Guide](configuration-guide.md) - Setup instructions

### External Resources

- [Wiz Documentation](https://docs.wiz.io/)
- [Flux CD Documentation](https://fluxcd.io/docs/)
- [Azure AKS Flux Documentation](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2)

### Getting Help

1. **Check this troubleshooting guide** for common issues
2. **Review GitHub Actions logs** in the Actions tab
3. **Check Flux logs** using commands above
4. **Inspect pod logs** for specific error messages
5. **Run validation steps** to identify missing components

### Support Contacts

For issues or questions:
- DevOps Team: `devops@yourcompany.com`
- Wiz Support: https://support.wiz.io/

---

**Document Version:** 1.0
**Last Updated:** 2026-01-07
**Maintainer:** DevOps Team
