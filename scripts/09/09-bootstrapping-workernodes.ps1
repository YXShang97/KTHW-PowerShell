# Tutorial Step 09: Bootstrapping the Kubernetes Worker Nodes
# Original Tutorial: https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/09-bootstrapping-kubernetes-workers.md
# 
# Description: Bootstrap two Kubernetes worker nodes with runc, container networking plugins, 
# cri-containerd, kubelet, and kube-proxy.
#
# Prerequisites:
# - Worker VMs deployed and accessible via SSH (Step 03)
# - Certificate Authority and certificates created (Step 04)
# - Kubernetes configuration files generated (Step 05)
# - Data encryption config created (Step 06)
# - etcd cluster bootstrapped (Step 07)
# - Control plane bootstrapped (Step 08)

param(
    [string]$KubernetesVersion = "v1.26.3",
    [string]$CriToolsVersion = "v1.26.1",
    [string]$RuncVersion = "v1.1.5",
    [string]$CniPluginsVersion = "v1.2.0",
    [string]$ContainerdVersion = "1.6.20"
)

$workers = @("worker-0", "worker-1")

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Tutorial Step 09: Kubernetes Worker Nodes" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Helper functions
function Get-WorkerPublicIP($workerName) {
    return az network public-ip show -g kubernetes -n "$workerName-pip" --query "ipAddress" -o tsv
}

function New-RemoteConfigFile($publicIP, $content, $remotePath) {
    $tempFile = [System.IO.Path]::GetTempFileName()
    $content | Out-File -FilePath $tempFile -Encoding UTF8
    scp $tempFile kuberoot@$publicIP`:/tmp/config_temp 2>$null
    ssh kuberoot@$publicIP "sudo mv /tmp/config_temp $remotePath"
    Remove-Item $tempFile
}

# Step 1: Install OS Dependencies
Write-Host "Step 1: Installing OS dependencies on worker nodes..." -ForegroundColor Yellow
foreach ($worker in $workers) {
    $publicIP = Get-WorkerPublicIP $worker
    Write-Host "  Processing $worker ($publicIP)..." -ForegroundColor Cyan
    
    # Install required OS packages
    ssh kuberoot@$publicIP "sudo apt-get update >/dev/null 2>&1 && sudo apt-get -y install socat conntrack ipset >/dev/null 2>&1"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✅ ${worker}: OS dependencies installed" -ForegroundColor Green
    } else {
        Write-Host "    ❌ ${worker}: OS dependency installation failed" -ForegroundColor Red
        exit 1
    }
}

# Step 2: Download and Install Worker Binaries
Write-Host ""
Write-Host "Step 2: Downloading and installing worker binaries..." -ForegroundColor Yellow
foreach ($worker in $workers) {
    $publicIP = Get-WorkerPublicIP $worker
    Write-Host "  Processing $worker ($publicIP)..." -ForegroundColor Cyan
    
    # Download worker binaries (split into batches to avoid command line length issues)
    $downloadCmd1 = "cd /tmp && wget -q --https-only --timestamping https://github.com/kubernetes-sigs/cri-tools/releases/download/$CriToolsVersion/crictl-$CriToolsVersion-linux-amd64.tar.gz https://storage.googleapis.com/gvisor/releases/nightly/latest/runsc https://github.com/opencontainers/runc/releases/download/$RuncVersion/runc.amd64"
    $downloadCmd2 = "cd /tmp && wget -q --https-only --timestamping https://github.com/containernetworking/plugins/releases/download/$CniPluginsVersion/cni-plugins-linux-amd64-$CniPluginsVersion.tgz https://github.com/containerd/containerd/releases/download/v$ContainerdVersion/containerd-$ContainerdVersion-linux-amd64.tar.gz"
    $downloadCmd3 = "cd /tmp && wget -q --https-only --timestamping https://storage.googleapis.com/kubernetes-release/release/$KubernetesVersion/bin/linux/amd64/kubectl https://storage.googleapis.com/kubernetes-release/release/$KubernetesVersion/bin/linux/amd64/kube-proxy https://storage.googleapis.com/kubernetes-release/release/$KubernetesVersion/bin/linux/amd64/kubelet"
    
    ssh kuberoot@$publicIP $downloadCmd1
    if ($LASTEXITCODE -ne 0) { Write-Host "    ❌ ${worker}: Binary download batch 1 failed" -ForegroundColor Red; exit 1 }
    ssh kuberoot@$publicIP $downloadCmd2
    if ($LASTEXITCODE -ne 0) { Write-Host "    ❌ ${worker}: Binary download batch 2 failed" -ForegroundColor Red; exit 1 }
    ssh kuberoot@$publicIP $downloadCmd3
    if ($LASTEXITCODE -ne 0) { Write-Host "    ❌ ${worker}: Binary download batch 3 failed" -ForegroundColor Red; exit 1 }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✅ ${worker}: Binaries downloaded" -ForegroundColor Green
    } else {
        Write-Host "    ❌ ${worker}: Binary download failed" -ForegroundColor Red
        exit 1
    }
    
    # Create installation directories and install binaries
    $installCmd = "sudo mkdir -p /etc/cni/net.d /opt/cni/bin /var/lib/kubelet /var/lib/kube-proxy /var/lib/kubernetes /var/run/kubernetes && cd /tmp && mkdir -p containerd && sudo mv runc.amd64 runc && chmod +x kubectl kube-proxy kubelet runc runsc && sudo mv kubectl kube-proxy kubelet runc runsc /usr/local/bin/ && sudo tar -xf crictl-$CriToolsVersion-linux-amd64.tar.gz -C /usr/local/bin/ 2>/dev/null && sudo tar -xf cni-plugins-linux-amd64-$CniPluginsVersion.tgz -C /opt/cni/bin/ 2>/dev/null && sudo tar -xf containerd-$ContainerdVersion-linux-amd64.tar.gz -C containerd 2>/dev/null && sudo mv containerd/bin/* /bin/"
    ssh kuberoot@$publicIP $installCmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✅ ${worker}: Binaries installed" -ForegroundColor Green
    } else {
        Write-Host "    ❌ ${worker}: Binary installation failed" -ForegroundColor Red
        exit 1
    }
}

# Step 3: Configure CNI Networking
Write-Host ""
Write-Host "Step 3: Configuring CNI networking..." -ForegroundColor Yellow
foreach ($worker in $workers) {
    $publicIP = Get-WorkerPublicIP $worker
    Write-Host "  Configuring CNI on $worker..." -ForegroundColor Cyan
    
    # Get POD_CIDR for this worker node
    $podCidr = ssh kuberoot@$publicIP "curl --silent -H Metadata:true 'http://169.254.169.254/metadata/instance/compute/tags?api-version=2017-08-01&format=text' | sed 's/\;/\n/g' | grep pod-cidr | cut -d : -f2"
    
    # Create bridge network config
    $bridgeConfig = @"
{
    "cniVersion": "0.4.0",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "$podCidr"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
"@
    
    # Create loopback config
    $loopbackConfig = @"
{
    "cniVersion": "0.4.0",
    "name": "lo",
    "type": "loopback"
}
"@
    
    New-RemoteConfigFile $publicIP $bridgeConfig "/etc/cni/net.d/10-bridge.conf"
    New-RemoteConfigFile $publicIP $loopbackConfig "/etc/cni/net.d/99-loopback.conf"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✅ ${worker}: CNI networking configured" -ForegroundColor Green
    } else {
        Write-Host "    ❌ ${worker}: CNI configuration failed" -ForegroundColor Red
    }
}

# Step 4: Configure containerd
Write-Host ""
Write-Host "Step 4: Configuring containerd..." -ForegroundColor Yellow
foreach ($worker in $workers) {
    $publicIP = Get-WorkerPublicIP $worker
    Write-Host "  Configuring containerd on $worker..." -ForegroundColor Cyan
    
    # Create containerd configuration
    $containerdConfig = @"
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
    [plugins.cri.containerd.untrusted_workload_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runsc"
      runtime_root = "/run/containerd/runsc"
    [plugins.cri.containerd.gvisor]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runsc"
      runtime_root = "/run/containerd/runsc"
"@
    
    # Create containerd systemd service
    $containerdService = @"
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd

Delegate=yes
KillMode=process
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
TasksMax=infinity

[Install]
WantedBy=multi-user.target
"@
    
    ssh kuberoot@$publicIP "sudo mkdir -p /etc/containerd/" 2>$null
    New-RemoteConfigFile $publicIP $containerdConfig "/etc/containerd/config.toml"
    New-RemoteConfigFile $publicIP $containerdService "/etc/systemd/system/containerd.service"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✅ ${worker}: containerd configured" -ForegroundColor Green
    } else {
        Write-Host "    ❌ ${worker}: containerd configuration failed" -ForegroundColor Red
    }
}

# Step 5: Configure Kubelet
Write-Host ""
Write-Host "Step 5: Configuring Kubelet..." -ForegroundColor Yellow
foreach ($worker in $workers) {
    $publicIP = Get-WorkerPublicIP $worker
    Write-Host "  Configuring Kubelet on $worker..." -ForegroundColor Cyan
    
    # Move certificates and kubeconfig
    ssh kuberoot@$publicIP "sudo mv $worker-key.pem $worker.pem /var/lib/kubelet/ && sudo mv $worker.kubeconfig /var/lib/kubelet/kubeconfig && sudo mv ca.pem /var/lib/kubernetes/"
    
    # Get POD_CIDR for this worker
    $podCidr = ssh kuberoot@$publicIP "curl --silent -H Metadata:true 'http://169.254.169.254/metadata/instance/compute/tags?api-version=2017-08-01&format=text' | sed 's/\;/\n/g' | grep pod-cidr | cut -d : -f2"
    
    # Create kubelet configuration
    $kubeletConfig = @"
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "$podCidr"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/$worker.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/$worker-key.pem"
"@
    
    # Create kubelet systemd service
    $kubeletService = @"
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \
  --config=/var/lib/kubelet/kubelet-config.yaml \
  --container-runtime=remote \
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --register-node=true \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
"@
    
    New-RemoteConfigFile $publicIP $kubeletConfig "/var/lib/kubelet/kubelet-config.yaml"
    New-RemoteConfigFile $publicIP $kubeletService "/etc/systemd/system/kubelet.service"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✅ ${worker}: Kubelet configured" -ForegroundColor Green
    } else {
        Write-Host "    ❌ ${worker}: Kubelet configuration failed" -ForegroundColor Red
    }
}

# Step 6: Configure Kube-Proxy
Write-Host ""
Write-Host "Step 6: Configuring Kube-Proxy..." -ForegroundColor Yellow
foreach ($worker in $workers) {
    $publicIP = Get-WorkerPublicIP $worker
    Write-Host "  Configuring Kube-Proxy on $worker..." -ForegroundColor Cyan
    
    # Move kube-proxy kubeconfig
    ssh kuberoot@$publicIP "sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig"
    
    # Create kube-proxy configuration
    $kubeProxyConfig = @"
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
"@
    
    # Create kube-proxy systemd service
    $kubeProxyService = @"
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
"@
    
    New-RemoteConfigFile $publicIP $kubeProxyConfig "/var/lib/kube-proxy/kube-proxy-config.yaml"
    New-RemoteConfigFile $publicIP $kubeProxyService "/etc/systemd/system/kube-proxy.service"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✅ ${worker}: Kube-Proxy configured" -ForegroundColor Green
    } else {
        Write-Host "    ❌ ${worker}: Kube-Proxy configuration failed" -ForegroundColor Red
    }
}

# Step 7: Start Worker Services
Write-Host ""
Write-Host "Step 7: Starting worker services..." -ForegroundColor Yellow
foreach ($worker in $workers) {
    $publicIP = Get-WorkerPublicIP $worker
    Write-Host "  Starting services on $worker..." -ForegroundColor Cyan
    
    # Start and enable services
    ssh kuberoot@$publicIP "sudo systemctl daemon-reload && sudo systemctl enable containerd kubelet kube-proxy >/dev/null 2>&1 && sudo systemctl start containerd kubelet kube-proxy"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✅ ${worker}: Services started" -ForegroundColor Green
    } else {
        Write-Host "    ❌ ${worker}: Service startup failed" -ForegroundColor Red
    }
    
    # Wait for services to initialize
    Write-Host "    Waiting for services to initialize..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    # Check service status
    $status = ssh kuberoot@$publicIP "sudo systemctl is-active containerd kubelet kube-proxy"
    $activeCount = ($status -split "`n" | Where-Object { $_ -eq "active" }).Count
    
    if ($activeCount -eq 3) {
        Write-Host "    ✅ ${worker}: All services active (3/3)" -ForegroundColor Green
    } else {
        Write-Host "    ⚠️ ${worker}: $activeCount/3 services active" -ForegroundColor Yellow
    }
}

# Step 8: Verification
Write-Host ""
Write-Host "Step 8: Verifying worker node registration..." -ForegroundColor Yellow

# Wait for node registration
Write-Host "  Waiting for nodes to register..." -ForegroundColor Cyan
Start-Sleep -Seconds 30

# Get controller IP and check node registration
$controllerIP = az network public-ip show -g kubernetes -n "controller-0-pip" --query "ipAddress" -o tsv
Write-Host "  Checking node registration from controller-0..." -ForegroundColor Cyan

$nodeList = ssh kuberoot@$controllerIP "kubectl get nodes --kubeconfig admin.kubeconfig"
Write-Host $nodeList -ForegroundColor White

# Check if both workers are ready
if ($nodeList -match "worker-0.*Ready" -and $nodeList -match "worker-1.*Ready") {
    Write-Host ""
    Write-Host "✅ Both worker nodes successfully registered and ready!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "⚠️ Worker nodes may not be fully ready yet. Check status above." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "✅ Kubernetes Worker Nodes Setup Complete" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎯 Next Step: Tutorial Step 10 - Configuring kubectl for Remote Access" -ForegroundColor Yellow
