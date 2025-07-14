# Tutorial Step 08: Bootstrapping the Kubernetes Control Plane - Execution Output

## Overview
This lab bootstraps the Kubernetes control plane across three compute instances and configures it for high availability with an external load balancer.

**Components Installed**: Kubernetes API Server, Scheduler, Controller Manager  
**Target**: High Availability Kubernetes Control Plane with Load Balancer  
**Script**: `08-bootstrapping-CP.ps1`

## Prerequisites Checklist
- ✅ Controller VMs deployed and accessible via SSH (Step 03)
- ✅ Certificate Authority and certificates created (Step 04) 
- ✅ Kubernetes configuration files generated (Step 05)
- ✅ Data encryption config created (Step 06)
- ✅ etcd cluster bootstrapped (Step 07)
- ✅ Azure CLI authenticated and configured

## Script Execution

### Command
```powershell
cd c:\repos\kthw\scripts\08
.\08-bootstrapping-CP.ps1
```

## Expected Results

### Step 1: Install Kubernetes Binaries
```
Step 1: Installing Kubernetes control plane binaries...
  Processing controller-0 (20.55.249.60)...
    ✅ controller-0: Binaries installed
  Processing controller-1 (172.210.248.242)...
    ✅ controller-1: Binaries installed
  Processing controller-2 (20.190.196.205)...
    ✅ controller-2: Binaries installed
```

### Step 2: Configure Services
```
Step 2: Configuring Kubernetes services...
  Configuring controller-0 (10.240.0.10)...
    ✅ controller-0: Services configured and started
  Configuring controller-1 (10.240.0.11)...
    ✅ controller-1: Services configured and started
  Configuring controller-2 (10.240.0.12)...
    ✅ controller-2: Services configured and started
```

### Step 3: RBAC Configuration
```
Step 3: Configuring RBAC for Kubelet Authorization...
  Applying RBAC configuration...
clusterrole.authorization.k8s.io/system:kube-apiserver-to-kubelet created
clusterrolebinding.authorization.k8s.io/system:kube-apiserver created
    ✅ RBAC configuration applied
```

### Step 4: Load Balancer Setup
```
Step 4: Configuring Kubernetes API Load Balancer...
  Creating health probe...
  Creating load balancer rule...
    ✅ Load balancer configured
```

### Step 5: Verification
```
Step 5: Verifying Kubernetes control plane...
  Checking component status...
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE   ERROR
scheduler            Healthy   ok        
controller-manager   Healthy   ok        
etcd-0               Healthy   ok        
etcd-1               Healthy   ok        
etcd-2               Healthy   ok        

  Testing API server via load balancer (20.55.241.63)...
    ✅ API server accessible via load balancer
    📋 Kubernetes version: v1.26.3

Checking service status on all controllers...
  ✅ controller-0: All services active
  ✅ controller-1: All services active
  ✅ controller-2: All services active
```

### Final Status
```
=============================================
✅ Kubernetes Control Plane Setup Complete
=============================================

🎯 Next Step: Tutorial Step 09 - Bootstrapping Kubernetes Worker Nodes
📍 Load Balancer Endpoint: https://20.55.241.63:6443
```

## Technical Details

### Installed Components
| Component | Version | Port | Configuration |
|-----------|---------|------|---------------|
| kube-apiserver | v1.26.3 | 6443 | HA with load balancer |
| kube-controller-manager | v1.26.3 | 10257 | Leader election enabled |
| kube-scheduler | v1.26.3 | 10259 | Leader election enabled |

### Network Configuration
- **Service Cluster IP Range**: 10.32.0.0/24
- **Pod Network CIDR**: 10.200.0.0/16
- **etcd Endpoints**: 10.240.0.10:2379, 10.240.0.11:2379, 10.240.0.12:2379
- **Load Balancer Public IP**: 20.55.241.63

### Service Files Created
- `/etc/systemd/system/kube-apiserver.service`
- `/etc/systemd/system/kube-controller-manager.service`
- `/etc/systemd/system/kube-scheduler.service`
- `/etc/kubernetes/config/kube-scheduler.yaml`

### Verification Commands
```bash
# Check component status
kubectl get componentstatuses --kubeconfig admin.kubeconfig

# Test API server via load balancer
curl -k https://20.55.241.63:6443/version

# Check service status
sudo systemctl status kube-apiserver kube-controller-manager kube-scheduler
```

## Troubleshooting

### Common Issues
1. **Services not starting**: Check systemd logs with `sudo journalctl -u kube-apiserver`
2. **API server unreachable**: Verify load balancer configuration and security groups
3. **Component unhealthy**: Check etcd cluster health and certificate validity

### Health Checks
```bash
# Service status
sudo systemctl is-active kube-apiserver kube-controller-manager kube-scheduler

# etcd cluster health
kubectl get componentstatuses --kubeconfig admin.kubeconfig

# Load balancer connectivity
curl -k https://20.55.241.63:6443/version
```

## Summary
✅ **Control Plane Status**: 3/3 controllers operational  
✅ **High Availability**: Load balancer distributing traffic  
✅ **Component Health**: All components healthy  
✅ **RBAC**: API server to kubelet authorization configured  

**Ready for Step 09**: Worker node bootstrap
Bootstrapping Kubernetes Control Plane
======================================

Step 1: Installing Kubernetes control plane binaries on all controller nodes...

Processing controller-0...
Public IP: 20.55.249.60
Downloading Kubernetes binaries...
✅ Download completed
Installing binaries...
✅ Installation completed
✅ Verified: Kubernetes v1.26.3

Processing controller-1...
Public IP: 172.210.248.242
Downloading Kubernetes binaries...
✅ Download completed
Installing binaries...
✅ Installation completed
✅ Verified: Kubernetes v1.26.3

Processing controller-2...
Public IP: 20.190.196.205
Downloading Kubernetes binaries...
✅ Download completed
Installing binaries...
✅ Installation completed
✅ Verified: Kubernetes v1.26.3

✅ Step 1 Complete: Kubernetes binaries installed on all controllers

Step 2: Configuring API Server on controller-0...
Configuring API Server on controller-0 (IP: 20.55.249.60, Internal: 10.240.0.10)...
Copying API Server service file...
✅ Service file copied
Installing API Server service...
✅ API Server service installed
✅ Step 2 Complete: API Server configured on controller-0

Step 3: Configuring Controller Manager and Scheduler on controller-0...
Copying Controller Manager service file...
✅ Controller Manager service configured
Copying Scheduler config file...
Copying Scheduler service file...
✅ Scheduler service configured
✅ Step 3 Complete: Controller Manager and Scheduler configured

Step 4: Starting Kubernetes control plane services on controller-0...
Created symlink /etc/systemd/system/multi-user.target.wants/kube-apiserver.service → /etc/systemd/system/kube-apiserver.service.
Created symlink /etc/systemd/system/multi-user.target.wants/kube-controller-manager.service → /etc/systemd/system/kube-controller-manager.service.
Created symlink /etc/systemd/system/multi-user.target.wants/kube-scheduler.service → /etc/systemd/system/kube-scheduler.service.
Services enabled
Services started
Service status: active
active
active

Step 5: Configuring RBAC for Kubelet Authorization...
Configuring RBAC on controller-0...
Copying ClusterRole YAML to controller-0...
Creating ClusterRole on controller-0...
Output: clusterrole.rbac.authorization.k8s.io/system:kube-apiserver-to-kubelet created
Copying ClusterRoleBinding YAML to controller-0...
Creating ClusterRoleBinding on controller-0...
Output: clusterrolebinding.rbac.authorization.k8s.io/system:kube-apiserver created

Step 6: Creating Kubernetes Frontend Load Balancer...
Creating load balancer health probe...
✅ Load balancer health probe created
Creating load balancer rule...
✅ Load balancer rule created

Step 7: Configuring remaining controllers (controller-1 and controller-2)...
Configuring controller-1 (172.210.248.242)...
Moving certificates...
✅ Files moved for controller-1
✅ Service files configured for controller-1
Starting services on controller-1...
Service status on controller-1: active active active
✅ controller-1 configured and running

Configuring controller-2 (20.190.196.205)...
Moving certificates...
✅ Files moved for controller-2
✅ Service files configured for controller-2
Starting services on controller-2...
Service status on controller-2: active active active
✅ controller-2 configured and running
✅ All controllers configured!

Step 8: Verifying Kubernetes control plane...
Checking component status...
NAME                 STATUS    MESSAGE             ERROR
scheduler            Healthy   ok
controller-manager   Healthy   ok
etcd-2               Healthy   {"health":"true"}
etcd-0               Healthy   {"health":"true"}
etcd-1               Healthy   {"health":"true"}
Warning: v1 ComponentStatus is deprecated in v1.19+

Verifying API server via load balancer...
Kubernetes public IP: 20.55.241.63
Testing API server accessibility...
✅ API server is accessible via load balancer
Version response: {
  "major": "1",
  "minor": "26",
  "gitVersion": "v1.26.3",
  "gitCommit": "9e644106593f3f4aa98f8a84b23db5fa378900bd",
  "gitTreeState": "clean",
  "buildDate": "2023-03-15T13:33:12Z",
  "goVersion": "go1.19.7",
  "compiler": "gc",
  "platform": "linux/amd64"
}

======================================
Kubernetes Control Plane Setup Complete
======================================

Next Step: Bootstrapping the Kubernetes Worker Nodes
```

## Execution Summary

### What the Script Accomplishes
1. **Downloaded and Installed Kubernetes v1.26.3**: Successfully installed control plane binaries on all 3 controller nodes
2. **Configured Kubernetes API Server**: Set up API server with proper certificates, etcd connection, and security policies
3. **Configured Controller Manager**: Set up cluster management with leader election and proper RBAC
4. **Configured Scheduler**: Set up pod scheduling with high availability configuration
5. **Started Control Plane Services**: All Kubernetes services running and healthy across all controllers
6. **Configured RBAC**: Set up proper authorization for API server to kubelet communication
7. **Created Load Balancer**: External load balancer configured for high availability API access
8. **Verified Control Plane**: All components healthy and API server accessible via load balancer

### Services Installation Status
- **Kubernetes Binary Installation**: ✅ Success on all 3 nodes
- **API Server Configuration**: ✅ Success on all 3 nodes
- **Controller Manager Configuration**: ✅ Success on all 3 nodes
- **Scheduler Configuration**: ✅ Success on all 3 nodes
- **Service Startup**: ✅ Success on all 3 nodes
- **RBAC Configuration**: ✅ Success
- **Load Balancer Setup**: ✅ Success
- **Control Plane Verification**: ✅ Success

### Key Configuration Details

#### API Server Configuration
- **Advertise Address**: Internal IP of each controller (10.240.0.10-12)
- **etcd Servers**: https://10.240.0.10:2379,https://10.240.0.11:2379,https://10.240.0.12:2379
- **Service Cluster IP Range**: 10.32.0.0/24
- **Service Node Port Range**: 30000-32767
- **Encryption**: Data encryption at rest enabled
- **Authorization**: Node and RBAC authorization modes
- **Admission Controllers**: NamespaceLifecycle, NodeRestriction, LimitRanger, ServiceAccount, DefaultStorageClass, ResourceQuota

#### Controller Manager Configuration
- **Cluster CIDR**: 10.200.0.0/16 (for pod networking)
- **Service Cluster IP Range**: 10.32.0.0/24
- **Leader Election**: Enabled for high availability
- **Service Account Management**: Enabled with proper key files

#### Scheduler Configuration
- **Configuration File**: /etc/kubernetes/config/kube-scheduler.yaml
- **Leader Election**: Enabled for high availability
- **Kubeconfig**: /var/lib/kubernetes/kube-scheduler.kubeconfig

#### Load Balancer Configuration
- **Health Probe**: Port 6443, TCP protocol
- **Load Balancer Rule**: Frontend port 6443 → Backend port 6443
- **Backend Pool**: kubernetes-lb-pool (includes all 3 controllers)

## Validation Steps

### 1. Verify Control Plane Components
```powershell
# Connect to any controller node and check component status
$controller0IP = az network public-ip show -g kubernetes -n controller-0-pip --query "ipAddress" -o tsv
ssh kuberoot@$controller0IP "kubectl get componentstatuses --kubeconfig admin.kubeconfig"

# Expected output:
# NAME                 STATUS    MESSAGE             ERROR
# scheduler            Healthy   ok
# controller-manager   Healthy   ok
# etcd-0               Healthy   {"health":"true"}
# etcd-1               Healthy   {"health":"true"}
# etcd-2               Healthy   {"health":"true"}
```

### 2. Verify Service Status on All Controllers
```powershell
# Check service status on each controller node
$controllers = @("controller-0", "controller-1", "controller-2")

foreach ($instance in $controllers) {
    $publicIP = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    Write-Host "Checking services on $instance ($publicIP)..." -ForegroundColor Yellow
    
    # Check if all services are active
    ssh kuberoot@$publicIP "sudo systemctl is-active kube-apiserver kube-controller-manager kube-scheduler"
    
    # Check service status details
    ssh kuberoot@$publicIP "sudo systemctl status kube-apiserver kube-controller-manager kube-scheduler --no-pager"
}
```

### 3. Test API Server via Load Balancer
```powershell
# Get the public IP of the Kubernetes load balancer
$kubernetesPublicIP = az network public-ip show -g kubernetes -n kubernetes-pip --query ipAddress -otsv
Write-Host "Kubernetes load balancer public IP: $kubernetesPublicIP"

# Test API server version endpoint
curl --cacert certs/ca.pem "https://${kubernetesPublicIP}:6443/version"

# Expected output:
# {
#   "major": "1",
#   "minor": "26",
#   "gitVersion": "v1.26.3",
#   "gitCommit": "9e644106593f3f4aa98f8a84b23db5fa378900bd",
#   "gitTreeState": "clean",
#   "buildDate": "2023-03-15T13:33:12Z",
#   "goVersion": "go1.19.7",
#   "compiler": "gc",
#   "platform": "linux/amd64"
# }
```

### 4. Verify Load Balancer Configuration
```powershell
# Check load balancer probe status
az network lb probe show -g kubernetes --lb-name kubernetes-lb --name kubernetes-apiserver-probe

# Check load balancer rule
az network lb rule show -g kubernetes --lb-name kubernetes-lb --name kubernetes-apiserver-rule

# Check backend pool members
az network lb address-pool show -g kubernetes --lb-name kubernetes-lb --name kubernetes-lb-pool
```

### 5. Test RBAC Configuration
```powershell
# Connect to controller-0 and test RBAC
$controller0IP = az network public-ip show -g kubernetes -n controller-0-pip --query "ipAddress" -o tsv

# Check ClusterRole
ssh kuberoot@$controller0IP "kubectl get clusterrole system:kube-apiserver-to-kubelet --kubeconfig admin.kubeconfig"

# Check ClusterRoleBinding  
ssh kuberoot@$controller0IP "kubectl get clusterrolebinding system:kube-apiserver --kubeconfig admin.kubeconfig"

# Test API server access to kubelet API (should work after worker nodes are set up)
# This will be testable after worker nodes are configured in the next tutorial step
```

### 6. Verify Certificate Configuration
```powershell
# Check that certificates are properly installed on each controller
$controllers = @("controller-0", "controller-1", "controller-2")

foreach ($instance in $controllers) {
    $publicIP = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    Write-Host "Checking certificates on $instance ($publicIP)..." -ForegroundColor Yellow
    
    # Check certificate files exist
    ssh kuberoot@$publicIP "sudo ls -la /var/lib/kubernetes/*.pem"
    
    # Verify certificate validity
    ssh kuberoot@$publicIP "sudo openssl x509 -in /var/lib/kubernetes/kubernetes.pem -noout -subject -dates"
}
```

### 7. Check Service Logs (if needed for troubleshooting)
```powershell
# Check service logs on any controller if there are issues
$controller0IP = az network public-ip show -g kubernetes -n controller-0-pip --query "ipAddress" -o tsv

# API Server logs
ssh kuberoot@$controller0IP "sudo journalctl -u kube-apiserver --no-pager | tail -20"

# Controller Manager logs
ssh kuberoot@$controller0IP "sudo journalctl -u kube-controller-manager --no-pager | tail -20"

# Scheduler logs
ssh kuberoot@$controller0IP "sudo journalctl -u kube-scheduler --no-pager | tail -20"
```

## Troubleshooting and Common Issues

### Issue 1: API Server Won't Start
**Symptoms**: `systemctl start kube-apiserver` fails
```powershell
# Check service logs for specific errors
ssh kuberoot@<controller-ip> "sudo journalctl -u kube-apiserver -f"

# Common solutions:
# 1. Verify etcd cluster is running
ssh kuberoot@<controller-ip> "sudo ETCDCTL_API=3 etcdctl endpoint health --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem"

# 2. Check certificate permissions
ssh kuberoot@<controller-ip> "sudo ls -la /var/lib/kubernetes/"

# 3. Verify encryption config
ssh kuberoot@<controller-ip> "sudo cat /var/lib/kubernetes/encryption-config.yaml"
```

### Issue 2: Controller Manager or Scheduler Won't Start
**Symptoms**: Controller Manager or Scheduler fails to start
```powershell
# Check kubeconfig files
ssh kuberoot@<controller-ip> "sudo ls -la /var/lib/kubernetes/*.kubeconfig"

# Verify kubeconfig content
ssh kuberoot@<controller-ip> "sudo cat /var/lib/kubernetes/kube-controller-manager.kubeconfig"

# Check if API server is accessible
ssh kuberoot@<controller-ip> "curl -k https://127.0.0.1:6443/version"
```

### Issue 3: Load Balancer Health Check Fails
**Symptoms**: Load balancer shows unhealthy backend instances
```powershell
# Check if API servers are listening on port 6443
foreach ($instance in @("controller-0", "controller-1", "controller-2")) {
    $ip = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    ssh kuberoot@$ip "sudo netstat -tlnp | grep :6443"
}

# Check Azure Load Balancer probe status
az network lb probe show -g kubernetes --lb-name kubernetes-lb --name kubernetes-apiserver-probe

# Test direct access to API server on each controller
foreach ($instance in @("controller-0", "controller-1", "controller-2")) {
    $ip = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    curl --cacert certs/ca.pem "https://$ip:6443/version"
}
```

### Issue 4: RBAC Permission Errors
**Symptoms**: API server cannot access kubelet API
```powershell
# Verify ClusterRole and ClusterRoleBinding were created
$controller0IP = az network public-ip show -g kubernetes -n controller-0-pip --query "ipAddress" -o tsv

ssh kuberoot@$controller0IP "kubectl get clusterrole system:kube-apiserver-to-kubelet --kubeconfig admin.kubeconfig -o yaml"
ssh kuberoot@$controller0IP "kubectl get clusterrolebinding system:kube-apiserver --kubeconfig admin.kubeconfig -o yaml"

# If missing, recreate RBAC objects:
ssh kuberoot@$controller0IP "kubectl apply --kubeconfig admin.kubeconfig -f /tmp/clusterrole.yaml"
ssh kuberoot@$controller0IP "kubectl apply --kubeconfig admin.kubeconfig -f /tmp/clusterrolebinding.yaml"
```

### Issue 5: Certificate Validation Errors  
**Symptoms**: TLS handshake failures in logs
```powershell
# Verify certificate files and permissions
ssh kuberoot@<controller-ip> "sudo ls -la /var/lib/kubernetes/*.pem"

# Check certificate subject alternative names
ssh kuberoot@<controller-ip> "sudo openssl x509 -in /var/lib/kubernetes/kubernetes.pem -text -noout | grep -A 5 'Subject Alternative Name'"

# Verify certificate chain
ssh kuberoot@<controller-ip> "sudo openssl verify -CAfile /var/lib/kubernetes/ca.pem /var/lib/kubernetes/kubernetes.pem"
```

## Network Configuration Verification

### Internal IP Addressing
- **controller-0**: 10.240.0.10
- **controller-1**: 10.240.0.11  
- **controller-2**: 10.240.0.12

### Service IP Ranges
- **Service Cluster IP Range**: 10.32.0.0/24
- **Pod Cluster CIDR**: 10.200.0.0/16
- **Service Node Port Range**: 30000-32767

### Load Balancer Configuration
- **Frontend IP**: Kubernetes public IP
- **Frontend Port**: 6443
- **Backend Pool**: All 3 controller nodes
- **Backend Port**: 6443
- **Health Probe**: TCP on port 6443

## ✅ Tutorial Step 08 - COMPLETED SUCCESSFULLY

**Final Status**: The Kubernetes control plane is now fully operational with high availability across all three controller nodes.

### What Was Achieved
- ✅ **Kubernetes v1.26.3 Installation**: Successfully installed on all 3 controller nodes
- ✅ **API Server Configuration**: Properly configured with etcd backend, encryption, and security policies
- ✅ **Controller Manager Setup**: High availability controller manager with leader election
- ✅ **Scheduler Configuration**: High availability scheduler with proper configuration
- ✅ **Service Management**: All systemd services running and healthy
- ✅ **RBAC Configuration**: Proper authorization for API server to kubelet communication
- ✅ **Load Balancer Setup**: External load balancer for high availability API access
- ✅ **End-to-End Verification**: API server accessible via load balancer with all components healthy

### Key Metrics
- **Kubernetes Version**: v1.26.3
- **Control Plane Nodes**: 3 (controller-0, controller-1, controller-2)
- **Service Cluster IP Range**: 10.32.0.0/24
- **Pod Network CIDR**: 10.200.0.0/16
- **Load Balancer**: External access via public IP
- **High Availability**: All components configured with leader election

The Kubernetes control plane is now ready to manage worker nodes and schedule workloads. The next step is to bootstrap the worker nodes to complete the cluster setup.

---
**Next Tutorial Step**: [09 - Bootstrapping the Kubernetes Worker Nodes](../09/09-bootstrapping-workernodes.ps1)
