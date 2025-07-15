# Tutorial Step 05: Generating Kubernetes Configuration Files for Authentication - Execution Output

## Tutorial Information
- **Tutorial Step**: 05
- **Tutorial Name**: Generating Kubernetes Configuration Files for Authentication
- **Original URL**: https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/05-kubernetes-configuration-files.md
- **Script File**: `05-generate-kub-config.ps1`

## Description
In this lab you will generate Kubernetes configuration files, also known as kubeconfigs, which enable Kubernetes clients to locate and authenticate to the Kubernetes API Servers. These configuration files contain the necessary certificates and endpoints for different Kubernetes components and users.

## Prerequisites
- kubectl installed and available in PATH
- Certificates generated from Tutorial Step 04 (PKI infrastructure)
- Azure infrastructure deployed (Tutorial Step 03) with VMs running
- Azure CLI authenticated and configured

## Script Execution

### Command Run
```powershell
cd scripts\05
.\05-generate-kub-config.ps1
```

### Execution Output
```
Working in: C:\repos\kthw\configs
Certificates path: C:\repos\kthw\scripts\05\..\..\certs
Retrieving Kubernetes public IP address...
Kubernetes API Server Public IP: 20.55.241.63
Generating kubelet kubeconfig files for worker nodes...
Creating kubeconfig for worker-0...
Cluster "kubernetes-the-hard-way" set.
User "system:node:worker-0" set.
Context "default" modified.
Switched to context "default".
✅ Created worker-0.kubeconfig
Creating kubeconfig for worker-1...
Cluster "kubernetes-the-hard-way" set.
User "system:node:worker-1" set.
Context "default" modified.
Switched to context "default".
✅ Created worker-1.kubeconfig
Generating kube-proxy kubeconfig file...
Cluster "kubernetes-the-hard-way" set.
User "kube-proxy" set.
Context "default" modified.
Switched to context "default".
✅ Created kube-proxy.kubeconfig
Generating kube-controller-manager kubeconfig file...
Cluster "kubernetes-the-hard-way" set.
User "system:kube-controller-manager" set.
Context "default" modified.
Switched to context "default".
✅ Created kube-controller-manager.kubeconfig
Generating kube-scheduler kubeconfig file...
Cluster "kubernetes-the-hard-way" set.
User "system:kube-scheduler" set.
Context "default" modified.
Switched to context "default".
✅ Created kube-scheduler.kubeconfig
Generating admin kubeconfig file...
Cluster "kubernetes-the-hard-way" set.
User "admin" set.
Context "default" modified.
Switched to context "default".
✅ Created admin.kubeconfig
Distributing kubeconfig files to worker instances...
Copying to worker-0 (20.57.35.21)...
worker-0.kubeconfig                                                                                                                                     100% 6498    92.0KB/s   00:00    
kube-proxy.kubeconfig                                                                                                                                   100% 6422    93.6KB/s   00:00    
✅ Copied kubeconfig files to worker-0
Copying to worker-1 (20.81.176.233)...
worker-1.kubeconfig                                                                                                                                     100% 6494    89.3KB/s   00:00    
kube-proxy.kubeconfig                                                                                                                                   100% 6422    92.2KB/s   00:00    
✅ Copied kubeconfig files to worker-1
Distributing kubeconfig files to controller instances...
Copying to controller-0 (20.55.249.60)...
admin.kubeconfig                                                                                                                                        100% 6381    90.3KB/s   00:00    
kube-controller-manager.kubeconfig                                                                                                                      100% 6507    92.1KB/s   00:00    
kube-scheduler.kubeconfig                                                                                                                               100% 6457    92.7KB/s   00:00    
✅ Copied kubeconfig files to controller-0
Copying to controller-1 (172.210.248.242)...
admin.kubeconfig                                                                                                                                        100% 6381    89.0KB/s   00:00    
kube-controller-manager.kubeconfig                                                                                                                      100% 6507    93.5KB/s   00:00    
kube-scheduler.kubeconfig                                                                                                                               100% 6457    91.4KB/s   00:00    
✅ Copied kubeconfig files to controller-1
Copying to controller-2 (20.190.196.205)...
admin.kubeconfig                                                                                                                                        100% 6381    90.3KB/s   00:00    
kube-controller-manager.kubeconfig                                                                                                                      100% 6507    93.5KB/s   00:00    
kube-scheduler.kubeconfig                                                                                                                               100% 6457    91.4KB/s   00:00    
✅ Copied kubeconfig files to controller-2
Kubeconfig generation and distribution complete!
Generated files:
  admin.kubeconfig
  kube-proxy.kubeconfig
  kube-controller-manager.kubeconfig
  kube-scheduler.kubeconfig
  worker-0.kubeconfig
  worker-1.kubeconfig
```

## Execution Summary

### What the Script Accomplished
1. **Retrieved Kubernetes Public IP**: Found the load balancer IP address (20.55.241.63) for external API access
2. **Generated 6 kubeconfig files**:
   - `worker-0.kubeconfig` - kubelet authentication for worker-0
   - `worker-1.kubeconfig` - kubelet authentication for worker-1  
   - `kube-proxy.kubeconfig` - kube-proxy service authentication
   - `kube-controller-manager.kubeconfig` - controller manager authentication
   - `kube-scheduler.kubeconfig` - scheduler authentication
   - `admin.kubeconfig` - admin user authentication

3. **Distributed files to VMs**:
   - Worker nodes: received their respective kubelet configs + kube-proxy config
   - Controller nodes: received admin, controller-manager, and scheduler configs

### File Distribution Details
- **Worker Nodes** (worker-0, worker-1):
  - Each received its specific `{instance}.kubeconfig` file
  - Both received the shared `kube-proxy.kubeconfig` file

- **Controller Nodes** (controller-0, controller-1, controller-2):  
  - All received `admin.kubeconfig` for administrative access
  - All received `kube-controller-manager.kubeconfig` 
  - All received `kube-scheduler.kubeconfig`

### Key Configuration Differences
- **Worker kubeconfigs**: Use external load balancer IP (20.55.241.63:6443) for API server access
- **Controller kubeconfigs**: Use localhost (127.0.0.1:6443) since they run on the same nodes as API servers
- **Authentication**: Each service uses its specific certificate for mTLS authentication

## Validation Steps

### 1. Verify Local kubeconfig Files
```powershell
# Check that all kubeconfig files were created
Get-ChildItem -Path "..\..\configs" -Filter "*.kubeconfig" | Format-Table Name, Length, LastWriteTime

# Verify file contents (sample for admin.kubeconfig)
kubectl config view --kubeconfig="..\..\configs\admin.kubeconfig"
```

**Actual Results:**
```
PS C:\repos\kthw\configs> Get-ChildItem -Filter "*.kubeconfig" | Format-Table Name, Length, LastWriteTime

Name                               Length LastWriteTime
----                               ------ -------------
admin.kubeconfig                     6381 7/14/2025 11:40:56 AM
kube-controller-manager.kubeconfig   6507 7/14/2025 11:40:55 AM
kube-proxy.kubeconfig                6422 7/14/2025 11:40:54 AM
kube-scheduler.kubeconfig            6457 7/14/2025 11:40:55 AM
worker-0.kubeconfig                  6498 7/14/2025 11:40:53 AM
worker-1.kubeconfig                  6494 7/14/2025 11:40:54 AM

PS C:\repos\kthw\configs> kubectl config view --kubeconfig="admin.kubeconfig"
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: DATA+OMITTED
    server: https://127.0.0.1:6443
  name: kubernetes-the-hard-way
contexts:
- context:
    cluster: kubernetes-the-hard-way
    user: admin
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: admin
  user:
    client-certificate-data: DATA+OMITTED
    client-key-data: DATA+OMITTED
```
✅ **All 6 kubeconfig files created successfully with proper structure and embedded certificates**

### 2. Verify File Distribution on Worker Nodes
```powershell
# Check worker-0
$worker0IP = az network public-ip show -g kubernetes -n worker-0-pip --query "ipAddress" -o tsv
ssh kuberoot@$worker0IP "ls -la *.kubeconfig"

# Check worker-1  
$worker1IP = az network public-ip show -g kubernetes -n worker-1-pip --query "ipAddress" -o tsv
ssh kuberoot@$worker1IP "ls -la *.kubeconfig"
```

**Actual Results:**
```
PS C:\repos\kthw\configs> $worker0IP = az network public-ip show -g kubernetes -n worker-0-pip --query "ipAddress" -o tsv
PS C:\repos\kthw\configs> ssh kuberoot@$worker0IP "ls -la *.kubeconfig"
-rw-rw-r-- 1 kuberoot kuberoot 6422 Jul 14 15:41 kube-proxy.kubeconfig
-rw-rw-r-- 1 kuberoot kuberoot 6498 Jul 14 15:41 worker-0.kubeconfig
```
✅ **Worker-0 has both required kubeconfig files (worker-0.kubeconfig and kube-proxy.kubeconfig)**

### 3. Verify File Distribution on Controller Nodes
```powershell
# Check controller-0
$controller0IP = az network public-ip show -g kubernetes -n controller-0-pip --query "ipAddress" -o tsv
ssh kuberoot@$controller0IP "ls -la *.kubeconfig"

# Check controller-1
$controller1IP = az network public-ip show -g kubernetes -n controller-1-pip --query "ipAddress" -o tsv  
ssh kuberoot@$controller1IP "ls -la *.kubeconfig"

# Check controller-2
$controller2IP = az network public-ip show -g kubernetes -n controller-2-pip --query "ipAddress" -o tsv
ssh kuberoot@$controller2IP "ls -la *.kubeconfig"
```

**Actual Results:**
```
PS C:\repos\kthw\configs> $controller0IP = az network public-ip show -g kubernetes -n controller-0-pip --query "ipAddress" -o tsv
PS C:\repos\kthw\configs> ssh kuberoot@$controller0IP "ls -la *.kubeconfig"
-rw-rw-r-- 1 kuberoot kuberoot 6381 Jul 14 15:41 admin.kubeconfig
-rw-rw-r-- 1 kuberoot kuberoot 6507 Jul 14 15:41 kube-controller-manager.kubeconfig
-rw-rw-r-- 1 kuberoot kuberoot 6457 Jul 14 15:41 kube-scheduler.kubeconfig
```
✅ **Controller-0 has all 3 required kubeconfig files (admin, kube-controller-manager, kube-scheduler)**

### 4. Validate kubeconfig File Structure
```powershell
# Examine a kubeconfig file structure
kubectl config view --kubeconfig="..\..\configs\worker-0.kubeconfig" --raw

# Check cluster configuration
kubectl config get-clusters --kubeconfig="..\..\configs\admin.kubeconfig"

# Check user configuration  
kubectl config get-users --kubeconfig="..\..\configs\admin.kubeconfig"

# Check context configuration
kubectl config get-contexts --kubeconfig="..\..\configs\admin.kubeconfig"
```

### 5. Test Authentication (Optional - requires API server)
```powershell
# Note: This will only work after API servers are running (Tutorial Step 08)
# Test admin access
kubectl get nodes --kubeconfig="..\..\configs\admin.kubeconfig"

# Test if certificates are properly embedded
kubectl config view --kubeconfig="..\..\configs\admin.kubeconfig" --raw | Select-String "certificate-authority-data"
```

## Troubleshooting

### Common Issues and Solutions

#### 1. kubectl Not Found
**Error**: `kubectl : The term 'kubectl' is not recognized`
```powershell
# Solution: Install kubectl or add to PATH
# Check if kubectl is installed
kubectl version --client

# If not installed, install via chocolatey
choco install kubernetes-cli

# Or download and add to PATH manually
```

#### 2. Certificate Files Not Found  
**Error**: Certificate files missing in certs folder
```powershell
# Solution: Ensure Tutorial Step 04 was completed
# Check certificate files exist
Get-ChildItem -Path "..\..\certs" -Filter "*.pem"

# Re-run step 04 if certificates are missing
cd ..\04
.\04-certificate-authority.ps1
```

#### 3. Azure CLI Not Authenticated
**Error**: Authentication errors when retrieving IP addresses
```powershell
# Solution: Re-authenticate with Azure
az login
az account set --subscription "your-subscription-id"

# Verify authentication
az account show
```

#### 4. SSH Connection Issues
**Error**: Permission denied or connection refused during file distribution
```powershell
# Solution: Check SSH key and VM status
# Verify VMs are running
az vm list -g kubernetes --query "[].{Name:name, PowerState:powerState}" -o table

# Test SSH connection
$testIP = az network public-ip show -g kubernetes -n worker-0-pip --query "ipAddress" -o tsv
ssh kuberoot@$testIP "echo 'Connection successful'"

# Check SSH key is properly configured
ssh-add -l
```

#### 5. kubeconfig Generation Errors
**Error**: Cluster/user/context configuration failures
```powershell
# Solution: Clean up and regenerate specific kubeconfig
# Remove problematic kubeconfig file
Remove-Item "..\..\configs\problematic.kubeconfig" -ErrorAction SilentlyContinue

# Regenerate manually with verbose output
kubectl config set-cluster kubernetes-the-hard-way `
    --certificate-authority="..\..\certs\ca.pem" `
    --embed-certs=true `
    --server="https://20.55.241.63:6443" `
    --kubeconfig="test.kubeconfig" `
    --v=2
```

### Verification Commands Summary
```powershell
# Quick verification script
Write-Host "Checking local kubeconfig files..." -ForegroundColor Yellow
Get-ChildItem -Path "..\..\configs" -Filter "*.kubeconfig" | Measure-Object | Select-Object Count

Write-Host "Checking worker nodes..." -ForegroundColor Yellow
$workers = @("worker-0", "worker-1")
foreach ($worker in $workers) {
    $ip = az network public-ip show -g kubernetes -n "$worker-pip" --query "ipAddress" -o tsv
    $files = ssh kuberoot@$ip "ls *.kubeconfig 2>/dev/null | wc -l"
    Write-Host "$worker ($ip): $files kubeconfig files" -ForegroundColor Cyan
}

Write-Host "Checking controller nodes..." -ForegroundColor Yellow  
$controllers = @("controller-0", "controller-1", "controller-2")
foreach ($controller in $controllers) {
    $ip = az network public-ip show -g kubernetes -n "$controller-pip" --query "ipAddress" -o tsv
    $files = ssh kuberoot@$ip "ls *.kubeconfig 2>/dev/null | wc -l"
    Write-Host "$controller ($ip): $files kubeconfig files" -ForegroundColor Cyan
}
```

## Next Steps
- **Tutorial Step 06**: Generating the Data Encryption Config and Key
- The kubeconfig files created in this step will be used by Kubernetes components for authentication when the cluster is bootstrapped
- Admin kubeconfig will be used in later steps for cluster management and verification

## File Locations
- **Local kubeconfig files**: `configs/` folder (6 files)
- **Worker node files**: `/home/kuberoot/` on worker-0 and worker-1 (2 files each)
- **Controller node files**: `/home/kuberoot/` on controller-0, controller-1, controller-2 (3 files each)

## Success Criteria ✅
- [x] 6 kubeconfig files generated successfully
- [x] Files distributed to appropriate VM instances
- [x] All file transfers completed without errors
- [x] kubeconfig files contain embedded certificates
- [x] Proper server endpoints configured (external for workers, localhost for controllers)

---

## 🧭 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [⬅️ Step 04: Certificate Authority](../04/04-execution-output.md) | **Step 05: Kubernetes Configuration** | [➡️ Step 06: Data Encryption](../06/06-execution-output.md) |
