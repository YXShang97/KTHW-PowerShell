# Tutorial Step 09: Bootstrapping the Kubernetes Worker Nodes - Execution Output

## Overview
Bootstrap two Kubernetes worker nodes with all required components for a fully functional cluster.

**Components**: runc, CNI plugins, containerd, kubelet, kube-proxy  
**Target**: Two operational worker nodes joining the cluster  
**Script**: `09-bootstrapping-workernodes.ps1`

## Prerequisites Checklist
- ✅ Worker VMs deployed and SSH accessible (Step 03)
- ✅ Certificates and kubeconfigs distributed (Steps 04-05)
- ✅ etcd cluster operational (Step 07)
- ✅ Control plane operational (Step 08)

## Script Execution

### Command
```powershell
cd c:\repos\kthw\scripts\09
.\09-bootstrapping-workernodes.ps1
```

## Expected Results

### Step 1: OS Dependencies
```
Step 1: Installing OS dependencies on worker nodes...
  Processing worker-0 (20.55.249.60)...
    ✅ worker-0: OS dependencies installed
  Processing worker-1 (172.210.248.242)...
    ✅ worker-1: OS dependencies installed
```
**Installs**: socat (kubectl port-forward), conntrack, ipset

### Step 2: Worker Binaries
```
Step 2: Downloading and installing worker binaries...
  Processing worker-0 (20.55.249.60)...
    ✅ worker-0: Binaries downloaded
    ✅ worker-0: Binaries installed
  Processing worker-1 (172.210.248.242)...
    ✅ worker-1: Binaries downloaded
    ✅ worker-1: Binaries installed
```

**Components Installed**:
| Binary | Version | Location | Purpose |
|--------|---------|----------|---------|
| crictl | v1.26.1 | /usr/local/bin | Container runtime CLI |
| runsc | latest | /usr/local/bin | gVisor secure runtime |
| runc | v1.1.5 | /usr/local/bin | OCI container runtime |
| containerd | v1.7.0 | /bin | Container runtime daemon |
| kubectl | v1.26.3 | /usr/local/bin | Kubernetes CLI |
| kube-proxy | v1.26.3 | /usr/local/bin | Network proxy |
| kubelet | v1.26.3 | /usr/local/bin | Node agent |
| CNI plugins | v1.2.0 | /opt/cni/bin | Network plugins |

### Step 3: CNI Networking
```
Step 3: Configuring CNI networking...
  Configuring CNI on worker-0...
    ✅ worker-0: CNI networking configured
  Configuring CNI on worker-1...
    ✅ worker-1: CNI networking configured
```
**Networks**: Bridge (cnio0) + Loopback, Pod CIDRs from Azure VM tags

### Step 4: containerd Configuration
```
Step 4: Configuring containerd...
  Configuring containerd on worker-0...
    ✅ worker-0: containerd configured
  Configuring containerd on worker-1...
    ✅ worker-1: containerd configured
```
**Features**: overlayfs, runc default, runsc for untrusted workloads

### Step 5: Kubelet Configuration
```
Step 5: Configuring Kubelet...
  Configuring Kubelet on worker-0...
    ✅ worker-0: Kubelet configured
  Configuring Kubelet on worker-1...
    ✅ worker-1: Kubelet configured
```
**Config**: Webhook auth, containerd CRI, node-specific certificates

### Step 6: Kube-Proxy Configuration
```
Step 6: Configuring Kube-Proxy...
  Configuring Kube-Proxy on worker-0...
    ✅ worker-0: Kube-Proxy configured
  Configuring Kube-Proxy on worker-1...
    ✅ worker-1: Kube-Proxy configured
```
**Mode**: iptables, Cluster CIDR: 10.200.0.0/16

### Step 7: Service Startup
```
Step 7: Starting worker services...
  Starting services on worker-0...
    ✅ worker-0: Services started
    Waiting for services to initialize...
    ✅ worker-0: All services active (3/3)
  Starting services on worker-1...
    ✅ worker-1: Services started
    Waiting for services to initialize...
    ✅ worker-1: All services active (3/3)
```

### Step 8: Verification
```
Step 8: Verifying worker node registration...
  Waiting for nodes to register...
  Checking node registration from controller-0...
NAME       STATUS   ROLES    AGE   VERSION
worker-0   Ready    <none>   26s   v1.26.3
worker-1   Ready    <none>   23s   v1.26.3

✅ Both worker nodes successfully registered and ready!
```

## Technical Architecture

### Network Layout
```
Control Plane:  10.240.0.10-12 (API servers)
Worker Nodes:   10.240.0.20-21 (kubelet + pods)
Pod Networks:   10.200.0.0/24 (worker-0), 10.200.1.0/24 (worker-1)
Service CIDR:   10.32.0.0/24 (cluster services)
```

### Service Stack
```
kubelet ← containerd ← runc/runsc
   ↓
kube-proxy ← iptables rules
   ↓
CNI bridge ← pod networking
```

## Validation Commands

### Check Node Status
```powershell
# From controller
$controllerIP = az network public-ip show -g kubernetes -n "controller-0-pip" --query "ipAddress" -o tsv
ssh kuberoot@$controllerIP "kubectl get nodes --kubeconfig admin.kubeconfig -o wide"
```

### Verify Services
```powershell
# Check each worker
foreach ($worker in @("worker-0", "worker-1")) {
    $ip = az network public-ip show -g kubernetes -n "$worker-pip" --query "ipAddress" -o tsv
    ssh kuberoot@$ip "sudo systemctl status containerd kubelet kube-proxy --no-pager"
}
```

### Test Pod Scheduling
```powershell
# SSH to controller and create test pod
ssh kuberoot@$controllerIP @"
kubectl run test-nginx --image=nginx --kubeconfig admin.kubeconfig
kubectl get pods -o wide --kubeconfig admin.kubeconfig
kubectl delete pod test-nginx --kubeconfig admin.kubeconfig
"@
```

### Network Verification
```powershell
# Check CNI setup
ssh kuberoot@$workerIP "ip addr show cnio0"
ssh kuberoot@$workerIP "ls -la /opt/cni/bin/"
```

## Troubleshooting

### Common Issues

#### 1. Node Not Joining
- **Check**: kubelet logs `sudo journalctl -u kubelet -f`
- **Verify**: certificates in `/var/lib/kubelet/`
- **Test**: API server connectivity from worker

#### 2. Pod Scheduling Issues
- **Check**: containerd status `sudo systemctl status containerd`
- **Verify**: CNI configuration in `/etc/cni/net.d/`
- **Test**: container runtime `sudo crictl version`

#### 3. Network Problems
- **Check**: kube-proxy logs `sudo journalctl -u kube-proxy -f`
- **Verify**: iptables rules `sudo iptables -t nat -L`
- **Test**: bridge interface `ip addr show cnio0`

### Health Check Script
```powershell
function Test-WorkerNode($workerName) {
    $ip = az network public-ip show -g kubernetes -n "$workerName-pip" --query "ipAddress" -o tsv
    Write-Host "=== $workerName Health Check ==="
    
    # Service status
    ssh kuberoot@$ip "sudo systemctl is-active containerd kubelet kube-proxy"
    
    # Runtime check
    ssh kuberoot@$ip "sudo crictl version"
    
    # Network test
    ssh kuberoot@$ip "ping -c 1 10.240.0.10"  # Control plane
}

Test-WorkerNode "worker-0"
Test-WorkerNode "worker-1"
```

## Summary
✅ **Worker Status**: 2/2 nodes operational and cluster-joined  
✅ **Runtime**: containerd with runc/runsc support  
✅ **Networking**: CNI bridge with pod CIDR allocation  
✅ **Services**: kubelet, kube-proxy, containerd active  

**Ready for Step 10**: kubectl remote access configuration

## Technical Details

### Network Architecture
```
Controller Plane: 10.240.0.10-12 (etcd + API servers)
Worker Nodes:     10.240.0.20-21 (kubelet + containers)
Pod Networks:     10.200.0.0/24 (worker-0), 10.200.1.0/24 (worker-1)
Service Network:  10.32.0.0/24 (cluster services)
```

### Security Features
- **Node Authentication**: x509 certificates for each worker
- **Container Isolation**: runc for standard, runsc (gVisor) for untrusted workloads
- **Network Security**: CNI with proper CIDR allocation
- **API Authorization**: Webhook-based authorization through control plane

### Service Dependencies
```
containerd ← kubelet ← kube-proxy
     ↑
   CNI plugins
```

## Validation Commands

### Manual Verification Steps

#### 1. Check Node Status from Control Plane
```powershell
# Get controller public IP
$controllerIP = az network public-ip show -g kubernetes -n "controller-0-pip" --query "ipAddress" -o tsv

# SSH to controller and check nodes
ssh kuberoot@$controllerIP "kubectl get nodes --kubeconfig admin.kubeconfig -o wide"
```

#### 2. Verify Worker Node Services
```powershell
# Check each worker node
$workers = @("worker-0", "worker-1")
foreach ($worker in $workers) {
    $workerIP = az network public-ip show -g kubernetes -n "$worker-pip" --query "ipAddress" -o tsv
    Write-Host "Checking $worker ($workerIP):"
    
    # Check service status
    ssh kuberoot@$workerIP "sudo systemctl status containerd kubelet kube-proxy --no-pager -l"
    
    # Check kubelet logs
    ssh kuberoot@$workerIP "sudo journalctl -u kubelet --no-pager -l --since '10 minutes ago'"
}
```

#### 3. Test Pod Scheduling
```powershell
# SSH to controller
$controllerIP = az network public-ip show -g kubernetes -n "controller-0-pip" --query "ipAddress" -o tsv
ssh kuberoot@$controllerIP

# Create test pod
kubectl run test-pod --image=nginx --kubeconfig admin.kubeconfig

# Check pod placement
kubectl get pods -o wide --kubeconfig admin.kubeconfig

# Clean up
kubectl delete pod test-pod --kubeconfig admin.kubeconfig
```

#### 4. Verify Container Runtime
```powershell
# Check containerd
ssh kuberoot@$workerIP "sudo crictl version"
ssh kuberoot@$workerIP "sudo crictl images"

# Check runc
ssh kuberoot@$workerIP "sudo runc --version"

# Check CNI
ssh kuberoot@$workerIP "sudo ls -la /opt/cni/bin/"
```

#### 5. Network Connectivity Test
```powershell
# From controller, test worker connectivity
ssh kuberoot@$controllerIP "ping -c 3 10.240.0.20"  # worker-0
ssh kuberoot@$controllerIP "ping -c 3 10.240.0.21"  # worker-1

# Check CNI bridge on workers
ssh kuberoot@$workerIP "ip addr show cnio0"
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Worker Nodes Not Joining Cluster
**Symptoms**: Nodes don't appear in `kubectl get nodes`
**Diagnosis**:
```powershell
# Check kubelet logs
ssh kuberoot@$workerIP "sudo journalctl -u kubelet -f"

# Check kubelet status
ssh kuberoot@$workerIP "sudo systemctl status kubelet"
```
**Solutions**:
- Verify certificates are in correct locations
- Check kubeconfig file permissions
- Ensure control plane is accessible from workers

#### 2. Pods Stuck in Pending State
**Symptoms**: Pods scheduled but not running
**Diagnosis**:
```powershell
# Check pod events
kubectl describe pod <pod-name> --kubeconfig admin.kubeconfig

# Check containerd
ssh kuberoot@$workerIP "sudo systemctl status containerd"
```
**Solutions**:
- Restart containerd service
- Check container image availability
- Verify CNI configuration

#### 3. Network Connectivity Issues
**Symptoms**: Pods can't reach services or external networks
**Diagnosis**:
```powershell
# Check CNI configuration
ssh kuberoot@$workerIP "sudo ls -la /etc/cni/net.d/"

# Check bridge interface
ssh kuberoot@$workerIP "ip addr show cnio0"

# Check iptables rules
ssh kuberoot@$workerIP "sudo iptables -t nat -L"
```
**Solutions**:
- Verify CNI plugin installation
- Check bridge network configuration
- Restart kube-proxy service

#### 4. Certificate Issues
**Symptoms**: Authentication failures in logs
**Diagnosis**:
```powershell
# Check certificate validity
ssh kuberoot@$workerIP "sudo openssl x509 -in /var/lib/kubelet/worker-0.pem -text -noout"

# Check kubeconfig
ssh kuberoot@$workerIP "sudo cat /var/lib/kubelet/kubeconfig"
```
**Solutions**:
- Regenerate worker certificates if expired
- Verify certificate subject matches hostname
- Check CA certificate consistency

### Health Check Commands
```powershell
# Complete worker health check
function Test-WorkerHealth($workerName) {
    $workerIP = az network public-ip show -g kubernetes -n "$workerName-pip" --query "ipAddress" -o tsv
    
    Write-Host "=== Health Check: $workerName ==="
    
    # Service status
    ssh kuberoot@$workerIP "sudo systemctl is-active containerd kubelet kube-proxy"
    
    # Runtime health
    ssh kuberoot@$workerIP "sudo crictl version"
    
    # Network connectivity
    ssh kuberoot@$workerIP "ping -c 1 10.240.0.10"  # Controller
    
    # Certificate validity
    ssh kuberoot@$workerIP "sudo openssl x509 -in /var/lib/kubelet/$workerName.pem -checkend 86400 -noout"
}

# Run health checks
Test-WorkerHealth "worker-0"
Test-WorkerHealth "worker-1"
```

## ACTUAL EXECUTION RESULTS - COMPLETED SUCCESSFULLY ✅

**Date:** 2025-07-15 15:02:42  
**Status:** ✅ COMPLETED SUCCESSFULLY  
**Duration:** ~3 minutes

### Final Verification
```
NAME       STATUS   ROLES    AGE   VERSION
worker-0   Ready    <none>   62s   v1.26.3
worker-1   Ready    <none>   45s   v1.26.3
```

### Issues Resolved During Execution
1. **Containerd Version Issue**: Updated from v1.7.0 to v1.6.20 due to download URL availability
2. **PowerShell Here-String Line Endings**: Split long download commands into batches
3. **All Services Active**: containerd, kubelet, and kube-proxy running on both workers

### Infrastructure Status
- ✅ 3 Controller nodes operational (etcd + control plane)
- ✅ 2 Worker nodes registered and ready
- ✅ Complete Kubernetes cluster operational
- ✅ Ready for workload deployment

**Next Step**: Tutorial Step 10 - Configuring kubectl for Remote Access

---

## 🧭 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [⬅️ Step 08: Control Plane Bootstrap](../08/08-execution-output.md) | **Step 09: Worker Node Bootstrap** | [➡️ Step 10: Configure kubectl](../10/10-execution-output.md) |
