# This file recreates the bash script from the kubernetes-the-hard-way repository but using PowerShell syntax
# This is from tutorial 7: Bootstrapping the etcd Cluster - https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/07-bootstrapping-etcd.md
# Kubernetes components are stateless and store cluster state in etcd. In this lab you will bootstrap a three nodes etcd cluster and configure it for high availability and secure remote access.

# This script coordinates the etcd installation on all controller nodes from your Windows machine

# Start transcript to capture all output
$outputFile = "C:\repos\kthw\scripts\07\07-execution-output.txt"
Start-Transcript -Path $outputFile -Force

Write-Host "=========================================="
Write-Host "Bootstrapping etcd Cluster"
Write-Host "=========================================="
Write-Host ""

# Define controller instances
$controllerInstances = @("controller-0", "controller-1", "controller-2")
$controllerIPs = @("10.240.0.10", "10.240.0.11", "10.240.0.12")

Write-Host "This script will install and configure etcd on all controller nodes."
Write-Host "The following steps will be performed on each controller:"
Write-Host "1. Download and install etcd binaries"
Write-Host "2. Configure etcd server"
Write-Host "3. Create and start etcd systemd service"
Write-Host "4. Verify cluster membership"
Write-Host ""

# Create the etcd installation script that will be executed on each controller
$etcdInstallScript = @'
#!/bin/bash
set -e

echo "Starting etcd installation on $(hostname)..."

# Download and Install the etcd Binaries
echo "Downloading etcd binaries..."
wget -q --show-progress --https-only --timestamping \
  "https://github.com/etcd-io/etcd/releases/download/v3.4.24/etcd-v3.4.24-linux-amd64.tar.gz"

# Extract and install the etcd server and the etcdctl command line utility
echo "Installing etcd binaries..."
tar -xvf etcd-v3.4.24-linux-amd64.tar.gz
sudo mv etcd-v3.4.24-linux-amd64/etcd* /usr/local/bin/
rm -rf etcd-v3.4.24-linux-amd64*

# Configure the etcd Server
echo "Configuring etcd server..."
sudo mkdir -p /etc/etcd /var/lib/etcd
sudo chmod 700 /var/lib/etcd

# Check if certificate files exist in home directory, if not, they should be in /home/kuberoot/
if [ -f "ca.pem" ]; then
    sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
    echo "Certificates copied from current directory"
else
    echo "Certificate files not found in current directory. Please ensure certificates were distributed correctly."
    echo "Looking for certificates in home directory..."
    ls -la ~/ca.pem ~/kubernetes*.pem 2>/dev/null || echo "Certificate files not found in home directory either"
    exit 1
fi

# Get internal IP and hostname
INTERNAL_IP=$(ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
ETCD_NAME=$(hostname -s)

echo "Internal IP: $INTERNAL_IP"
echo "ETCD Name: $ETCD_NAME"

# Create the etcd.service systemd unit file
echo "Creating etcd systemd service..."
cat > etcd.service <<EOF
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name $ETCD_NAME \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://$INTERNAL_IP:2380 \\
  --listen-peer-urls https://$INTERNAL_IP:2380 \\
  --listen-client-urls https://$INTERNAL_IP:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://$INTERNAL_IP:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster controller-0=https://10.240.0.10:2380,controller-1=https://10.240.0.11:2380,controller-2=https://10.240.0.12:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Install and start the etcd service
echo "Installing and starting etcd service..."
sudo mv etcd.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd

# Wait a moment for etcd to start
sleep 5

# Check etcd service status
echo "Checking etcd service status..."
sudo systemctl status etcd --no-pager -l

echo "etcd installation completed on $(hostname)!"
'@

# Save the installation script to a temporary file with Unix line endings
$scriptPath = "C:\repos\kthw\scripts\07\install-etcd.sh"
# Write with UTF8 encoding and convert to Unix line endings
$etcdInstallScript -replace "`r`n", "`n" | Out-File -FilePath $scriptPath -Encoding UTF8 -NoNewline
# Add final newline
"`n" | Out-File -FilePath $scriptPath -Encoding UTF8 -Append -NoNewline

Write-Host "Created etcd installation script: $scriptPath"
Write-Host ""

# Execute the script on each controller instance
foreach ($i in 0..($controllerInstances.Length - 1)) {
    $instance = $controllerInstances[$i]
    $internalIP = $controllerIPs[$i]
    
    Write-Host "=========================================="
    Write-Host "Configuring etcd on $instance (IP: $internalIP)"
    Write-Host "=========================================="
    
    # Get the public IP address for SSH connection
    $publicIpAddress = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    
    Write-Host "Public IP for $instance : $publicIpAddress"
    
    # Copy the installation script to the controller
    Write-Host "Copying installation script to $instance..."
    scp -o StrictHostKeyChecking=no $scriptPath "kuberoot@${publicIpAddress}:~/"
    
    # Execute the installation script on the controller
    Write-Host "Executing etcd installation on $instance..."
    try {
        ssh -o StrictHostKeyChecking=no "kuberoot@$publicIpAddress" "chmod +x install-etcd.sh && ./install-etcd.sh"
        Write-Host "$instance etcd installation completed successfully!"
    }
    catch {
        Write-Host "ERROR: Failed to install etcd on $instance"
        Write-Host "Error: $_"
    }
    Write-Host ""
}

Write-Host "=========================================="
Write-Host "Verifying etcd Cluster"
Write-Host "=========================================="

# Verify the etcd cluster on the first controller
$firstController = $controllerInstances[0]
$firstPublicIP = az network public-ip show -g kubernetes -n "$firstController-pip" --query "ipAddress" -o tsv
$firstInternalIP = $controllerIPs[0]

Write-Host "Verifying etcd cluster membership from $firstController..."
Write-Host "Connecting to $firstController (Public IP: $firstPublicIP, Internal IP: $firstInternalIP)"

Write-Host "Running verification command..."
ssh -o StrictHostKeyChecking=no "kuberoot@$firstPublicIP" "sudo ETCDCTL_API=3 etcdctl member list --endpoints=https://$firstInternalIP:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem"

Write-Host ""
Write-Host "=========================================="
Write-Host "etcd Cluster Bootstrap Complete!"
Write-Host "=========================================="
Write-Host ""
Write-Host "Expected output should show 3 etcd members:"
Write-Host "- controller-0 (10.240.0.10)"
Write-Host "- controller-1 (10.240.0.11)"
Write-Host "- controller-2 (10.240.0.12)"
Write-Host ""
Write-Host "Next step: Bootstrapping the Kubernetes Control Plane"
Write-Host ""

# Cleanup temporary script
Remove-Item $scriptPath -Force
Write-Host "Cleaned up temporary installation script."

# Stop transcript
Stop-Transcript
Write-Host "`nExecution log saved to: $outputFile"