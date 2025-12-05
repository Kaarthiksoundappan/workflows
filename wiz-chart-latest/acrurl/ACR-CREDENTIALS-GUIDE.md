# ACR Credentials Guide

This guide helps you obtain Azure Container Registry (ACR) credentials for the `mirror-images-to-acr.sh` script.

## Why Docker Login Instead of `az acr login`?

Recent versions of Azure CLI have issues with `az acr login` not working properly. The recommended approach is to use `docker login` with ACR credentials directly.

## Getting ACR Credentials

### Method 1: Admin User Credentials (Quick & Easy)

**Step 1: Enable admin user**
```bash
az acr update --name your-acr-name --admin-enabled true
```

**Step 2: Get credentials**
```bash
az acr credential show --name your-acr-name
```

**Output:**
```json
{
  "passwords": [
    {
      "name": "password",
      "value": "AbCd1234EfGh5678IjKl9012MnOp3456"
    },
    {
      "name": "password2",
      "value": "QrSt7890UvWx1234YzAb5678CdEf9012"
    }
  ],
  "username": "youracrname"
}
```

**Step 3: Update script configuration**
```bash
ACR_NAME="youracrname"
ACR_USERNAME="youracrname"
ACR_PASSWORD="AbCd1234EfGh5678IjKl9012MnOp3456"  # Use password or password2
```

### Method 2: Service Principal (Production Recommended)

Service principals provide better security with scoped permissions.

**Step 1: Create service principal**
```bash
# Get ACR resource ID
ACR_ID=$(az acr show --name your-acr-name --query id --output tsv)

# Create service principal with push/pull permissions
SP_CREDENTIALS=$(az ad sp create-for-rbac \
  --name "acr-mirror-sp" \
  --role acrpush \
  --scopes $ACR_ID)

echo $SP_CREDENTIALS
```

**Output:**
```json
{
  "appId": "12345678-1234-1234-1234-123456789012",
  "displayName": "acr-mirror-sp",
  "password": "your-service-principal-password",
  "tenant": "87654321-4321-4321-4321-210987654321"
}
```

**Step 2: Update script configuration**
```bash
ACR_NAME="youracrname"
ACR_USERNAME="12345678-1234-1234-1234-123456789012"  # appId
ACR_PASSWORD="your-service-principal-password"        # password
```

### Method 3: Managed Identity (For Azure VMs/AKS)

If running on Azure VM or AKS, use managed identity.

**Step 1: Assign identity access to ACR**
```bash
# For system-assigned identity
az role assignment create \
  --assignee <managed-identity-principal-id> \
  --role acrpull \
  --scope /subscriptions/<subscription-id>/resourceGroups/<rg>/providers/Microsoft.ContainerRegistry/registries/<acr-name>
```

**Step 2: Get access token**
```bash
# Get token from instance metadata
TOKEN=$(curl -s 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/' -H Metadata:true | jq -r .access_token)

# Exchange for ACR refresh token
REFRESH_TOKEN=$(curl -s -X POST \
  "https://<acr-name>.azurecr.io/oauth2/exchange" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=access_token&service=<acr-name>.azurecr.io&access_token=$TOKEN" \
  | jq -r .refresh_token)
```

**Step 3: Update script configuration**
```bash
ACR_NAME="youracrname"
ACR_USERNAME="00000000-0000-0000-0000-000000000000"  # Use this special UUID
ACR_PASSWORD="$REFRESH_TOKEN"                         # The refresh token
```

## Using the Credentials

### Update mirror-images-to-acr.sh

Edit the script configuration section:

```bash
# Your Azure Container Registry name (without .azurecr.io)
ACR_NAME="youracrname"

# ACR authentication credentials
ACR_USERNAME="youracrname"                           # From step above
ACR_PASSWORD="AbCd1234EfGh5678IjKl9012MnOp3456"      # From step above
ACR_USE_AZ_LOGIN=false                               # Keep as false
```

### Test the Login

Before running the full script, test the login:

```bash
# Test docker login
echo "AbCd1234EfGh5678IjKl9012MnOp3456" | docker login youracrname.azurecr.io \
  --username youracrname \
  --password-stdin
```

**Expected output:**
```
Login Succeeded
```

## Troubleshooting

### Issue: "unauthorized: authentication required"

**Cause:** Invalid credentials or ACR admin not enabled

**Fix:**
```bash
# Enable admin user
az acr update --name your-acr-name --admin-enabled true

# Verify credentials
az acr credential show --name your-acr-name

# Test login
docker login your-acr-name.azurecr.io -u <username> -p <password>
```

### Issue: "az acr login" not working

**Cause:** Recent Azure CLI versions have compatibility issues

**Fix:** Use docker login method (Method 1 or 2 above) instead of `az acr login`

### Issue: Service principal lacks permissions

**Cause:** Insufficient RBAC roles

**Fix:**
```bash
# Get ACR resource ID
ACR_ID=$(az acr show --name your-acr-name --query id --output tsv)

# Assign acrpush role (includes pull and push)
az role assignment create \
  --assignee <service-principal-app-id> \
  --role acrpush \
  --scope $ACR_ID

# Or assign both roles explicitly
az role assignment create --assignee <sp-app-id> --role acrpull --scope $ACR_ID
az role assignment create --assignee <sp-app-id> --role acrpush --scope $ACR_ID
```

### Issue: Token expired

**Cause:** Refresh tokens can expire

**Fix:**
```bash
# For admin user: Get new password
az acr credential renew --name your-acr-name --password-name password

# For service principal: Reset credentials
az ad sp credential reset --id <service-principal-app-id>

# Update script with new credentials
```

## Security Best Practices

1. **Use Service Principals** for production (not admin user)
2. **Rotate credentials** regularly
3. **Use Azure Key Vault** to store secrets
4. **Disable admin user** after setup if using service principals
5. **Use RBAC roles** with least privilege:
   - `acrpull` - Read-only access
   - `acrpush` - Push and pull access
   - `acrdelete` - Delete images (use carefully)

## Alternative: Using Azure Key Vault

Store credentials securely:

```bash
# Store in Key Vault
az keyvault secret set \
  --vault-name your-keyvault \
  --name acr-username \
  --value "youracrname"

az keyvault secret set \
  --vault-name your-keyvault \
  --name acr-password \
  --value "your-password"

# Retrieve in script
ACR_USERNAME=$(az keyvault secret show --vault-name your-keyvault --name acr-username --query value -o tsv)
ACR_PASSWORD=$(az keyvault secret show --vault-name your-keyvault --name acr-password --query value -o tsv)
```

## Quick Reference Commands

```bash
# List ACRs in subscription
az acr list --output table

# Show ACR details
az acr show --name your-acr-name

# Enable admin user
az acr update --name your-acr-name --admin-enabled true

# Get admin credentials
az acr credential show --name your-acr-name

# Test docker login
docker login your-acr-name.azurecr.io -u <username> -p <password>

# List images in ACR
az acr repository list --name your-acr-name --output table

# Show image tags
az acr repository show-tags --name your-acr-name --repository wiz/sensor --output table
```

## Need Help?

- [Azure ACR Authentication Documentation](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-authentication)
- [Azure Service Principals](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal)
- [Docker Login Reference](https://docs.docker.com/engine/reference/commandline/login/)
