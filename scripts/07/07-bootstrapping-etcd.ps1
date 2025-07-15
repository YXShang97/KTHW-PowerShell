#requires -Version 5.1
<#
.SYNOPSIS
    Tutorial Step 07: Bootstrapping the etcd Cluster

.DESCRIPTION
    Kubernetes components are stateless and store cluster state in etcd. 
    In this lab you will bootstrap a three nodes etcd cluster and configure it 
    for high availability and secure remote access.

.NOTES
    Tutorial Step: 07
    Tutorial Name: Bootstrapping the etcd Cluster
    Original URL: https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/07-bootstrapping-etcd.md
    
    Prerequisites:
    - Controller VMs deployed and accessible via SSH
    - Certificates generated and distributed from previous steps
    - This script coordinates etcd installation across all controller nodes
#>

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Bootstrapping etcd Cluster" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Define controller instances
$controllers = @("controller-0", "controller-1", "controller-2")

# Function to execute commands on remote instance
function Invoke-RemoteCommand {
    param(
        [string]$Instance,
        [string]$Command,
        [string]$Description
    )
    
    $publicIP = az network public-ip show -g kubernetes -n "$Instance-pip" --query "ipAddress" -o tsv
    Write-Host "$Description on $Instance ($publicIP)..." -ForegroundColor Yellow
    
    # Execute command via SSH
    $result = ssh kuberoot@$publicIP $Command 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ $Description completed on $Instance" -ForegroundColor Green
        if ($result) {
            Write-Host "Output: $result" -ForegroundColor Gray
        }
    } else {
        Write-Host "❌ $Description failed on $Instance" -ForegroundColor Red
        Write-Host "Error: $result" -ForegroundColor Red
    }
    
    return $LASTEXITCODE -eq 0
}

# Function to copy file to remote instance
function Copy-ToRemoteInstance {
    param(
        [string]$Instance,
        [string]$LocalFile,
        [string]$RemotePath = "~/"
    )
    
    $publicIP = az network public-ip show -g kubernetes -n "$Instance-pip" --query "ipAddress" -o tsv
    Write-Host "Copying $LocalFile to $Instance ($publicIP)..." -ForegroundColor Yellow
    
    & scp $LocalFile "kuberoot@$publicIP`:$RemotePath"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ File copied successfully to $Instance" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ File copy failed to $Instance" -ForegroundColor Red
        return $false
    }
}

Write-Host "Step 1: Installing etcd binaries on all controller nodes..." -ForegroundColor Cyan

foreach ($instance in $controllers) {
    Write-Host ""
    Write-Host "Processing $instance..." -ForegroundColor White
    
    # Download etcd binaries
    $downloadCmd = 'wget -q --show-progress --https-only --timestamping "https://github.com/etcd-io/etcd/releases/download/v3.4.24/etcd-v3.4.24-linux-amd64.tar.gz"'
    Invoke-RemoteCommand -Instance $instance -Command $downloadCmd -Description "Downloading etcd v3.4.24"
    
    # Extract and install etcd binaries
    $extractCmd = 'tar -xvf etcd-v3.4.24-linux-amd64.tar.gz && sudo mv etcd-v3.4.24-linux-amd64/etcd* /usr/local/bin/'
    Invoke-RemoteCommand -Instance $instance -Command $extractCmd -Description "Extracting and installing etcd binaries"
    
    # Verify installation
    $verifyCmd = '/usr/local/bin/etcd --version'
    Invoke-RemoteCommand -Instance $instance -Command $verifyCmd -Description "Verifying etcd installation"
}

Write-Host ""
Write-Host "Step 2: Configuring etcd servers on all controller nodes..." -ForegroundColor Cyan

foreach ($instance in $controllers) {
    Write-Host ""
    Write-Host "Configuring etcd on $instance..." -ForegroundColor White
    
    # Create etcd directories
    $mkdirCmd = 'sudo mkdir -p /etc/etcd /var/lib/etcd && sudo chmod 700 /var/lib/etcd'
    Invoke-RemoteCommand -Instance $instance -Command $mkdirCmd -Description "Creating etcd directories"
    
    # Copy certificates to etcd directory
    $copyCertsCmd = 'sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/'
    Invoke-RemoteCommand -Instance $instance -Command $copyCertsCmd -Description "Copying certificates to etcd directory"
    
    # Get internal IP address
    $getIPCmd = "ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'"
    $publicIP = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    Write-Host "Getting internal IP for $instance..." -ForegroundColor Yellow
    $internalIP = ssh kuberoot@$publicIP $getIPCmd
    Write-Host "Internal IP for ${instance}: $internalIP" -ForegroundColor Cyan
    
    # Create etcd systemd service file using string concatenation for proper variable expansion
    $serviceContent = "[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \
  --name $instance \
  --cert-file=/etc/etcd/kubernetes.pem \
  --key-file=/etc/etcd/kubernetes-key.pem \
  --peer-cert-file=/etc/etcd/kubernetes.pem \
  --peer-key-file=/etc/etcd/kubernetes-key.pem \
  --trusted-ca-file=/etc/etcd/ca.pem \
  --peer-trusted-ca-file=/etc/etcd/ca.pem \
  --peer-client-cert-auth \
  --client-cert-auth \
  --initial-advertise-peer-urls https://$internalIP`:2380 \
  --listen-peer-urls https://$internalIP`:2380 \
  --listen-client-urls https://$internalIP`:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://$internalIP`:2379 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-cluster controller-0=https://10.240.0.10:2380,controller-1=https://10.240.0.11:2380,controller-2=https://10.240.0.12:2380 \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target"
    
    # Write service file content to temporary local file
    $tempServiceFile = "$env:TEMP\etcd-$instance.service"
    $serviceContent | Out-File -FilePath $tempServiceFile -Encoding UTF8
    
    # Copy service file to remote instance
    Copy-ToRemoteInstance -Instance $instance -LocalFile $tempServiceFile -RemotePath "~/etcd.service"
    
    # Move service file to systemd directory
    $moveServiceCmd = 'sudo mv etcd.service /etc/systemd/system/'
    Invoke-RemoteCommand -Instance $instance -Command $moveServiceCmd -Description "Installing etcd systemd service"
    
    # Clean up temporary file
    Remove-Item $tempServiceFile -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Step 3: Starting etcd services on all controller nodes..." -ForegroundColor Cyan

foreach ($instance in $controllers) {
    Write-Host ""
    Write-Host "Starting etcd service on $instance..." -ForegroundColor White
    
    # Reload systemd daemon
    Invoke-RemoteCommand -Instance $instance -Command "sudo systemctl daemon-reload" -Description "Reloading systemd daemon"
    
    # Enable etcd service
    Invoke-RemoteCommand -Instance $instance -Command "sudo systemctl enable etcd" -Description "Enabling etcd service"
    
    # Start etcd service
    Invoke-RemoteCommand -Instance $instance -Command "sudo systemctl start etcd" -Description "Starting etcd service"
    
    # Check etcd service status
    Invoke-RemoteCommand -Instance $instance -Command "sudo systemctl is-active etcd" -Description "Checking etcd service status"
}

Write-Host ""
Write-Host "Step 4: Verifying etcd cluster..." -ForegroundColor Cyan

# Wait a moment for cluster to stabilize
Write-Host "Waiting 10 seconds for etcd cluster to stabilize..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Verify cluster from controller-0
$verificationInstance = "controller-0"
$publicIP = az network public-ip show -g kubernetes -n "$verificationInstance-pip" --query "ipAddress" -o tsv
Write-Host ""
Write-Host "Verifying etcd cluster from $verificationInstance ($publicIP)..." -ForegroundColor Yellow

$internalIP = ssh kuberoot@$publicIP "ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'"
$clusterListCmd = "sudo ETCDCTL_API=3 etcdctl member list --endpoints=https://$internalIP:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem"

Write-Host "Executing cluster verification command..." -ForegroundColor Yellow
$clusterMembers = ssh kuberoot@$publicIP $clusterListCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ etcd cluster verification successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "etcd Cluster Members:" -ForegroundColor Cyan
    $clusterMembers | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
} else {
    Write-Host "❌ etcd cluster verification failed" -ForegroundColor Red
    Write-Host "Error output: $clusterMembers" -ForegroundColor Red
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "etcd Cluster Bootstrap Complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "- etcd v3.4.24 installed on all 3 controller nodes" -ForegroundColor White
Write-Host "- etcd cluster configured for high availability" -ForegroundColor White
Write-Host "- All nodes using TLS certificates for secure communication" -ForegroundColor White
Write-Host "- Cluster ready for Kubernetes control plane bootstrap" -ForegroundColor White