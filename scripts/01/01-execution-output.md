# Kubernetes the Hard Way - Step 01: Prerequisites

**Tutorial Step**: 01  
**Tutorial Name**: Prerequisites  
**Original Tutorial**: [prerequisites.md](https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/01-prerequisites.md)  
**Description**: Set up the foundational requirements for the Kubernetes cluster deployment, including Azure CLI verification and resource group creation.  
**Script File**: `01-prerequisites.ps1`

## 🎯 Overview

This initial step establishes the foundation for the entire Kubernetes the Hard Way tutorial by:

- Verifying Azure CLI installation and version compatibility
- Creating the primary Azure resource group that will contain all tutorial resources
- Ensuring proper Azure authentication and permissions
- Setting up the basic infrastructure foundation

## ⚙️ Execution Instructions

### Prerequisites

Before running this script, ensure you have:

1. **Azure Subscription**: Active Azure subscription with appropriate permissions
2. **Azure CLI**: Version 2.46.0 or higher installed
3. **PowerShell**: PowerShell 7.0+ (recommended) or Windows PowerShell 5.1+
4. **Authentication**: Logged into Azure CLI (`az login`)

### Running the Script

1. **Navigate to the script directory**:
   ```powershell
   cd scripts/01
   ```

2. **Execute the script**:
   ```powershell
   .\01-prerequisites.ps1
   ```

3. **Monitor the output** for any errors or warnings

## 📋 Expected Output

When executed successfully, the script will display:

### Azure CLI Version Check
```
azure-cli                         2.74.0 *
core                              2.74.0 *
telemetry                          1.1.0
Dependencies:
msal                              1.32.3
azure-mgmt-resource               23.3.0
Python location 'C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\python.exe'
Config directory 'C:\Users\username\.azure'
Extensions directory 'C:\Users\username\.azure\cliextensions'
Python (Windows) 3.12.10 (tags/v3.12.10:0cc8128, Apr  8 2025, 11:58:42) [MSC v.1943 32 bit (Intel)]
Legal docs and information: aka.ms/AzureCliLegal
```

### Resource Group Creation
```json
{
  "id": "/subscriptions/subscription-id/resourceGroups/kubernetes",
  "location": "eastus",
  "managedBy": null,
  "name": "kubernetes",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": null,
  "type": "Microsoft.Resources/resourceGroups"
}
```

## ✅ Validation Steps

After running the script, verify the setup using these commands:

### 1. Verify Azure CLI Version
**Command**:
```powershell
az --version
```
**Explanation**: Confirms Azure CLI is installed and displays version information  
**Expected Result**: Should show version 2.46.0 or higher

### 2. Verify Azure Authentication
**Command**:
```powershell
az account show
```
**Explanation**: Displays current Azure subscription and authentication status  
**Expected Result**: Shows your active subscription details

### 3. Verify Resource Group Creation
**Command**:
```powershell
az group show --name kubernetes
```
**Explanation**: Confirms the kubernetes resource group was created successfully  
**Expected Result**: Returns resource group details with "provisioningState": "Succeeded"

### 4. List Resource Groups
**Command**:
```powershell
az group list --query "[].{Name:name, Location:location, State:properties.provisioningState}" --output table
```
**Explanation**: Lists all resource groups to confirm the kubernetes group exists  
**Expected Result**: Table showing the kubernetes resource group in the list

### 5. Check Azure Subscription Permissions
**Command**:
```powershell
az role assignment list --assignee (az account show --query user.name --output tsv) --scope /subscriptions/(az account show --query id --output tsv) --query "[].{Role:roleDefinitionName, Scope:scope}" --output table
```
**Explanation**: Verifies you have appropriate permissions in the subscription  
**Expected Result**: Shows role assignments, should include Contributor or Owner roles

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. Azure CLI Not Found
**Error**: `'az' is not recognized as an internal or external command`

**Solutions**:
```powershell
# Install Azure CLI using winget
winget install Microsoft.AzureCLI

# Or download from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows
# After installation, restart PowerShell
```

#### 2. Azure CLI Version Too Old
**Error**: Azure CLI version below 2.46.0

**Solutions**:
```powershell
# Update Azure CLI
az upgrade

# Or reinstall the latest version
winget upgrade Microsoft.AzureCLI
```

#### 3. Not Logged Into Azure
**Error**: `Please run 'az login' to setup account`

**Solutions**:
```powershell
# Login to Azure
az login

# Login with specific tenant
az login --tenant your-tenant-id

# Login using device code (for restricted environments)
az login --use-device-code
```

#### 4. Insufficient Permissions
**Error**: `AuthorizationFailed` or permission denied errors

**Solutions**:
```powershell
# Check current account
az account show

# Switch to correct subscription
az account set --subscription "your-subscription-name"

# Verify permissions
az role assignment list --assignee (az account show --query user.name --output tsv)
```

#### 5. Resource Group Already Exists
**Error**: `Resource group 'kubernetes' already exists`

**Solutions**:
```powershell
# Check existing resource group
az group show --name kubernetes

# If you want to use existing group, verify it's in correct location
# If you want to start fresh, delete and recreate:
az group delete --name kubernetes --yes
az group create --name kubernetes --location eastus
```

#### 6. Location/Region Issues
**Error**: Resource group cannot be created in specified location

**Solutions**:
```powershell
# List available locations
az account list-locations --query "[].{Name:name, DisplayName:displayName}" --output table

# Use a different location
az group create --name kubernetes --location "West US 2"
```

### General Troubleshooting Steps

1. **Verify Network Connectivity**:
   ```powershell
   Test-NetConnection login.microsoftonline.com -Port 443
   ```

2. **Clear Azure CLI Cache**:
   ```powershell
   az cache purge
   az account clear
   az login
   ```

3. **Check Azure Service Health**:
   - Visit [Azure Status](https://status.azure.com/) to check for service issues

4. **Verbose Logging**:
   ```powershell
   az group create --name kubernetes --location eastus --debug
   ```

## 💰 Cost Considerations

- **Resource Group**: Free to create and maintain
- **Estimated Tutorial Cost**: ~$0.40/hour or ~$10/day for all resources
- **Cost Optimization**: Resources will be created in subsequent steps
- **Cleanup**: Use Step 15 cleanup script to remove all resources when finished

## 🔐 Security Best Practices

1. **Use Least Privilege**: Ensure your Azure account has only necessary permissions
2. **Monitor Costs**: Set up billing alerts to track spending
3. **Resource Tagging**: Consider adding tags to the resource group for tracking:
   ```powershell
   az group update --name kubernetes --tags project=kubernetes-tutorial environment=learning
   ```

## 📚 Additional Resources

- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- [Azure Resource Groups Overview](https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/overview)
- [Azure Free Account](https://azure.microsoft.com/en-us/free/)
- [Kubernetes the Hard Way Original](https://github.com/kelseyhightower/kubernetes-the-hard-way)

## ➡️ Next Step

After completing this step successfully, proceed to:
**[Step 02: Client Tools](../02/02-execution-output.md)**

## 📝 Summary

Step 01 successfully:
- ✅ Verified Azure CLI installation and version
- ✅ Confirmed Azure authentication
- ✅ Created the 'kubernetes' resource group in East US region
- ✅ Established foundation for subsequent tutorial steps

You're now ready to proceed with installing the client tools in Step 02!
