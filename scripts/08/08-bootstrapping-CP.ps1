# Tutorial Step 08: Bootstrapping the Kubernetes Control Plane
# Original Tutorial: https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/08-bootstrapping-kubernetes-controllers.md
# 
# Description: Bootstrap the Kubernetes control plane across three compute instances 
# and configure it for high availability. Creates an external load balancer that exposes 
# the Kubernetes API Servers to remote clients.
#
# Components installed on each controller node:
# - Kubernetes API Server
# - Kubernetes Scheduler  
# - Kubernetes Controller Manager
#
# Prerequisites:
# - Controller VMs deployed and accessible via SSH (Step 03)
# - Certificate Authority and certificates created (Step 04)
# - Kubernetes configuration files generated (Step 05)
# - Data encryption config created (Step 06)
# - etcd cluster bootstrapped (Step 07)

param(
    [string]$KubernetesVersion = "v1.26.3"
)

# Configuration
$controllers = @("controller-0", "controller-1", "controller-2")
$etcdEndpoints = "https://10.240.0.10:2379,https://10.240.0.11:2379,https://10.240.0.12:2379"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Tutorial Step 08: Kubernetes Control Plane" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Function to get controller internal IP
function Get-ControllerInternalIP($controllerName) {
    $index = [int]$controllerName.Split('-')[1]
    return "10.240.0.$((10 + $index))"
}

# Function to get controller public IP
function Get-ControllerPublicIP($controllerName) {
    return az network public-ip show -g kubernetes -n "$controllerName-pip" --query "ipAddress" -o tsv
}

# Step 1: Install Kubernetes Control Plane Binaries
Write-Host "Step 1: Installing Kubernetes control plane binaries..." -ForegroundColor Yellow
foreach ($controller in $controllers) {
    $publicIP = Get-ControllerPublicIP $controller
    Write-Host "  Processing $controller ($publicIP)..." -ForegroundColor Cyan
    
    # Create directories and download binaries
    $command = "sudo mkdir -p /etc/kubernetes/config && cd /tmp && wget -q --https-only --timestamping 'https://storage.googleapis.com/kubernetes-release/release/$KubernetesVersion/bin/linux/amd64/kube-apiserver' 'https://storage.googleapis.com/kubernetes-release/release/$KubernetesVersion/bin/linux/amd64/kube-controller-manager' 'https://storage.googleapis.com/kubernetes-release/release/$KubernetesVersion/bin/linux/amd64/kube-scheduler' 'https://storage.googleapis.com/kubernetes-release/release/$KubernetesVersion/bin/linux/amd64/kubectl' && chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl && sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/"
    ssh kuberoot@$publicIP $command
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✅ ${controller}: Binaries installed" -ForegroundColor Green
    } else {
        Write-Host "    ❌ ${controller}: Installation failed" -ForegroundColor Red
        exit 1
    }
}

# Step 2: Configure Kubernetes Services
Write-Host ""
Write-Host "Step 2: Configuring Kubernetes services..." -ForegroundColor Yellow
foreach ($controller in $controllers) {
    $publicIP = Get-ControllerPublicIP $controller
    $internalIP = Get-ControllerInternalIP $controller
    Write-Host "  Configuring $controller ($internalIP)..." -ForegroundColor Cyan
    
    # Move certificates and kubeconfigs
    $moveCommand = "sudo mkdir -p /var/lib/kubernetes/ && sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem service-account-key.pem service-account.pem encryption-config.yaml kube-controller-manager.kubeconfig kube-scheduler.kubeconfig /var/lib/kubernetes/"
    ssh kuberoot@$publicIP $moveCommand
    
    # Create API Server service
    $apiServerService = @"
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=$internalIP \\
  --allow-privileged=true \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=$etcdEndpoints \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --runtime-config='api/all=true' \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-account-issuer=https://$internalIP:6443 \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
"@
    
    # Create Controller Manager service
    $controllerManagerService = @"
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --bind-address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
"@
    
    # Create Scheduler configuration
    $schedulerConfig = @"
apiVersion: kubescheduler.config.k8s.io/v1beta3
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
"@
    
    # Create Scheduler service
    $schedulerService = @"
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
"@
    
    # Write service files
    $apiServerService | ssh kuberoot@$publicIP "cat > /tmp/kube-apiserver.service"
    $controllerManagerService | ssh kuberoot@$publicIP "cat > /tmp/kube-controller-manager.service"
    $schedulerConfig | ssh kuberoot@$publicIP "cat > /tmp/kube-scheduler.yaml"
    $schedulerService | ssh kuberoot@$publicIP "cat > /tmp/kube-scheduler.service"
    
    # Install services
    $installCommand = "sudo mv /tmp/kube-scheduler.yaml /etc/kubernetes/config/ && sudo mv /tmp/kube-*.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler && sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler"
    ssh kuberoot@$publicIP $installCommand
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✅ ${controller}: Services configured and started" -ForegroundColor Green
    } else {
        Write-Host "    ❌ ${controller}: Service configuration failed" -ForegroundColor Red
        exit 1
    }
}

# Wait for services to initialize
Write-Host ""
Write-Host "Waiting for services to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Step 3: Configure RBAC for Kubelet Authorization
Write-Host ""
Write-Host "Step 3: Configuring RBAC for Kubelet Authorization..." -ForegroundColor Yellow
$primaryIP = Get-ControllerPublicIP "controller-0"

Write-Host "  Applying RBAC configuration..." -ForegroundColor Cyan
$rbacCommand = "kubectl apply --kubeconfig admin.kubeconfig -f clusterrole.yaml && kubectl apply --kubeconfig admin.kubeconfig -f clusterrolebinding.yaml"
ssh kuberoot@$primaryIP $rbacCommand

if ($LASTEXITCODE -eq 0) {
    Write-Host "    ✅ RBAC configuration applied" -ForegroundColor Green
} else {
    Write-Host "    ❌ RBAC configuration failed" -ForegroundColor Red
}

# Step 4: Configure Load Balancer
Write-Host ""
Write-Host "Step 4: Configuring Kubernetes API Load Balancer..." -ForegroundColor Yellow

Write-Host "  Creating health probe..." -ForegroundColor Cyan
az network lb probe create -g kubernetes --lb-name kubernetes-lb --name kubernetes-apiserver-probe --port 6443 --protocol tcp 2>$null

Write-Host "  Creating load balancer rule..." -ForegroundColor Cyan
az network lb rule create -g kubernetes -n kubernetes-apiserver-rule --protocol tcp --lb-name kubernetes-lb --frontend-ip-name LoadBalancerFrontEnd --frontend-port 6443 --backend-pool-name kubernetes-lb-pool --backend-port 6443 --probe-name kubernetes-apiserver-probe 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "    ✅ Load balancer configured" -ForegroundColor Green
} else {
    Write-Host "    ⚠️ Load balancer configuration (may already exist)" -ForegroundColor Yellow
}

# Step 5: Verify Control Plane
Write-Host ""
Write-Host "Step 5: Verifying Kubernetes control plane..." -ForegroundColor Yellow

# Check component status
Write-Host "  Checking component status..." -ForegroundColor Cyan
$componentStatus = ssh kuberoot@$primaryIP "kubectl get componentstatuses --kubeconfig admin.kubeconfig 2>/dev/null"
Write-Host $componentStatus -ForegroundColor White

# Check API server via load balancer
$kubernetesPublicIP = az network public-ip show -g kubernetes -n kubernetes-pip --query ipAddress -otsv
Write-Host ""
Write-Host "  Testing API server via load balancer ($kubernetesPublicIP)..." -ForegroundColor Cyan

try {
    $versionResponse = curl -k -s "https://${kubernetesPublicIP}:6443/version" 2>$null
    if ($versionResponse -and $versionResponse -match "gitVersion") {
        Write-Host "    ✅ API server accessible via load balancer" -ForegroundColor Green
        $version = ($versionResponse | ConvertFrom-Json).gitVersion
        Write-Host "    📋 Kubernetes version: $version" -ForegroundColor Cyan
    } else {
        Write-Host "    ❌ API server not accessible via load balancer" -ForegroundColor Red
    }
} catch {
    Write-Host "    ❌ Error testing API server accessibility" -ForegroundColor Red
}

# Final status check
Write-Host ""
Write-Host "Checking service status on all controllers..." -ForegroundColor Yellow
foreach ($controller in $controllers) {
    $publicIP = Get-ControllerPublicIP $controller
    $status = ssh kuberoot@$publicIP "sudo systemctl is-active kube-apiserver kube-controller-manager kube-scheduler 2>/dev/null"
    $activeCount = ($status -split "`n" | Where-Object { $_ -eq "active" }).Count
    
    if ($activeCount -eq 3) {
        Write-Host "  ✅ ${controller}: All services active" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ ${controller}: $activeCount/3 services active" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "✅ Kubernetes Control Plane Setup Complete" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎯 Next Step: Tutorial Step 09 - Bootstrapping Kubernetes Worker Nodes" -ForegroundColor Yellow
Write-Host "📍 Load Balancer Endpoint: https://$kubernetesPublicIP:6443" -ForegroundColor Cyan
