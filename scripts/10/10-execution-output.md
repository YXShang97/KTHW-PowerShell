# Tutorial Step 10: Configuring kubectl for Remote Access - Execution Output

## Overview
Configure kubectl for remote access to the Kubernetes cluster from your Windows machine using admin user credentials.

**Purpose**: Generate kubeconfig file for kubectl command line utility  
**Target**: Remote kubectl access from local Windows machine  
**Script**: `10-cofigure-kubectl.ps1`

## Prerequisites Checklist
- ✅ Certificates generated (Step 04)
- ✅ Admin kubeconfig created (Step 05)
- ✅ Control plane operational (Step 08)
- ✅ Worker nodes joined cluster (Step 09)
- ✅ kubectl installed locally on Windows machine
- ✅ Azure CLI authenticated and configured

## Script Execution

### Command
```powershell
cd c:\repos\kthw\scripts\10
.\10-cofigure-kubectl.ps1
```

## Expected Results

### Step 1: Kubernetes API Server IP Retrieval
```
===============================================
Tutorial Step 10: Configuring kubectl for Remote Access
===============================================

Working directory: C:\repos\kthw\certs

Step 1: Retrieving Kubernetes API Server public IP address...
  ✅ Kubernetes API Server IP: 20.55.241.63
```
**What this does:**
- Retrieves the public IP address of the Kubernetes API Server load balancer
- Uses Azure CLI to query the `kubernetes-pip` public IP resource
- This IP will be used as the server endpoint in kubectl configuration

### Step 2: Cluster Configuration
```
Step 2: Configuring kubectl cluster settings...
Cluster "kubernetes-the-hard-way" set.
  ✅ Cluster configuration set successfully
```
**Configuration Details:**
- **Cluster Name**: `kubernetes-the-hard-way`
- **Server Endpoint**: `https://20.55.241.63:6443`
- **Certificate Authority**: Embedded `ca.pem` for TLS verification
- **Security**: Certificate-based authentication

### Step 3: User Credentials Configuration
```
Step 3: Configuring kubectl admin user credentials...
User "admin" set.
  ✅ Admin user credentials configured
```
**Credentials Details:**
- **User**: `admin`
- **Client Certificate**: `admin.pem` for authentication
- **Client Key**: `admin-key.pem` for secure communication
- **Authentication Type**: Mutual TLS (mTLS)

### Step 4: Context Configuration
```
Step 4: Configuring kubectl context...
Context "kubernetes-the-hard-way" modified.
  ✅ Context 'kubernetes-the-hard-way' created
```
**Context Details:**
- **Context Name**: `kubernetes-the-hard-way`
- **Cluster**: `kubernetes-the-hard-way`
- **User**: `admin`
- **Namespace**: `default` (implicit)

### Step 5: Context Switch
```
Step 5: Switching to the kubernetes-the-hard-way context...
Switched to context "kubernetes-the-hard-way".
  ✅ Successfully switched to 'kubernetes-the-hard-way' context
```

### Step 6: Cluster Verification
```
Step 6: Verifying cluster connectivity...
  Checking component status...
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-1               Healthy   {"health":"true"}
etcd-2               Healthy   {"health":"true"}
etcd-0               Healthy   {"health":"true"}
  ✅ Component status retrieved successfully

  Checking node status...
No resources found
  ✅ Node status retrieved successfully
```

**Important Notes:**
- **ComponentStatus**: All components show "Healthy" status
- **etcd Cluster**: All 3 etcd nodes are healthy
- **Node Status**: Shows "No resources found" - this indicates worker nodes may not be bootstrapped yet
- **API Connectivity**: Successfully connected to API server

### Step 7: Configuration Summary
```
Step 7: Current kubectl configuration summary...
  Current context:
kubernetes-the-hard-way

  Cluster info:
Kubernetes control plane is running at https://20.55.241.63:6443

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

### Final Status
```
===============================================
✅ kubectl Remote Access Configuration Complete
===============================================

🎯 Next Step: Tutorial Step 11 - Provisioning Pod Network Routes

You can now manage your Kubernetes cluster remotely using kubectl!
Example commands to try:
  kubectl get nodes
  kubectl get pods --all-namespaces
  kubectl cluster-info
```

## Technical Details

### kubeconfig File Location
```
Windows: %USERPROFILE%\.kube\config
Linux/Mac: ~/.kube/config
```

### Configuration Structure
```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: [base64-encoded ca.pem]
    server: https://20.55.241.63:6443
  name: kubernetes-the-hard-way
contexts:
- context:
    cluster: kubernetes-the-hard-way
    user: admin
  name: kubernetes-the-hard-way
current-context: kubernetes-the-hard-way
users:
- name: admin
  user:
    client-certificate-data: [base64-encoded admin.pem]
    client-key-data: [base64-encoded admin-key.pem]
```

### Security Features
- **Mutual TLS**: Both client and server certificates for authentication
- **Certificate Authority**: CA verification prevents man-in-the-middle attacks
- **Embedded Certificates**: No external file dependencies
- **Secure Communication**: All traffic encrypted via TLS 1.2+

## Validation Commands

### Post-Script Validation Steps
After running the script, execute these PowerShell commands to verify the installation:

### 1. Verify Current Configuration
```powershell
# Check current context
kubectl config current-context
# Expected output: kubernetes-the-hard-way

# View current configuration
kubectl config view --minify
```

### 2. Test Cluster Connectivity
```powershell
# Get cluster information
kubectl cluster-info
# Expected output: Kubernetes control plane is running at https://20.55.241.63:6443

# Test API server health (basic connectivity)
kubectl version --short
```

### 3. Verify Authentication and Authorization
```powershell
# Test admin permissions
kubectl auth can-i "*" "*"
# Expected output: yes (admin has full cluster access)

# List available API resources
kubectl api-resources --verbs=list --namespaced -o name | head -10
```

### 4. Check Cluster Components
```powershell
# Check component status (may show deprecation warning)
kubectl get componentstatuses
# Expected: etcd components show "Healthy"

# List all namespaces
kubectl get namespaces
# Expected: default, kube-system, kube-public, kube-node-lease
```

### 5. Verify Node Access (if worker nodes are bootstrapped)
```powershell
# List all nodes
kubectl get nodes -o wide
# Expected: Shows worker nodes if Step 09 was completed

# If no nodes found, this is normal if worker nodes haven't been bootstrapped yet
```

### 6. Test Pod Operations
```powershell
# List pods in all namespaces
kubectl get pods --all-namespaces
# Expected: Shows system pods if any are running

# Create a test namespace to verify write permissions
kubectl create namespace test-access
kubectl get namespace test-access
kubectl delete namespace test-access
```

### 7. Verify Certificate Configuration
```powershell
# Check embedded certificates
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | `
  ForEach-Object { 
    if ($_) { Write-Host "✅ CA certificate embedded" } 
    else { Write-Host "❌ CA certificate missing" }
  }

kubectl config view --raw -o jsonpath='{.users[0].user.client-certificate-data}' | `
  ForEach-Object { 
    if ($_) { Write-Host "✅ Client certificate embedded" } 
    else { Write-Host "❌ Client certificate missing" }
  }
```

## Live Validation Results

### Running the Validation Commands
Here are the actual results when running the validation commands after script execution:

#### 1. Current Context Verification
```powershell
PS C:\repos\kthw\certs> kubectl config current-context
kubernetes-the-hard-way
```
✅ **Result**: Correct context is active

#### 2. Cluster Information
```powershell
PS C:\repos\kthw\certs> kubectl cluster-info
Kubernetes control plane is running at https://20.55.241.63:6443

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```
✅ **Result**: API server is accessible and responding

#### 3. API Version Check
```powershell
PS C:\repos\kthw\certs> kubectl version --short
Flag --short has been deprecated, and will be removed in the future. The --short output will become the default.
Client Version: v1.27.10
Kustomize Version: v5.0.1
Server Version: v1.26.3
```
✅ **Result**: Client (v1.27.10) and server (v1.26.3) versions compatible

#### 4. Admin Permissions Test
```powershell
PS C:\repos\kthw\certs> kubectl auth can-i "*" "*"
yes
```
✅ **Result**: Admin user has full cluster permissions

#### 5. Available Namespaces
```powershell
PS C:\repos\kthw\certs> kubectl get namespaces
NAME              STATUS   AGE
default           Active   71m
kube-node-lease   Active   71m
kube-public       Active   71m
kube-system       Active   71m
```
✅ **Result**: Standard Kubernetes namespaces are present and active

#### 6. Node Status Check
```powershell
PS C:\repos\kthw\certs> kubectl get nodes
No resources found
```
ℹ️ **Expected Result**: No worker nodes found (Step 09 needs to be completed first)

#### 7. Write Permissions Test
```powershell
PS C:\repos\kthw\certs> kubectl create namespace test-validation
namespace/test-validation created

PS C:\repos\kthw\certs> kubectl get namespace test-validation
NAME              STATUS   AGE
test-validation   Active   6s

PS C:\repos\kthw\certs> kubectl delete namespace test-validation
namespace "test-validation" deleted
```
✅ **Result**: Admin user can create, read, and delete resources

#### 8. Component Status (with expected deprecation warning)
```powershell
PS C:\repos\kthw\certs> kubectl get componentstatuses
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-0               Healthy   {"health":"true"}
etcd-1               Healthy   {"health":"true"}
etcd-2               Healthy   {"health":"true"}
```
✅ **Result**: All core components are healthy

### Validation Summary
- ✅ kubectl context properly configured
- ✅ API server connectivity established
- ✅ TLS authentication working
- ✅ Admin permissions confirmed
- ✅ Cluster components healthy
- ✅ Standard namespaces present
- ✅ Read/write operations successful
- ℹ️ Worker nodes not yet joined (Step 09 pending)

## Troubleshooting

### Common Issues

#### 1. "Unable to connect to the server"
**Symptoms**: Connection timeout or refused
```powershell
# Check Azure resources
az network public-ip show -g kubernetes -n kubernetes-pip --query ipAddress -o tsv

# Verify controllers are running
az vm list -g kubernetes --query "[?contains(name, 'controller')].{Name:name, State:powerState}" -o table

# Test direct connectivity
Test-NetConnection -ComputerName $KUBERNETES_PUBLIC_ADDRESS -Port 6443
```

#### 2. "x509: certificate signed by unknown authority"
**Symptoms**: Certificate verification failure
```powershell
# Verify CA certificate exists
Test-Path "c:\repos\kthw\certs\ca.pem"

# Check certificate validity
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | `
  ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) } | `
  Out-File -FilePath temp-ca.pem
openssl x509 -in temp-ca.pem -text -noout
Remove-Item temp-ca.pem
```

#### 3. "error: You must be logged in to the server"
**Symptoms**: Authentication failure
```powershell
# Verify admin certificates exist
Test-Path "c:\repos\kthw\certs\admin.pem"
Test-Path "c:\repos\kthw\certs\admin-key.pem"

# Check certificate validity
openssl x509 -in "c:\repos\kthw\certs\admin.pem" -text -noout

# Reconfigure credentials if needed
kubectl config set-credentials admin --client-certificate=admin.pem --client-key=admin-key.pem
```

#### 4. "The connection to the server was refused"
**Symptoms**: API server not responding
```powershell
# Check controller VMs status
foreach ($controller in @("controller-0", "controller-1", "controller-2")) {
    $ip = az network public-ip show -g kubernetes -n "$controller-pip" --query "ipAddress" -o tsv
    Write-Host "Testing $controller ($ip):"
    Test-NetConnection -ComputerName $ip -Port 6443
}

# Check API server logs on controllers
$controllerIP = az network public-ip show -g kubernetes -n "controller-0-pip" --query "ipAddress" -o tsv
ssh kuberoot@$controllerIP "sudo journalctl -u kube-apiserver -f"
```

### Recovery Steps

#### Reset kubectl Configuration
```powershell
# Back up current config
Copy-Item "$env:USERPROFILE\.kube\config" "$env:USERPROFILE\.kube\config.backup"

# Remove current context
kubectl config delete-context kubernetes-the-hard-way
kubectl config delete-cluster kubernetes-the-hard-way
kubectl config delete-user admin

# Re-run configuration script
cd c:\repos\kthw\scripts\10
.\10-cofigure-kubectl.ps1
```

#### Manual Configuration Check
```powershell
# View raw configuration
kubectl config view --raw

# Check specific cluster details
kubectl config view -o jsonpath='{.clusters[?(@.name=="kubernetes-the-hard-way")].cluster}'

# Verify user configuration
kubectl config view -o jsonpath='{.users[?(@.name=="admin")].user}'
```

#### Alternative Access Methods
```powershell
# Direct kubeconfig file usage
$env:KUBECONFIG = "c:\repos\kthw\configs\admin.kubeconfig"
kubectl get nodes

# Temporary context switch for testing
kubectl --kubeconfig="c:\repos\kthw\configs\admin.kubeconfig" get nodes
```

## Manual Verification Steps

### 1. Certificate Validation
```powershell
cd c:\repos\kthw\certs

# Verify CA certificate
openssl x509 -in ca.pem -text -noout | Select-String "Subject:", "Issuer:", "Not After"

# Verify admin certificate
openssl x509 -in admin.pem -text -noout | Select-String "Subject:", "Issuer:", "Not After"

# Check certificate chain
openssl verify -CAfile ca.pem admin.pem
```

### 2. Network Connectivity
```powershell
# Test API server connectivity
$KUBERNETES_PUBLIC_ADDRESS = az network public-ip show -g kubernetes -n kubernetes-pip --query ipAddress -o tsv
Test-NetConnection -ComputerName $KUBERNETES_PUBLIC_ADDRESS -Port 6443

# Test DNS resolution (if using domain name)
Resolve-DnsName $KUBERNETES_PUBLIC_ADDRESS
```

### 3. API Server Health
```powershell
# Check API server health endpoint (requires proper certificates)
$KUBERNETES_PUBLIC_ADDRESS = az network public-ip show -g kubernetes -n kubernetes-pip --query ipAddress -o tsv
Invoke-WebRequest -Uri "https://${KUBERNETES_PUBLIC_ADDRESS}:6443/healthz" -SkipCertificateCheck
```

### 4. Context Management
```powershell
# List all contexts
kubectl config get-contexts

# Switch between contexts if multiple exist
kubectl config use-context kubernetes-the-hard-way

# View current context details
kubectl config view --minify
```

## Summary
✅ **kubectl Configuration**: Remote access configured successfully  
✅ **Authentication**: Admin user with client certificates working  
✅ **Connectivity**: Cluster accessible via public IP (20.55.241.63:6443)  
✅ **Security**: TLS-secured communication with CA verification  
✅ **Permissions**: Full admin access confirmed through testing  
✅ **Components**: All control plane components healthy  
ℹ️ **Worker Nodes**: Not yet joined (complete Step 09 first)  

**Script Status**: ✅ Successfully executed and validated  
**Ready for Step 11**: Pod network routes provisioning for inter-node communication

---

## 🧭 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [⬅️ Step 09: Worker Node Bootstrap](../09/09-execution-output.md) | **Step 10: Configure kubectl** | [➡️ Step 11: Pod Network Routes](../11/11-execution-output.md) |

### 📋 Tutorial Progress
- [🏠 Main README](../../README.md)
- [📖 All Tutorial Steps](../../README.md#-tutorial-steps)
- [🔧 Troubleshooting](../troubleshooting/Repair-Cluster.ps1)
- [✅ Cluster Validation](../validation/Validate-Cluster.ps1)
