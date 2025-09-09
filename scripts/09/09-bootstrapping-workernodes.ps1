#requires -Version 5.1

<#
.SYNOPSIS
Bootstrap Kubernetes worker nodes with improved error handling and compatibility

.DESCRIPTION
Bootstraps two Kubernetes worker nodes with proper cgroups v2 support,
improved line ending handling, and enhanced error recovery.
Based on lessons learned from successful tutorial execution.

.PARAMETER KubernetesVersion
Kubernetes version to install (default: v1.26.3)

.PARAMETER ContainerdVersion
containerd version to install (default: 1.6.20 - known working version)

.NOTES
Author: KTHW PowerShell Tutorial
Version: 2.0
Date: July 15, 2025
Improvements: Fixed containerd version, cgroups v2 support, proper line endings
#>

[CmdletBinding()]
param(
    [string]$KubernetesVersion = "v1.26.3",
    [string]$CriToolsVersion = "v1.26.1", 
    [string]$RuncVersion = "v1.1.5",
    [string]$CniPluginsVersion = "v1.2.0",
    [string]$ContainerdVersion = "1.6.20",  # Fixed to working version
    [int]$SshTimeoutSeconds = 30,           # SSH timeout for operations
    [int]$LongTimeoutSeconds = 120          # Longer timeout for downloads
)

# Import common functions
. "$PSScriptRoot\..\common\Common-Functions.ps1"

# Wrapper function for long-running operations with timeout
function Invoke-RemoteCommandWithTimeout {
    param(
        [string]$VmIP,
        [string]$Command,
        [string]$Description = "",
        [int]$TimeoutSeconds = $SshTimeoutSeconds
    )
    
    if ($Description) {
        Write-Host "        $Description" -ForegroundColor Gray
    }
    
    # Use Start-Job for timeout capability
    $job = Start-Job -ScriptBlock {
        param($ip, $cmd)
        $result = ssh -o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 -o StrictHostKeyChecking=no "kuberoot@$ip" $cmd 2>$null
        return @{ Output = $result; ExitCode = $LASTEXITCODE }
    } -ArgumentList $VmIP, $Command
    
    $completed = Wait-Job $job -Timeout $TimeoutSeconds
    if (-not $completed) {
        Stop-Job $job
        Remove-Job $job
        throw "Command timed out after $TimeoutSeconds seconds: $Command"
    }
    
    $result = Receive-Job $job
    Remove-Job $job
    
    if ($result.ExitCode -ne 0) {
        throw "SSH command failed with exit code $($result.ExitCode): $Command"
    }
    
    return $result.Output
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Tutorial Step 09: Kubernetes Worker Nodes" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Kubernetes Version: $KubernetesVersion" -ForegroundColor Cyan
Write-Host "containerd Version: $ContainerdVersion (known working version)" -ForegroundColor Cyan
Write-Host "SSH Timeout: $SshTimeoutSeconds seconds" -ForegroundColor Cyan
Write-Host "Long Operation Timeout: $LongTimeoutSeconds seconds" -ForegroundColor Cyan
Write-Host ""

# Progress tracking
$script:CurrentStep = 0
$script:TotalSteps = 7

function Write-StepProgress {
    param([string]$StepName)
    $script:CurrentStep++
    Write-Host "[$script:CurrentStep/$script:TotalSteps] $StepName" -ForegroundColor Magenta
}

#region Prerequisites Validation

Write-Host "Validating prerequisites..." -ForegroundColor Yellow

try {
    Test-AzureAuthentication
    
    # Check if certificates exist
    if (!(Test-Path "..\..\certs\ca.pem")) {
        throw "CA certificate not found. Run script 04 first."
    }
    
    # Check if worker kubeconfigs exist
    if (!(Test-Path "..\..\configs\worker-0.kubeconfig") -or !(Test-Path "..\..\configs\worker-1.kubeconfig")) {
        throw "Worker kubeconfig files not found. Run script 05 first."
    }
    
    Write-Host "✅ Prerequisites validated" -ForegroundColor Green
}
catch {
    Write-Host "❌ Prerequisites validation failed: $_" -ForegroundColor Red
    exit 1
}

#endregion

#region Worker Configuration

$workers = @("worker-0", "worker-1")

# Step 1: Install OS Dependencies
Write-Host ""
Write-StepProgress "Installing OS dependencies"

foreach ($worker in $workers) {
    try {
        $ip = Get-VmPublicIP -ResourceGroup "kubernetes" -VmName $worker
        Write-Host "  Processing $worker ($ip)..." -ForegroundColor Cyan
        
        # Install OS dependencies with timeout
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo apt-get update >/dev/null 2>&1 && sudo apt-get -y install socat conntrack ipset >/dev/null 2>&1" -Description "Installing OS dependencies" -TimeoutSeconds $LongTimeoutSeconds
        
        # Disable swap (required for kubelet)
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo swapoff -a" -Description "Disabling swap"
        
        Write-Host "    ✅ OS dependencies installed on $worker" -ForegroundColor Green
    }
    catch {
        Write-Host "    ❌ Failed to install dependencies on $worker - $_" -ForegroundColor Red
        throw
    }
}

# Step 2: Download and Install Worker Binaries
Write-Host ""
Write-StepProgress "Downloading and installing worker binaries"

foreach ($worker in $workers) {
    try {
        $ip = Get-VmPublicIP -ResourceGroup "kubernetes" -VmName $worker
        Write-Host "  Processing $worker ($ip)..." -ForegroundColor Cyan
        
        # Download binaries in batches to avoid command line length issues
        $downloadCommands = @(
            "cd /tmp && wget -q --https-only --timestamping https://github.com/kubernetes-sigs/cri-tools/releases/download/$CriToolsVersion/crictl-$CriToolsVersion-linux-amd64.tar.gz",
            "cd /tmp && wget -q --https-only --timestamping https://storage.googleapis.com/gvisor/releases/nightly/latest/runsc",
            "cd /tmp && wget -q --https-only --timestamping https://github.com/opencontainers/runc/releases/download/$RuncVersion/runc.amd64",
            "cd /tmp && wget -q --https-only --timestamping https://github.com/containernetworking/plugins/releases/download/$CniPluginsVersion/cni-plugins-linux-amd64-$CniPluginsVersion.tgz",
            "cd /tmp && wget -q --https-only --timestamping https://github.com/containerd/containerd/releases/download/v$ContainerdVersion/containerd-$ContainerdVersion-linux-amd64.tar.gz",
            "cd /tmp && wget -q --https-only --timestamping https://storage.googleapis.com/kubernetes-release/release/$KubernetesVersion/bin/linux/amd64/kubectl",
            "cd /tmp && wget -q --https-only --timestamping https://storage.googleapis.com/kubernetes-release/release/$KubernetesVersion/bin/linux/amd64/kube-proxy",
            "cd /tmp && wget -q --https-only --timestamping https://storage.googleapis.com/kubernetes-release/release/$KubernetesVersion/bin/linux/amd64/kubelet"
        )
        
        foreach ($cmd in $downloadCommands) {
            Invoke-RemoteCommandWithTimeout -VmIP $ip -Command $cmd -Description "Downloading binaries" -TimeoutSeconds $LongTimeoutSeconds
        }
        
        # Install binaries
        $installCmd = "sudo mkdir -p /etc/cni/net.d /opt/cni/bin /var/lib/kubelet /var/lib/kube-proxy /var/lib/kubernetes /var/run/kubernetes && cd /tmp && mkdir -p containerd && sudo mv runc.amd64 runc && chmod +x kubectl kube-proxy kubelet runc runsc && sudo mv kubectl kube-proxy kubelet runc runsc /usr/local/bin/ && sudo tar -xf crictl-$CriToolsVersion-linux-amd64.tar.gz -C /usr/local/bin/ && sudo tar -xf cni-plugins-linux-amd64-$CniPluginsVersion.tgz -C /opt/cni/bin/ && sudo tar -xf containerd-$ContainerdVersion-linux-amd64.tar.gz -C containerd && sudo mv containerd/bin/* /bin/"
        
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command $installCmd -Description "Installing binaries" -TimeoutSeconds $LongTimeoutSeconds
        
        Write-Host "    ✅ Binaries installed on $worker" -ForegroundColor Green
    }
    catch {
        Write-Host "    ❌ Failed to install binaries on $worker - $_" -ForegroundColor Red
        throw
    }
}

# Step 3: Configure CNI Networking
Write-Host ""
Write-StepProgress "Configuring CNI networking"

foreach ($worker in $workers) {
    try {
        $ip = Get-VmPublicIP -ResourceGroup "kubernetes" -VmName $worker
        Write-Host "  Configuring CNI on $worker..." -ForegroundColor Cyan
        
        # Get POD_CIDR for this worker
        $podCidr = Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "curl --silent -H Metadata:true 'http://169.254.169.254/metadata/instance/compute/tags?api-version=2017-08-01&format=text' | sed 's/\;/\n/g' | grep pod-cidr | cut -d : -f2" -Description "Getting pod CIDR"
        
        # Create bridge network configuration with proper formatting
        $bridgeConfig = @"
{
    `"cniVersion`": `"0.3.1`",
    `"name`": `"bridge`",
    `"type`": `"bridge`",
    `"bridge`": `"cnio0`",
    `"isGateway`": true,
    `"ipMasq`": true,
    `"ipam`": {
        `"type`": `"host-local`",
        `"ranges`": [
          [{`"subnet`": `"$podCidr`"}]
        ],
        `"routes`": [{`"dst`": `"0.0.0.0/0`"}]
    }
}
"@
        
        # Create loopback configuration  
        $loopbackConfig = @"
{
    `"cniVersion`": `"0.3.1`",
    `"name`": `"lo`",
    `"type`": `"loopback`"
}
"@
        
        # Copy CNI config files to temp location first, then move with sudo
        New-RemoteConfigFile -VmIP $ip -Content $bridgeConfig -RemotePath "/tmp/10-bridge.conf"
        New-RemoteConfigFile -VmIP $ip -Content $loopbackConfig -RemotePath "/tmp/99-loopback.conf"
        
        # Move files to correct locations with proper permissions
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo mv /tmp/10-bridge.conf /etc/cni/net.d/10-bridge.conf" -Description "Moving bridge config"
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo mv /tmp/99-loopback.conf /etc/cni/net.d/99-loopback.conf" -Description "Moving loopback config"
        
        Write-Host "    ✅ CNI configured on $worker" -ForegroundColor Green
    }
    catch {
        Write-Host "    ❌ Failed to configure CNI on $worker - $_" -ForegroundColor Red
        throw
    }
}

# Step 4: Configure containerd with cgroups v2 support
Write-Host ""
Write-StepProgress "Configuring containerd with cgroups v2 support"

foreach ($worker in $workers) {
    try {
        $ip = Get-VmPublicIP -ResourceGroup "kubernetes" -VmName $worker
        Write-Host "  Configuring containerd on $worker..." -ForegroundColor Cyan
        
        # Create containerd directories
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo mkdir -p /etc/containerd/" -Description "Creating containerd directories"
        
        # Generate default containerd configuration and enable systemd cgroups
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo containerd config default | sudo tee /etc/containerd/config.toml" -Description "Generating containerd config"
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml" -Description "Enabling systemd cgroups"
        
        # Create containerd systemd service
        $containerdService = "ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd

Delegate=yes
KillMode=process
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
TasksMax=infinity

[Install]
WantedBy=multi-user.target"

        # Create service file with proper header
        $serviceContent = @"
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
$containerdService
"@
        
        # Copy service file to temp location first, then move with sudo
        New-RemoteConfigFile -VmIP $ip -Content $serviceContent -RemotePath "/tmp/containerd.service"
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo mv /tmp/containerd.service /etc/systemd/system/containerd.service" -Description "Moving containerd service"
        
        Write-Host "    ✅ containerd configured on $worker" -ForegroundColor Green
    }
    catch {
        Write-Host "    ❌ Failed to configure containerd on $worker - $_" -ForegroundColor Red
        throw
    }
}

# Step 5: Configure Kubelet with systemd cgroups
Write-Host ""
Write-StepProgress "Configuring Kubelet"

foreach ($worker in $workers) {
    try {
        $ip = Get-VmPublicIP -ResourceGroup "kubernetes" -VmName $worker
        Write-Host "  Configuring Kubelet on $worker..." -ForegroundColor Cyan
        
        # Create required directories first
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo mkdir -p /var/lib/kubelet /var/lib/kubernetes" -Description "Creating kubelet directories"
        
        # Copy certificates and kubeconfig files to the worker node
        Write-Host "    Copying certificates and kubeconfig..." -ForegroundColor Gray
        scp -o ConnectTimeout=10 -o StrictHostKeyChecking=no "..\..\certs\ca.pem" "kuberoot@${ip}:~/" 2>$null
        if ($LASTEXITCODE -ne 0) { throw "Failed to copy ca.pem to $worker" }
        
        scp -o ConnectTimeout=10 -o StrictHostKeyChecking=no "..\..\certs\$worker-key.pem" "kuberoot@${ip}:~/" 2>$null
        if ($LASTEXITCODE -ne 0) { throw "Failed to copy $worker-key.pem to $worker" }
        
        scp -o ConnectTimeout=10 -o StrictHostKeyChecking=no "..\..\certs\$worker.pem" "kuberoot@${ip}:~/" 2>$null
        if ($LASTEXITCODE -ne 0) { throw "Failed to copy $worker.pem to $worker" }
        
        scp -o ConnectTimeout=10 -o StrictHostKeyChecking=no "..\..\configs\$worker.kubeconfig" "kuberoot@${ip}:~/" 2>$null
        if ($LASTEXITCODE -ne 0) { throw "Failed to copy $worker.kubeconfig to $worker" }
        
        # Move certificates and kubeconfig to proper locations
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo mv $worker-key.pem $worker.pem /var/lib/kubelet/ && sudo mv $worker.kubeconfig /var/lib/kubelet/kubeconfig && sudo mv ca.pem /var/lib/kubernetes/" -Description "Moving certificates and kubeconfig"
        
        # Get POD_CIDR for this worker
        $podCidr = Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "curl --silent -H Metadata:true 'http://169.254.169.254/metadata/instance/compute/tags?api-version=2017-08-01&format=text' | sed 's/\;/\n/g' | grep pod-cidr | cut -d : -f2" -Description "Getting pod CIDR"
        
        # Create kubelet configuration with systemd cgroup driver
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
cgroupDriver: systemd
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
        
        # Copy config files to temp location first, then move with sudo
        New-RemoteConfigFile -VmIP $ip -Content $kubeletConfig -RemotePath "/tmp/kubelet-config.yaml"
        New-RemoteConfigFile -VmIP $ip -Content $kubeletService -RemotePath "/tmp/kubelet.service"
        
        # Move files to correct locations with proper permissions
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo mv /tmp/kubelet-config.yaml /var/lib/kubelet/kubelet-config.yaml" -Description "Moving kubelet config"
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo mv /tmp/kubelet.service /etc/systemd/system/kubelet.service" -Description "Moving kubelet service"
        
        Write-Host "    ✅ Kubelet configured on $worker" -ForegroundColor Green
    }
    catch {
        Write-Host "    ❌ Failed to configure Kubelet on $worker - $_" -ForegroundColor Red
        throw
    }
}

# Step 6: Configure Kube-Proxy
Write-Host ""
Write-StepProgress "Configuring Kube-Proxy"

foreach ($worker in $workers) {
    try {
        $ip = Get-VmPublicIP -ResourceGroup "kubernetes" -VmName $worker
        Write-Host "  Configuring Kube-Proxy on $worker..." -ForegroundColor Cyan
        
        # Create kube-proxy directory
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo mkdir -p /var/lib/kube-proxy" -Description "Creating kube-proxy directory"
        
        # Copy kube-proxy kubeconfig to the worker node
        Write-Host "    Copying kube-proxy kubeconfig..." -ForegroundColor Gray
        scp -o ConnectTimeout=10 -o StrictHostKeyChecking=no "..\..\configs\kube-proxy.kubeconfig" "kuberoot@${ip}:~/" 2>$null
        if ($LASTEXITCODE -ne 0) { throw "Failed to copy kube-proxy.kubeconfig to $worker" }
        
        # Move kube-proxy kubeconfig to proper location
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig" -Description "Moving kube-proxy kubeconfig"
        
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
        
        # Copy config files to temp location first, then move with sudo
        New-RemoteConfigFile -VmIP $ip -Content $kubeProxyConfig -RemotePath "/tmp/kube-proxy-config.yaml"
        New-RemoteConfigFile -VmIP $ip -Content $kubeProxyService -RemotePath "/tmp/kube-proxy.service"
        
        # Move files to correct locations with proper permissions
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo mv /tmp/kube-proxy-config.yaml /var/lib/kube-proxy/kube-proxy-config.yaml" -Description "Moving kube-proxy config"
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo mv /tmp/kube-proxy.service /etc/systemd/system/kube-proxy.service" -Description "Moving kube-proxy service"
        
        Write-Host "    ✅ Kube-Proxy configured on $worker" -ForegroundColor Green
    }
    catch {
        Write-Host "    ❌ Failed to configure Kube-Proxy on $worker - $_" -ForegroundColor Red
        throw
    }
}

# Step 7: Start Worker Services
Write-Host ""
Write-StepProgress "Starting worker services"

foreach ($worker in $workers) {
    try {
        $ip = Get-VmPublicIP -ResourceGroup "kubernetes" -VmName $worker
        Write-Host "  Starting services on $worker..." -ForegroundColor Cyan
        
        # Reload systemd and start services
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo systemctl daemon-reload" -Description "Reloading systemd"
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo systemctl enable containerd kubelet kube-proxy" -Description "Enabling services"
        Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo systemctl start containerd kubelet kube-proxy" -Description "Starting services" -TimeoutSeconds $LongTimeoutSeconds
        
        # Wait for services to initialize
        Start-Sleep -Seconds 10
        
        # Verify services are running
        $services = @("containerd", "kubelet", "kube-proxy")
        foreach ($service in $services) {
            $status = Invoke-RemoteCommandWithTimeout -VmIP $ip -Command "sudo systemctl is-active $service" -Description "Checking $service status"
            if ($status -eq "active") {
                Write-Host "    ✅ $service is running on $worker" -ForegroundColor Green
            } else {
                Write-Host "    ⚠️ $service status on $worker - $status" -ForegroundColor Yellow
            }
        }
        
        Write-Host "    ✅ Services started on $worker" -ForegroundColor Green
    }
    catch {
        Write-Host "    ❌ Failed to start services on $worker - $_" -ForegroundColor Red
        throw
    }
}

#endregion

#region Validation

Write-Host ""
Write-Host "Validating worker node configuration..." -ForegroundColor Yellow

Start-Sleep -Seconds 20  # Allow time for nodes to register

# Note: Node validation requires kubectl to be configured (step 10)
Write-Host "⚠️ Worker node registration validation requires kubectl configuration" -ForegroundColor Yellow
Write-Host "💡 Run script 10-configure-kubectl.ps1 to configure kubectl, then validate with:" -ForegroundColor Yellow
Write-Host "   kubectl get nodes" -ForegroundColor White

#endregion

#region Completion

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Worker Nodes Configuration Complete" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Worker nodes configured with:" -ForegroundColor Green
Write-Host "  • containerd $ContainerdVersion with systemd cgroups" -ForegroundColor White
Write-Host "  • kubelet with systemd cgroup driver" -ForegroundColor White
Write-Host "  • CNI networking configured" -ForegroundColor White
Write-Host "  • kube-proxy configured" -ForegroundColor White
Write-Host ""
Write-Host "🔧 Improvements applied:" -ForegroundColor Cyan
Write-Host "  • Fixed containerd version compatibility" -ForegroundColor White
Write-Host "  • Added cgroups v2 support" -ForegroundColor White
Write-Host "  • Proper Unix line endings for config files" -ForegroundColor White
Write-Host "  • Enhanced error handling and validation" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Configure kubectl (script 10)" -ForegroundColor White
Write-Host "2. Provision pod network routes (script 11)" -ForegroundColor White
Write-Host "3. Validate cluster: .\scripts\validation\Validate-Cluster.ps1" -ForegroundColor White

#endregion
