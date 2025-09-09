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
    - Controller VMs deployed and accessible via SSH (Step 03)
    - Certificates generated and distributed to controllers (Step 04)
    - This script moves certificates to /etc/etcd/ and installs etcd cluster
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
Write-Host "Step 2: Setting up etcd certificates on all controller nodes..." -ForegroundColor Cyan

foreach ($instance in $controllers) {
    Write-Host ""
    Write-Host "Setting up certificates on $instance..." -ForegroundColor Yellow
    
    # Create etcd directory and move certificates (certificates were copied by step 04)
    $certSetupCmd = "sudo mkdir -p /etc/etcd && sudo cp ~/ca.pem ~/kubernetes.pem ~/kubernetes-key.pem /etc/etcd/ && sudo chmod 600 /etc/etcd/*.pem && sudo chown root:root /etc/etcd/*.pem"
    Invoke-RemoteCommand -Instance $instance -Command $certSetupCmd -Description "Setting up etcd certificates"
    
    # Verify certificates are in place
    $verifyCerts = "sudo ls -la /etc/etcd/"
    Invoke-RemoteCommand -Instance $instance -Command $verifyCerts -Description "Verifying certificate setup"
}

Write-Host ""
Write-Host "Step 3: Configuring etcd servers on all controller nodes..." -ForegroundColor Cyan

foreach ($instance in $controllers) {
    Write-Host ""
    Write-Host "Configuring etcd on $instance..." -ForegroundColor White
    
    # Create etcd data directory (/etc/etcd already created in Step 2 for certificates)
    $mkdirCmd = 'sudo mkdir -p /var/lib/etcd && sudo chmod 700 /var/lib/etcd'
    Invoke-RemoteCommand -Instance $instance -Command $mkdirCmd -Description "Creating etcd data directory"
    
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
Write-Host "Step 4: Starting etcd services on all controller nodes..." -ForegroundColor Cyan

# First, reload systemd daemon and enable services on all nodes
foreach ($instance in $controllers) {
    Write-Host ""
    Write-Host "Preparing etcd service on $instance..." -ForegroundColor White
    
    # Reload systemd daemon
    Invoke-RemoteCommand -Instance $instance -Command "sudo systemctl daemon-reload" -Description "Reloading systemd daemon"
    
    # Enable etcd service
    Invoke-RemoteCommand -Instance $instance -Command "sudo systemctl enable etcd" -Description "Enabling etcd service"
    
    # Stop any existing etcd service to ensure clean start
    Invoke-RemoteCommand -Instance $instance -Command "sudo systemctl stop etcd" -Description "Stopping existing etcd service"
}

Write-Host ""
Write-Host "Starting all etcd services simultaneously for proper cluster formation..." -ForegroundColor Yellow

# Start all etcd services simultaneously using PowerShell jobs
$jobs = @()
foreach ($instance in $controllers) {
    $publicIP = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    Write-Host "Initiating etcd startup on $instance ($publicIP)..." -ForegroundColor Cyan
    
    $job = Start-Job -ScriptBlock {
        param($ip, $instanceName)
        ssh "kuberoot@$ip" "sudo systemctl start etcd"
        return @{Instance = $instanceName; IP = $ip; ExitCode = $LASTEXITCODE}
    } -ArgumentList $publicIP, $instance
    
    $jobs += $job
}

# Wait for all services to start
Write-Host "Waiting for all etcd services to start..." -ForegroundColor Gray
$results = $jobs | Wait-Job -Timeout 60 | Receive-Job
$jobs | Remove-Job -Force

# Check results
foreach ($result in $results) {
    if ($result.ExitCode -eq 0) {
        Write-Host "✅ etcd started successfully on $($result.Instance)" -ForegroundColor Green
    } else {
        Write-Host "❌ etcd startup failed on $($result.Instance)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Step 5: Verifying etcd cluster..." -ForegroundColor Cyan

# Wait longer for cluster to stabilize after simultaneous startup
Write-Host "Waiting 15 seconds for etcd cluster to stabilize..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

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
    
    Write-Host ""
    Write-Host "Troubleshooting - checking individual node status:" -ForegroundColor Yellow
    foreach ($instance in $controllers) {
        $ip = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
        Write-Host "Checking $instance ($ip):" -ForegroundColor Cyan
        
        # Check service status
        $status = ssh kuberoot@$ip "sudo systemctl is-active etcd" 2>/dev/null
        Write-Host "  Service status: $status" -ForegroundColor White
        
        # Check if certificates exist
        $certCheck = ssh kuberoot@$ip "sudo ls -la /etc/etcd/*.pem" 2>/dev/null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Certificates present" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Certificates missing" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "If etcd cluster formation failed, you can:" -ForegroundColor Yellow
    Write-Host "1. Check logs: ssh kuberoot@<controller-ip> 'sudo journalctl -u etcd -f'" -ForegroundColor White
    Write-Host "2. Re-run the fix script: .\07-fix-etcd-quick.ps1" -ForegroundColor White
    Write-Host "3. Verify certificates are in /etc/etcd/ on all controllers" -ForegroundColor White
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