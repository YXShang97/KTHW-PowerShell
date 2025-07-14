# This file recreates the bash script from the kubernetes-the-hard-way repository but using PowerShell syntax
# This is from tutorial 9: Bootstrapping the Kubernetes Worker Nodes - https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/09-bootstrapping-kubernetes-workers.md
# In this lab you will bootstrap two Kubernetes worker nodes. The following components will be installed on each node: runc, container networking plugins, cri-containerd, kubelet, and kube-proxy.

# This script coordinates the Kubernetes worker nodes installation on all worker nodes from your Windows machine

# Start transcript to capture all output
$outputFile = "C:\repos\kthw\scripts\09\09-execution-output.txt"
Start-Transcript -Path $outputFile -Force

Write-Host "=========================================="
Write-Host "Bootstrapping Kubernetes Worker Nodes"
Write-Host "=========================================="
Write-Host ""

# Define worker instances
$workerInstances = @("worker-0", "worker-1")
$workerIPs = @("10.240.0.20", "10.240.0.21")
$podCIDRs = @("10.200.0.0/24", "10.200.1.0/24")

Write-Host "This script will install and configure Kubernetes worker nodes."
Write-Host "The following components will be installed on each worker:"
Write-Host "1. OS dependencies (socat, conntrack, ipset)"
Write-Host "2. Container runtime (containerd)"
Write-Host "3. Container networking plugins (CNI)"
Write-Host "4. Kubernetes components (kubelet, kube-proxy)"
Write-Host "5. runc and runsc (gVisor) runtimes"
Write-Host ""

# Create the Kubernetes worker nodes installation script that will be executed on each worker
$workerInstallScript = @'
#!/bin/bash
set -e

echo "Starting Kubernetes worker node installation on $(hostname)..."

# Install OS dependencies
echo "Installing OS dependencies..."
sudo apt-get update
sudo apt-get -y install socat conntrack ipset

# Download and Install Worker Binaries
echo "Downloading Kubernetes worker binaries..."
wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.26.1/crictl-v1.26.1-linux-amd64.tar.gz \
  https://storage.googleapis.com/gvisor/releases/nightly/latest/runsc \
  https://github.com/opencontainers/runc/releases/download/v1.1.5/runc.amd64 \
  https://github.com/containernetworking/plugins/releases/download/v1.2.0/cni-plugins-linux-amd64-v1.2.0.tgz \
  https://github.com/containerd/containerd/releases/download/v1.7.0/containerd-1.7.0-linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v1.26.3/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.26.3/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.26.3/bin/linux/amd64/kubelet

# Create the installation directories
echo "Creating installation directories..."
sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

# Install the worker binaries
echo "Installing worker binaries..."
mkdir containerd
sudo mv runc.amd64 runc
chmod +x kubectl kube-proxy kubelet runc runsc
sudo mv kubectl kube-proxy kubelet runc runsc /usr/local/bin/
sudo tar -xvf crictl-v1.26.1-linux-amd64.tar.gz -C /usr/local/bin/
sudo tar -xvf cni-plugins-linux-amd64-v1.2.0.tgz -C /opt/cni/bin/
sudo tar -xvf containerd-1.7.0-linux-amd64.tar.gz -C containerd
sudo mv containerd/bin/* /bin/

# Get POD_CIDR from Azure VM tags
echo "Retrieving POD_CIDR from Azure VM tags..."
POD_CIDR="$(echo $(curl --silent -H Metadata:true "http://169.254.169.254/metadata/instance/compute/tags?api-version=2017-08-01&format=text" | sed 's/\;/\n/g' | grep pod-cidr) | cut -d : -f2)"
echo "POD_CIDR: $POD_CIDR"

# Configure CNI Networking
echo "Configuring CNI networking..."
cat > 10-bridge.conf <<EOF
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
          [{"subnet": "$POD_CIDR"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

cat > 99-loopback.conf <<EOF
{
    "cniVersion": "0.4.0",
    "name": "lo",
    "type": "loopback"
}
EOF

sudo mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/

# Configure containerd
echo "Configuring containerd..."
sudo mkdir -p /etc/containerd/

cat > config.toml <<EOF
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
EOF

sudo mv config.toml /etc/containerd/

# Create the containerd.service systemd unit file
cat > containerd.service <<EOF
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd

Delegate=yes
KillMode=process
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity

[Install]
WantedBy=multi-user.target
EOF

# Configure the Kubelet
echo "Configuring Kubelet..."
HOSTNAME=$(hostname -s)

# Check if required files exist
if [ -f "$HOSTNAME-key.pem" ] && [ -f "$HOSTNAME.pem" ] && [ -f "$HOSTNAME.kubeconfig" ] && [ -f "ca.pem" ]; then
    sudo mv ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/
    sudo mv ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
    sudo mv ca.pem /var/lib/kubernetes/
    echo "Kubelet certificates and config moved successfully"
else
    echo "ERROR: Required kubelet files not found"
    ls -la ${HOSTNAME}*.pem ${HOSTNAME}.kubeconfig ca.pem 2>/dev/null || echo "Files missing"
    exit 1
fi

# Create the kubelet-config.yaml configuration file
cat > kubelet-config.yaml <<EOF
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
podCIDR: "$POD_CIDR"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/$HOSTNAME.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/$HOSTNAME-key.pem"
EOF

sudo mv kubelet-config.yaml /var/lib/kubelet/

# Create the kubelet.service systemd unit file
cat > kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Configure the Kubernetes Proxy
echo "Configuring Kubernetes Proxy..."
if [ -f "kube-proxy.kubeconfig" ]; then
    sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
    echo "kube-proxy.kubeconfig moved successfully"
else
    echo "ERROR: kube-proxy.kubeconfig not found"
    exit 1
fi

# Create the kube-proxy-config.yaml configuration file
cat > kube-proxy-config.yaml <<EOF
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF

sudo mv kube-proxy-config.yaml /var/lib/kube-proxy/

# Create the kube-proxy.service systemd unit file
cat > kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Install and start the Worker Services
echo "Installing and starting worker services..."
sudo mv containerd.service kubelet.service kube-proxy.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable containerd kubelet kube-proxy
sudo systemctl start containerd kubelet kube-proxy

# Wait for services to start
echo "Waiting for services to initialize..."
sleep 10

# Check service status
echo "Checking service status..."
echo "=== containerd status ==="
sudo systemctl status containerd --no-pager -l
echo ""
echo "=== kubelet status ==="
sudo systemctl status kubelet --no-pager -l
echo ""
echo "=== kube-proxy status ==="
sudo systemctl status kube-proxy --no-pager -l

echo "Kubernetes worker node installation completed on $(hostname)!"
'@

# Save the installation script to a temporary file with Unix line endings
$scriptPath = "C:\repos\kthw\scripts\09\install-kubernetes-worker.sh"
# Write with UTF8 encoding and convert to Unix line endings
$workerInstallScript -replace "`r`n", "`n" | Out-File -FilePath $scriptPath -Encoding UTF8 -NoNewline
# Add final newline
"`n" | Out-File -FilePath $scriptPath -Encoding UTF8 -Append -NoNewline

Write-Host "Created Kubernetes worker nodes installation script: $scriptPath"
Write-Host ""

# Execute the script on each worker instance
foreach ($i in 0..($workerInstances.Length - 1)) {
    $instance = $workerInstances[$i]
    $internalIP = $workerIPs[$i]
    $podCIDR = $podCIDRs[$i]
    
    Write-Host "=========================================="
    Write-Host "Configuring Kubernetes Worker Node on $instance (IP: $internalIP)"
    Write-Host "Pod CIDR: $podCIDR"
    Write-Host "=========================================="
    
    # Get the public IP address for SSH connection
    $publicIpAddress = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    
    Write-Host "Public IP for $instance : $publicIpAddress"
    
    # Copy required files to the worker
    Write-Host "Copying required files to $instance..."
    
    # Copy certificates, configs, and installation script
    scp -o StrictHostKeyChecking=no C:\repos\kthw\certs\ca.pem "kuberoot@${publicIpAddress}:~/"
    scp -o StrictHostKeyChecking=no "C:\repos\kthw\certs\$instance-key.pem" "kuberoot@${publicIpAddress}:~/"
    scp -o StrictHostKeyChecking=no "C:\repos\kthw\certs\$instance.pem" "kuberoot@${publicIpAddress}:~/"
    scp -o StrictHostKeyChecking=no "C:\repos\kthw\configs\$instance.kubeconfig" "kuberoot@${publicIpAddress}:~/"
    scp -o StrictHostKeyChecking=no C:\repos\kthw\configs\kube-proxy.kubeconfig "kuberoot@${publicIpAddress}:~/"
    scp -o StrictHostKeyChecking=no $scriptPath "kuberoot@${publicIpAddress}:~/"
    
    # Execute the installation script on the worker
    Write-Host "Executing Kubernetes worker node installation on $instance..."
    try {
        ssh -o StrictHostKeyChecking=no "kuberoot@$publicIpAddress" "chmod +x install-kubernetes-worker.sh && ./install-kubernetes-worker.sh"
        Write-Host "$instance Kubernetes worker node installation completed successfully!"
    }
    catch {
        Write-Host "ERROR: Failed to install Kubernetes worker node on $instance"
        Write-Host "Error: $_"
    }
    Write-Host ""
}

Write-Host "=========================================="
Write-Host "Verifying Kubernetes Worker Nodes"
Write-Host "=========================================="

# Verify the Kubernetes worker nodes from the first controller
$firstController = "controller-0"
$firstPublicIP = az network public-ip show -g kubernetes -n "$firstController-pip" --query "ipAddress" -o tsv

Write-Host "Verifying Kubernetes worker nodes from $firstController..."
Write-Host "Connecting to $firstController (Public IP: $firstPublicIP)"

Write-Host "Listing registered Kubernetes nodes..."
ssh -o StrictHostKeyChecking=no "kuberoot@$firstPublicIP" "kubectl get nodes --kubeconfig admin.kubeconfig"

Write-Host ""
Write-Host "Getting detailed node information..."
ssh -o StrictHostKeyChecking=no "kuberoot@$firstPublicIP" "kubectl get nodes -o wide --kubeconfig admin.kubeconfig"

Write-Host ""
Write-Host "=========================================="
Write-Host "Kubernetes Worker Nodes Bootstrap Complete!"
Write-Host "=========================================="
Write-Host ""
Write-Host "Successfully configured Kubernetes worker nodes:"
foreach ($i in 0..($workerInstances.Length - 1)) {
    $instance = $workerInstances[$i]
    $ip = $workerIPs[$i]
    $podCIDR = $podCIDRs[$i]
    Write-Host "- $instance ($ip) - Pod CIDR: $podCIDR"
}
Write-Host ""
Write-Host "Next step: Configuring kubectl for Remote Access"
Write-Host ""

# Cleanup temporary script
Remove-Item $scriptPath -Force
Write-Host "Cleaned up temporary installation script."

# Stop transcript
Stop-Transcript
Write-Host "`nExecution log saved to: $outputFile"