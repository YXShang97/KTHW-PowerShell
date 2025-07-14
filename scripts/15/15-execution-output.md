# Kubernetes the Hard Way - Step 15: Cleanup

**Tutorial Step**: 15  
**Tutorial Name**: Cleanup  
**Original Tutorial**: [kubernetes-the-hard-way-on-azure/docs/15-cleanup.md](https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/15-cleanup.md)  
**Description**: In this lab you will delete all resources that were created during this tutorial.  
**Script File**: `15-cleanup.ps1`

## ⚠️ IMPORTANT WARNING

**This script will permanently delete ALL resources created during the tutorial!**

This includes:
- Azure resource group 'kubernetes' and all resources within it (VMs, networks, storage, etc.)
- All certificate files in the local `certs` directory
- All kubeconfig files in the local `configs` directory
- CFSSL binary files in the local `cfssl` directory
- kubectl context configuration

**Please ensure you have backed up any important data before proceeding.**

## Script Overview

This PowerShell script provides a comprehensive cleanup process that safely removes all resources created during the Kubernetes the Hard Way tutorial. The script includes user confirmation, error handling, and detailed status reporting to ensure a clean and complete removal of all tutorial-related resources.

## Script Features

- **User Confirmation**: Requires explicit confirmation before proceeding
- **Safe Execution**: Checks for resource existence before attempting deletion
- **Error Handling**: Graceful handling of missing resources or deletion failures
- **Progress Reporting**: Clear status updates throughout the cleanup process
- **Comprehensive Cleanup**: Removes both cloud and local resources

## Sample Execution Output

```
Starting Kubernetes the Hard Way - Cleanup Process...
============================================================
⚠️  WARNING: This will delete ALL resources created during the tutorial!
============================================================

Step 1: Confirmation required before proceeding...
This script will permanently delete:
  • Azure resource group 'kubernetes' and all resources within it
  • All certificates in the certs directory
  • All kubeconfig files in the configs directory
  • CFSSL binaries in the cfssl directory

Are you sure you want to proceed? Type 'YES' to confirm: YES

✅ User confirmed - proceeding with cleanup...

Step 2: Deleting Azure resource group...
Checking if 'kubernetes' resource group exists...
✓ Found resource group: kubernetes
Deleting resource group 'kubernetes' and all contained resources...
⏳ This may take several minutes...
✅ Resource group deletion initiated successfully
   Note: Deletion continues in background

Step 3: Cleaning up certificate files...
Found certificates directory: certs
Removing 34 certificate files...
✅ Certificate files removed successfully

Step 4: Cleaning up kubeconfig files...
Found configs directory: configs
Removing 6 kubeconfig files...
✅ Kubeconfig files removed successfully

Step 5: Cleaning up CFSSL binaries...
Found cfssl directory: cfssl
Removing 2 CFSSL binary files...
✅ CFSSL binaries removed successfully

Step 6: Cleaning up kubectl context...
Removing kubernetes-the-hard-way context from kubectl...
✅ Kubectl context cleaned up

============================================================
🎉 Kubernetes the Hard Way - Cleanup Complete!
============================================================

Cleanup Summary:
✅ Azure resource group deletion initiated
✅ Local certificate files removed
✅ Kubeconfig files removed
✅ CFSSL binaries removed
✅ Kubectl context cleaned up

Important Notes:
• Azure resources may take several minutes to fully delete
• Check Azure portal to confirm complete resource deletion
• Your Azure subscription is now clean of tutorial resources

🚀 Thank you for completing Kubernetes the Hard Way!
You have successfully learned how to set up Kubernetes from scratch!
```

## What the Script Does

### Step-by-Step Breakdown

1. **User Confirmation**
   - Displays a clear warning about what will be deleted
   - Requires the user to type "YES" to confirm the destructive operation
   - Exits safely if confirmation is not provided

2. **Azure Resource Group Deletion**
   - Checks if the 'kubernetes' resource group exists
   - Initiates deletion of the entire resource group and all contained resources
   - Uses `--no-wait` flag to allow deletion to continue in the background
   - This removes all VMs, network resources, storage accounts, and other Azure resources

3. **Certificate Files Cleanup**
   - Removes all certificate files from the local `certs` directory
   - Includes CA certificates, server certificates, client certificates, and private keys
   - Counts and reports the number of files removed

4. **Kubeconfig Files Cleanup**
   - Removes all kubeconfig files from the local `configs` directory
   - Includes configurations for admin, controller manager, scheduler, and worker nodes
   - Counts and reports the number of files removed

5. **CFSSL Binaries Cleanup**
   - Removes CFSSL and CFSSLJSON binary files from the local `cfssl` directory
   - Cleans up the certificate generation tools downloaded during setup

6. **Kubectl Context Cleanup**
   - Removes the 'kubernetes-the-hard-way' context from kubectl configuration
   - Cleans up cluster and user configurations
   - Ensures no leftover kubectl configurations remain

## Expected Behavior

When run successfully, the script will:
- ✅ **Remove all Azure resources** created during the tutorial
- ✅ **Clean local directories** of all tutorial-related files
- ✅ **Reset kubectl configuration** to remove tutorial contexts
- ✅ **Provide confirmation** of each cleanup step

## Validation Commands

After running the cleanup script, use these commands to verify complete removal:

### Verify Azure Resources Deletion
```powershell
# Check if the kubernetes resource group still exists
az group show --name kubernetes

# List all resource groups to confirm removal
az group list --query "[].name" --output table

# Check for any remaining VMs (should return empty)
az vm list --query "[].name" --output table
```

### Verify Local File Cleanup
```powershell
# Check if certificate files were removed
Get-ChildItem -Path "certs" -ErrorAction SilentlyContinue

# Check if kubeconfig files were removed
Get-ChildItem -Path "configs" -ErrorAction SilentlyContinue

# Check if CFSSL binaries were removed
Get-ChildItem -Path "cfssl" -ErrorAction SilentlyContinue

# Verify directories exist but are empty
Test-Path "certs" -PathType Container
Test-Path "configs" -PathType Container
Test-Path "cfssl" -PathType Container
```

### Verify Kubectl Context Cleanup
```powershell
# Check current kubectl contexts
kubectl config get-contexts

# Verify no kubernetes-the-hard-way context exists
kubectl config current-context

# List all clusters in kubectl config
kubectl config get-clusters
```

### Verify Complete Azure Cleanup
```powershell
# Check for any remaining Azure resources with 'kubernetes' in the name
az resource list --query "[?contains(name, 'kubernetes')].{Name:name, Type:type, ResourceGroup:resourceGroup}" --output table

# Verify no compute resources remain
az vm list --output table
az disk list --output table
az network vnet list --output table
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Resource Group Deletion Fails
**Cause**: Resources may be locked or have dependencies

**Solutions**:
```powershell
# Check for resource locks
az lock list --resource-group kubernetes

# Force delete with different approach
az group delete --name kubernetes --yes --force-deletion-types Microsoft.Compute/virtualMachines

# Manual cleanup if automated fails
az vm delete --ids $(az vm list --resource-group kubernetes --query "[].id" --output tsv) --yes --no-wait
az group delete --name kubernetes --yes
```

#### 2. Permission Errors on Local Files
**Cause**: Files may be in use or have restricted permissions

**Solutions**:
```powershell
# Check for file locks
Get-Process | Where-Object {$_.Path -like "*cfssl*" -or $_.Path -like "*kubectl*"}

# Force removal with elevated permissions
Remove-Item -Path "certs\*" -Recurse -Force -ErrorAction Continue
Remove-Item -Path "configs\*" -Recurse -Force -ErrorAction Continue
Remove-Item -Path "cfssl\*" -Recurse -Force -ErrorAction Continue

# Manual file removal if script fails
takeown /f certs /r /d y
icacls certs /grant administrators:F /t
Remove-Item -Path "certs\*" -Recurse -Force
```

#### 3. Azure CLI Authentication Issues
**Cause**: Azure CLI session may have expired

**Solutions**:
```powershell
# Re-authenticate to Azure
az login

# Check current subscription
az account show

# Set correct subscription if needed
az account set --subscription "<your-subscription-id>"

# Retry resource group deletion
az group delete --name kubernetes --yes
```

#### 4. Kubectl Context Errors
**Cause**: kubectl configuration may be corrupted

**Solutions**:
```powershell
# Backup current kubectl config
Copy-Item "$env:USERPROFILE\.kube\config" "$env:USERPROFILE\.kube\config.backup"

# Manually edit kubectl config to remove kubernetes-the-hard-way entries
kubectl config unset clusters.kubernetes-the-hard-way
kubectl config unset contexts.kubernetes-the-hard-way
kubectl config unset users.admin

# Reset kubectl config if needed
Remove-Item "$env:USERPROFILE\.kube\config" -Force
kubectl config view
```

#### 5. Incomplete Cleanup Detection
**Verification Script**:
```powershell
# Comprehensive cleanup verification
Write-Host "Checking for remaining resources..." -ForegroundColor Yellow

# Check Azure resources
$azureResources = az resource list --query "[?contains(name, 'kubernetes') || contains(resourceGroup, 'kubernetes')]" --output tsv
if ($azureResources) {
    Write-Host "⚠️ Found remaining Azure resources:" -ForegroundColor Red
    az resource list --query "[?contains(name, 'kubernetes') || contains(resourceGroup, 'kubernetes')].{Name:name, Type:type, ResourceGroup:resourceGroup}" --output table
} else {
    Write-Host "✅ No Azure resources found" -ForegroundColor Green
}

# Check local files
$localFiles = @()
if (Test-Path "certs") { $localFiles += Get-ChildItem "certs" }
if (Test-Path "configs") { $localFiles += Get-ChildItem "configs" }
if (Test-Path "cfssl") { $localFiles += Get-ChildItem "cfssl" }

if ($localFiles.Count -gt 0) {
    Write-Host "⚠️ Found remaining local files:" -ForegroundColor Red
    $localFiles | ForEach-Object { Write-Host "  $($_.FullName)" }
} else {
    Write-Host "✅ No local files found" -ForegroundColor Green
}

# Check kubectl contexts
$kubeContexts = kubectl config get-contexts --output name 2>$null | Where-Object { $_ -like "*kubernetes-the-hard-way*" }
if ($kubeContexts) {
    Write-Host "⚠️ Found remaining kubectl contexts:" -ForegroundColor Red
    $kubeContexts | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "✅ No kubectl contexts found" -ForegroundColor Green
}
```

## Alternative Cleanup Methods

### Manual Azure Portal Cleanup
1. Navigate to [Azure Portal](https://portal.azure.com)
2. Go to "Resource groups"
3. Find and select the "kubernetes" resource group
4. Click "Delete resource group"
5. Type the resource group name to confirm
6. Click "Delete"

### Azure CLI Alternative Commands
```powershell
# Delete specific resource types individually
az vm delete --ids $(az vm list --resource-group kubernetes --query "[].id" --output tsv) --yes --no-wait
az network vnet delete --ids $(az network vnet list --resource-group kubernetes --query "[].id" --output tsv) --no-wait
az storage account delete --ids $(az storage account list --resource-group kubernetes --query "[].id" --output tsv) --yes

# Force delete the resource group
az group delete --name kubernetes --yes --force-deletion-types Microsoft.Compute/virtualMachines,Microsoft.Network/virtualNetworks
```

### PowerShell Alternative for Local Cleanup
```powershell
# Alternative local cleanup using .NET methods
[System.IO.Directory]::Delete((Resolve-Path "certs").Path, $true)
[System.IO.Directory]::Delete((Resolve-Path "configs").Path, $true)  
[System.IO.Directory]::Delete((Resolve-Path "cfssl").Path, $true)

# Recreate empty directories
New-Item -ItemType Directory -Path "certs" -Force
New-Item -ItemType Directory -Path "configs" -Force
New-Item -ItemType Directory -Path "cfssl" -Force
```

## Security Notes

⚠️ **Important Security Considerations**:

- **Irreversible Operation**: Resource deletion cannot be undone
- **Data Loss**: All VMs, storage, and configurations will be permanently lost
- **Cost Implications**: Ensure no important resources share the same resource group
- **Backup Considerations**: Back up any customizations or important data before cleanup

## Cost Savings

After successful cleanup:
- ✅ **Azure costs stop accruing** for all tutorial resources
- ✅ **No ongoing charges** for VMs, storage, or networking
- ✅ **Clean Azure subscription** ready for future projects
- ✅ **Local disk space recovered** from certificates and binaries

## Summary

The cleanup script provides a comprehensive and safe way to remove all resources created during the Kubernetes the Hard Way tutorial. It includes:

- **Interactive confirmation** to prevent accidental deletion
- **Comprehensive resource removal** covering both cloud and local resources
- **Error handling** for graceful failure recovery
- **Detailed reporting** of cleanup progress and results
- **Validation guidance** to confirm complete removal

After running this script, your environment will be completely clean of all tutorial resources, and you will have successfully completed the Kubernetes the Hard Way tutorial while learning how to properly clean up cloud resources.

## Congratulations! 🎉

You have successfully completed the **Kubernetes the Hard Way** tutorial using PowerShell! You've learned:

- How to set up a Kubernetes cluster from scratch
- Certificate management and PKI infrastructure
- Kubernetes component configuration and networking
- Troubleshooting and validation techniques
- Proper resource cleanup and cost management

This knowledge provides a solid foundation for understanding how Kubernetes works internally and will help you in your journey as a Kubernetes administrator or developer.
