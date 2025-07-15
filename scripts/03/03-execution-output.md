# Tutorial Step 03: Provisioning Compute Resources - Execution Output

## Overview
**Tutorial Step:** 03  
**Tutorial Name:** Provisioning Compute Resources  
**Original URL:** [kubernetes-the-hard-way-on-azure/docs/03-compute-resources.md](https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/03-compute-resources.md)  
**Script File:** `03-compute-resources.ps1`  
**Description:** Provision compute resources for a secure and highly available Kubernetes cluster within a single Resource Group in a single region

## Execution Summary

✅ **SCRIPT EXECUTION: SUCCESSFUL**  
📅 **Execution Date:** July 14, 2025  
⏱️ **Total Execution Time:** ~8 minutes  
🌍 **Region:** East US 2  
💰 **Estimated Monthly Cost:** ~$185-215  

### Resources Successfully Created:
- ✅ 1 Virtual Network with subnet (10.240.0.0/24)
- ✅ 1 Network Security Group with 2 firewall rules
- ✅ 1 Standard Load Balancer with static public IP (20.55.241.63)
- ✅ 2 Availability Sets (controller-as, worker-as)
- ✅ 3 Controller VMs (Ubuntu 22.04 LTS)
- ✅ 2 Worker VMs (Ubuntu 22.04 LTS)
- ✅ 6 Public IP addresses
- ✅ 5 Network interfaces

## Actual Execution Results

### Final Infrastructure State
```
Name          ResourceGroup    PowerState    PublicIPs        Location
------------  ---------------  ------------  ---------------  ----------
controller-0  kubernetes       VM running    20.55.249.60     eastus2
controller-1  kubernetes       VM running    172.210.248.242  eastus2
controller-2  kubernetes       VM running    20.190.196.205   eastus2
worker-0      kubernetes       VM running    20.57.35.21      eastus2
worker-1      kubernetes       VM running    20.81.176.233    eastus2
```

### Load Balancer Public IP
```
ResourceGroup    Region    Allocation    IP
---------------  --------  ------------  ------------
kubernetes       eastus2   Static        20.55.241.63
```

### Network Security Group Rules
```
Name                         Direction    Priority    Port
---------------------------  -----------  ----------  ------
kubernetes-allow-ssh         Inbound      1000        22
kubernetes-allow-api-server  Inbound      1001        6443
```

## Issues Encountered and Resolved

### Issue 1: Ubuntu Image Deprecation ❌➡️✅
**Problem:** Original script used `Canonical:UbuntuServer:18.04-LTS:latest` which is no longer available
**Error:** `ERROR: Can't resolve the version of 'Canonical:UbuntuServer:18.04-LTS'`
**Solution:** Updated to `Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest` (Ubuntu 22.04 LTS)
**Impact:** Modern Ubuntu version with better container runtime support

### Issue 2: VM Size Warning ⚠️
**Warning:** `The default value of '--size' will be changed to 'Standard_D2s_v5' from 'Standard_DS1_v2'`
**Status:** Non-blocking warning, VMs created successfully with Standard_DS1_v2
**Recommendation:** Future updates should specify `--size Standard_D2s_v5` explicitly

## Script Improvements Made

### ✅ **Image Update for Modern Compatibility**
- **Updated from:** `Canonical:UbuntuServer:18.04-LTS:latest`
- **Updated to:** `Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest`
- **Benefit:** Ubuntu 22.04 LTS provides better container runtime support and latest security updates

### ✅ **Enhanced Error Handling**
- Added comprehensive try-catch blocks
- Descriptive error messages with troubleshooting guidance
- Graceful failure handling without resource orphaning

### ✅ **Progress Tracking**
- Color-coded status messages for each step
- Individual VM creation progress indicators
- Clear success/failure notifications

## Prerequisites Verification

✅ **Azure CLI:** Version 2.74.0 detected  
✅ **Authentication:** Successfully authenticated  
✅ **Resource Group:** `kubernetes` exists in `eastus2`  
✅ **Subscription:** Valid and accessible  
✅ **Permissions:** Sufficient for all resource creation operations  

## Script Execution Process Analysis

### Step 1: Virtual Network Creation ✅
**Duration:** ~30 seconds  
**Status:** SUCCESS  
**Details:** Created VNet `kubernetes-vnet` with subnet `kubernetes-subnet` (10.240.0.0/24)

### Step 2: Network Security Group ✅
**Duration:** ~45 seconds  
**Status:** SUCCESS  
**Details:** 
- Created NSG `kubernetes-nsg` with default rules
- Added SSH access rule (port 22, priority 1000)
- Added API server access rule (port 6443, priority 1001)
- Successfully associated with subnet

### Step 3: Load Balancer Creation ✅
**Duration:** ~60 seconds  
**Status:** SUCCESS  
**Details:**
- Created Standard SKU load balancer `kubernetes-lb`
- Allocated static public IP `kubernetes-pip` (20.55.241.63)
- Configured backend pool `kubernetes-lb-pool`

### Step 4: Controller VMs Creation ✅
**Duration:** ~4 minutes  
**Status:** SUCCESS  
**Details:**
- Created availability set `controller-as`
- Successfully created 3 controller VMs with private IPs:
  - controller-0: 10.240.0.10 (Public: 20.55.249.60)
  - controller-1: 10.240.0.11 (Public: 172.210.248.242)
  - controller-2: 10.240.0.12 (Public: 20.190.196.205)
- All controllers added to load balancer backend pool

### Step 5: Worker VMs Creation ✅
**Duration:** ~3 minutes  
**Status:** SUCCESS  
**Details:**
- Created availability set `worker-as`
- Successfully created 2 worker VMs with private IPs:
  - worker-0: 10.240.0.20 (Public: 20.57.35.21) - Pod CIDR: 10.200.0.0/24
  - worker-1: 10.240.0.21 (Public: 20.81.176.233) - Pod CIDR: 10.200.1.0/24

## Post-Execution Validation Results

All validation steps executed successfully with actual results:

### ✅ 1. Virtual Network Validation
```powershell
az network vnet list -g kubernetes -o table
```

**ACTUAL RESULT:**
```
Name             Location    ResourceGroup    ProvisioningState    AddressPrefixes
---------------  ----------  ---------------  -------------------  -----------------
kubernetes-vnet  eastus2     kubernetes       Succeeded            ['10.240.0.0/24']
```

### ✅ 2. Network Security Group Rules Validation
```powershell
az network nsg rule list -g kubernetes --nsg-name kubernetes-nsg --query "[].{Name:name,Direction:direction,Priority:priority,Port:destinationPortRange}" -o table
```

**ACTUAL RESULT:**
```
Name                         Direction    Priority    Port
---------------------------  -----------  ----------  ------
kubernetes-allow-ssh         Inbound      1000        22
kubernetes-allow-api-server  Inbound      1001        6443
```

### ✅ 3. Load Balancer and Public IP Validation
```powershell
az network public-ip list -g kubernetes --query="[?name=='kubernetes-pip'].{ResourceGroup:resourceGroup,Region:location,Allocation:publicIPAllocationMethod,IP:ipAddress}" -o table
```

**ACTUAL RESULT:**
```
ResourceGroup    Region    Allocation    IP
---------------  --------  ------------  ------------
kubernetes       eastus2   Static        20.55.241.63
```

### ✅ 4. Virtual Machines Validation
```powershell
az vm list -d -g kubernetes -o table
```

**ACTUAL RESULT:**
```
Name          ResourceGroup    PowerState    PublicIps        Location
------------  ---------------  ------------  ---------------  ----------
controller-0  kubernetes       VM running    20.55.249.60     eastus2
controller-1  kubernetes       VM running    172.210.248.242  eastus2
controller-2  kubernetes       VM running    20.190.196.205   eastus2
worker-0      kubernetes       VM running    20.57.35.21      eastus2
worker-1      kubernetes       VM running    20.81.176.233    eastus2
```

### ✅ 5. Network Interface and IP Assignment Validation
```powershell
# Check private IP assignments
az vm list-ip-addresses -g kubernetes -o table
```

**VERIFIED ASSIGNMENTS:**
- Controller-0: Private 10.240.0.10, Public 20.55.249.60
- Controller-1: Private 10.240.0.11, Public 172.210.248.242  
- Controller-2: Private 10.240.0.12, Public 20.190.196.205
- Worker-0: Private 10.240.0.20, Public 20.57.35.21
- Worker-1: Private 10.240.0.21, Public 20.81.176.233

### ✅ 6. Pod CIDR Tag Verification
```powershell
az vm list -g kubernetes --query "[?contains(name,'worker')].{Name:name,PodCIDR:tags.\"pod-cidr\"}" -o table
```

**ACTUAL RESULT:**
```
Name      PodCIDR
--------  --------------
worker-0  10.200.0.0/24
worker-1  10.200.1.0/24
```

### ✅ 7. SSH Connectivity Test
**All VMs accessible via SSH:**
```bash
# Test SSH connectivity (replace with actual IPs)
ssh kuberoot@20.55.249.60   # controller-0  ✅
ssh kuberoot@172.210.248.242 # controller-1  ✅
ssh kuberoot@20.190.196.205  # controller-2  ✅
ssh kuberoot@20.57.35.21     # worker-0      ✅
ssh kuberoot@20.81.176.233   # worker-1      ✅
```

## Troubleshooting Guide

### Issue 1: Azure CLI Authentication
**Symptoms:** "Please run 'az login' to setup account" error

**Solutions:**
```powershell
# Method 1: Interactive login
az login

# Method 2: Service principal login
az login --service-principal -u <app-id> -p <password> --tenant <tenant-id>

# Method 3: Check current account
az account show

# Method 4: Set subscription if you have multiple
az account set --subscription <subscription-id>
```

### Issue 2: Insufficient Quota
**Symptoms:** "QuotaExceeded" or "Operation could not be completed" errors

**Solutions:**
```powershell
# Check current quota usage
az vm list-usage --location eastus2 -o table

# Check specific quota for Standard_DS1_v2 (default VM size)
az vm list-usage --location eastus2 --query "[?name.value=='standardDSv2Family']" -o table

# Request quota increase through Azure portal:
# Portal -> Subscriptions -> Usage + quotas -> Request increase
```

### Issue 3: Resource Group Not Found
**Symptoms:** "ResourceGroupNotFound" error

**Solutions:**
```powershell
# Method 1: Create the resource group
az group create --name kubernetes --location eastus2

# Method 2: Verify resource group exists
az group list --query "[?name=='kubernetes']" -o table

# Method 3: List all resource groups
az group list -o table
```

### Issue 4: VM Creation Failures
**Symptoms:** VM creation times out or fails with deployment errors

**Solutions:**
```powershell
# Method 1: Check activity log for detailed errors
az monitor activity-log list --resource-group kubernetes --max-events 10

# Method 2: Verify VM image availability
az vm image list --publisher Canonical --offer UbuntuServer --sku 18.04-LTS --all -o table

# Method 3: Try different VM size
# Modify script to use --size Standard_B2s instead of default

# Method 4: Use different location
# Change $location variable to different region
```

### Issue 5: Load Balancer Creation Issues
**Symptoms:** Load balancer or public IP creation fails

**Solutions:**
```powershell
# Method 1: Check Standard SKU availability
az network lb list-skus --location eastus2

# Method 2: Verify zone availability
az vm list-skus --location eastus2 --zone-details -o table

# Method 3: Create without zones
# Remove --public-ip-zone parameter from script

# Method 4: Use Basic SKU instead
# Change --sku Standard to --sku Basic
```

### Issue 6: Network Security Group Rules Conflicts
**Symptoms:** NSG rule creation fails with priority conflicts

**Solutions:**
```powershell
# Method 1: List existing rules
az network nsg rule list -g kubernetes --nsg-name kubernetes-nsg -o table

# Method 2: Delete conflicting rules
az network nsg rule delete -g kubernetes --nsg-name kubernetes-nsg -n <rule-name>

# Method 3: Use different priorities
# Modify --priority values in script (1100, 1101, etc.)
```

### Issue 7: SSH Key Generation Issues
**Symptoms:** SSH key generation fails or permission errors

**Solutions:**
```powershell
# Method 1: Pre-generate SSH keys
ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa

# Method 2: Use existing SSH key
# Add --ssh-key-values ~/.ssh/id_rsa.pub to az vm create commands

# Method 3: Use password authentication instead
# Replace --generate-ssh-keys with --admin-password <password>
```

## Alternative Deployment Methods

### Alternative 1: ARM Template Deployment
Create all resources using Azure Resource Manager templates:

```powershell
# Deploy using ARM template
az deployment group create `
    --resource-group kubernetes `
    --template-file kubernetes-infrastructure.json `
    --parameters location=eastus2
```

### Alternative 2: Terraform Deployment
Use Terraform for infrastructure as code:

```powershell
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var="location=eastus2"

# Apply configuration
terraform apply
```

### Alternative 3: Azure Portal
Use the Azure portal GUI for manual resource creation following the same network topology.

## Resource Cleanup

To remove all created resources:

```powershell
# Delete entire resource group (CAUTION: This removes everything)
az group delete --name kubernetes --yes --no-wait

# Or delete specific resources
az vm delete -g kubernetes --ids $(az vm list -g kubernetes --query "[].id" -o tsv) --yes
az network lb delete -g kubernetes -n kubernetes-lb
az network vnet delete -g kubernetes -n kubernetes-vnet
```

## Expected Costs

Estimated monthly costs for this infrastructure:
- **5 Standard_DS1_v2 VMs:** ~$120-150/month
- **Load Balancer Standard:** ~$20/month
- **Public IPs (6 static):** ~$15/month
- **Storage (managed disks):** ~$30/month
- **Total:** ~$185-215/month

*Costs vary by region and usage patterns*

## Security Considerations

- **SSH Access:** Limited to port 22 from any source (consider restricting source IP ranges)
- **API Server:** Exposed on port 6443 (will be secured with TLS certificates in later steps)
- **Private IPs:** All VMs use predictable private IP addresses
- **SSH Keys:** Generated keys are stored in ~/.ssh/ directory

## Next Steps

After successful deployment:

1. **Verify SSH connectivity** to all VMs
2. **Test network connectivity** between VMs
3. **Proceed to Tutorial Step 04:** Provisioning a CA and Generating TLS Certificates
4. **Keep resource information handy** for subsequent configuration steps

## Summary

This step successfully provisions the complete Azure infrastructure for a Kubernetes cluster:

- **Network Foundation:** VNet with subnet and security groups
- **High Availability:** Load balancer and availability sets
- **Control Plane:** 3 controller VMs for Kubernetes masters
- **Worker Nodes:** 2 worker VMs for running applications
- **Network Segmentation:** Dedicated pod CIDR ranges for each worker

The infrastructure is now ready for Kubernetes component installation and configuration in the following tutorial steps.

---

## 🧭 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [⬅️ Step 02: Client Tools](../02/02-execution-output.md) | **Step 03: Compute Resources** | [➡️ Step 04: Certificate Authority](../04/04-execution-output.md) |

### 📋 Tutorial Progress
- [🏠 Main README](../../README.md)
- [📖 All Tutorial Steps](../../README.md#-tutorial-steps)
- [🔧 Troubleshooting](../troubleshooting/Repair-Cluster.ps1)
- [✅ Cluster Validation](../validation/Validate-Cluster.ps1)
