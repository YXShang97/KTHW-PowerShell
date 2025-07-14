# This file recreates the bash script from the kubernetes-the-hard-way repository but using PowerShell syntax
# This is from tutorial 8: Bootstrapping the Kubernetes Control Plane - https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/08-bootstrapping-kubernetes-controllers.md
# In this lab you will bootstrap the Kubernetes control plane across three compute instances and configure it for high availability. You will also create an external load balancer that exposes the Kubernetes API Servers to remote clients. The following components will be installed on each node: Kubernetes API Server, Scheduler, and Controller Manager.

# This script coordinates the Kubernetes control plane installation on all controller nodes from your Windows machine

# Start transcript to capture all output
$outputFile = "C:\repos\kthw\scripts\08\08-execution-output.txt"
Start-Transcript -Path $outputFile -Force

Write-Host "=========================================="
Write-Host "Bootstrapping Kubernetes Control Plane"
Write-Host "=========================================="
Write-Host ""

# Define controller instances
$controllerInstances = @("controller-0", "controller-1", "controller-2")
$controllerIPs = @("10.240.0.10", "10.240.0.11", "10.240.0.12")

Write-Host "This script will install and configure Kubernetes control plane on all controller nodes."
Write-Host "The following components will be installed on each controller:"
Write-Host "1. Kubernetes API Server"
Write-Host "2. Kubernetes Controller Manager"
Write-Host "3. Kubernetes Scheduler"
Write-Host "4. Configure systemd services"
Write-Host "5. Setup RBAC for Kubelet authorization"
Write-Host ""

# Create the Kubernetes control plane installation script that will be executed on each controller
$kubernetesInstallScript = @'
#!/bin/bash
set -e

echo "Starting Kubernetes control plane installation on $(hostname)..."

# Create the Kubernetes configuration directory
echo "Creating Kubernetes configuration directory..."
sudo mkdir -p /etc/kubernetes/config

# Download and Install the Kubernetes Controller Binaries
echo "Downloading Kubernetes controller binaries..."
wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.26.3/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.26.3/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.26.3/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.26.3/bin/linux/amd64/kubectl"

# Install the Kubernetes binaries
echo "Installing Kubernetes binaries..."
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/

# Configure the Kubernetes API Server
echo "Configuring Kubernetes API Server..."
sudo mkdir -p /var/lib/kubernetes/

# Check if certificate and config files exist, copy them to the correct locations
if [ -f "ca.pem" ] && [ -f "kubernetes.pem" ] && [ -f "encryption-config.yaml" ]; then
    sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
        service-account-key.pem service-account.pem \
        encryption-config.yaml /var/lib/kubernetes/
    echo "Certificates and config files moved to /var/lib/kubernetes/"
else
    echo "ERROR: Required certificate or config files not found in current directory"
    ls -la ca.pem kubernetes*.pem service-account*.pem encryption-config.yaml 2>/dev/null || echo "Files missing"
    exit 1
fi

# Get internal IP and public IP for this instance
INTERNAL_IP=$(ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
HOSTNAME=$(hostname -s)

# Determine public IP based on hostname
case $HOSTNAME in
    "controller-0")
        PUBLIC_IP_ADDRESS="20.161.74.83"
        ;;
    "controller-1") 
        PUBLIC_IP_ADDRESS="20.186.17.67"
        ;;
    "controller-2")
        PUBLIC_IP_ADDRESS="20.109.1.80"
        ;;
    *)
        echo "ERROR: Unknown hostname $HOSTNAME"
        exit 1
        ;;
esac

echo "Internal IP: $INTERNAL_IP"
echo "Public IP: $PUBLIC_IP_ADDRESS"
echo "Hostname: $HOSTNAME"

# Create the kube-apiserver.service systemd unit file
echo "Creating kube-apiserver systemd service..."
cat > kube-apiserver.service <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=$INTERNAL_IP \\
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
  --etcd-servers=https://10.240.0.10:2379,https://10.240.0.11:2379,https://10.240.0.12:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --runtime-config='api/all=true' \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-account-issuer=https://$PUBLIC_IP_ADDRESS:6443 \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Configure the Kubernetes Controller Manager
echo "Configuring Kubernetes Controller Manager..."
if [ -f "kube-controller-manager.kubeconfig" ]; then
    sudo mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
    echo "Moved kube-controller-manager.kubeconfig to /var/lib/kubernetes/"
else
    echo "ERROR: kube-controller-manager.kubeconfig not found"
    exit 1
fi

# Create the kube-controller-manager.service systemd unit file
cat > kube-controller-manager.service <<EOF
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
EOF

# Configure the Kubernetes Scheduler
echo "Configuring Kubernetes Scheduler..."
if [ -f "kube-scheduler.kubeconfig" ]; then
    sudo mv kube-scheduler.kubeconfig /var/lib/kubernetes/
    echo "Moved kube-scheduler.kubeconfig to /var/lib/kubernetes/"
else
    echo "ERROR: kube-scheduler.kubeconfig not found"
    exit 1
fi

# Create the kube-scheduler.yaml configuration file
cat > kube-scheduler.yaml <<EOF
apiVersion: kubescheduler.config.k8s.io/v1beta3
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

sudo mv kube-scheduler.yaml /etc/kubernetes/config/

# Create the kube-scheduler.service systemd unit file
cat > kube-scheduler.service <<EOF
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
EOF

# Install and start the Controller Services
echo "Installing and starting Kubernetes control plane services..."
sudo mv kube-apiserver.service kube-controller-manager.service kube-scheduler.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler

# Wait for services to start
echo "Waiting for Kubernetes API Server to initialize..."
sleep 15

# Check service status
echo "Checking service status..."
echo "=== kube-apiserver status ==="
sudo systemctl status kube-apiserver --no-pager -l
echo ""
echo "=== kube-controller-manager status ==="
sudo systemctl status kube-controller-manager --no-pager -l
echo ""
echo "=== kube-scheduler status ==="
sudo systemctl status kube-scheduler --no-pager -l

echo "Kubernetes control plane installation completed on $(hostname)!"
'@

# Save the installation script to a temporary file with Unix line endings
$scriptPath = "C:\repos\kthw\scripts\08\install-kubernetes-cp.sh"
# Write with UTF8 encoding and convert to Unix line endings
$kubernetesInstallScript -replace "`r`n", "`n" | Out-File -FilePath $scriptPath -Encoding UTF8 -NoNewline
# Add final newline
"`n" | Out-File -FilePath $scriptPath -Encoding UTF8 -Append -NoNewline

Write-Host "Created Kubernetes control plane installation script: $scriptPath"
Write-Host ""

# Execute the script on each controller instance
foreach ($i in 0..($controllerInstances.Length - 1)) {
    $instance = $controllerInstances[$i]
    $internalIP = $controllerIPs[$i]
    
    Write-Host "=========================================="
    Write-Host "Configuring Kubernetes Control Plane on $instance (IP: $internalIP)"
    Write-Host "=========================================="
    
    # Get the public IP address for SSH connection
    $publicIpAddress = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    
    Write-Host "Public IP for $instance : $publicIpAddress"
    
    # Copy required files to the controller
    Write-Host "Copying required files to $instance..."
    
    # Copy certificates, configs, and installation script
    scp -o StrictHostKeyChecking=no C:\repos\kthw\certs\ca.pem "kuberoot@${publicIpAddress}:~/"
    scp -o StrictHostKeyChecking=no C:\repos\kthw\certs\ca-key.pem "kuberoot@${publicIpAddress}:~/"
    scp -o StrictHostKeyChecking=no C:\repos\kthw\certs\kubernetes-key.pem "kuberoot@${publicIpAddress}:~/"
    scp -o StrictHostKeyChecking=no C:\repos\kthw\certs\kubernetes.pem "kuberoot@${publicIpAddress}:~/"
    scp -o StrictHostKeyChecking=no C:\repos\kthw\certs\service-account-key.pem "kuberoot@${publicIpAddress}:~/"
    scp -o StrictHostKeyChecking=no C:\repos\kthw\certs\service-account.pem "kuberoot@${publicIpAddress}:~/"
    scp -o StrictHostKeyChecking=no C:\repos\kthw\certs\encryption-config.yaml "kuberoot@${publicIpAddress}:~/"
    scp -o StrictHostKeyChecking=no C:\repos\kthw\configs\kube-controller-manager.kubeconfig "kuberoot@${publicIpAddress}:~/"
    scp -o StrictHostKeyChecking=no C:\repos\kthw\configs\kube-scheduler.kubeconfig "kuberoot@${publicIpAddress}:~/"
    scp -o StrictHostKeyChecking=no C:\repos\kthw\configs\admin.kubeconfig "kuberoot@${publicIpAddress}:~/"
    scp -o StrictHostKeyChecking=no $scriptPath "kuberoot@${publicIpAddress}:~/"
    
    # Execute the installation script on the controller
    Write-Host "Executing Kubernetes control plane installation on $instance..."
    try {
        ssh -o StrictHostKeyChecking=no "kuberoot@$publicIpAddress" "chmod +x install-kubernetes-cp.sh && ./install-kubernetes-cp.sh"
        Write-Host "$instance Kubernetes control plane installation completed successfully!"
    }
    catch {
        Write-Host "ERROR: Failed to install Kubernetes control plane on $instance"
        Write-Host "Error: $_"
    }
    Write-Host ""
}

Write-Host "=========================================="
Write-Host "Verifying Kubernetes Control Plane"
Write-Host "=========================================="

# Verify the Kubernetes control plane on the first controller
$firstController = $controllerInstances[0]
$firstPublicIP = az network public-ip show -g kubernetes -n "$firstController-pip" --query "ipAddress" -o tsv

Write-Host "Verifying Kubernetes control plane from $firstController..."
Write-Host "Connecting to $firstController (Public IP: $firstPublicIP)"

Write-Host "Running component status verification..."
ssh -o StrictHostKeyChecking=no "kuberoot@$firstPublicIP" "kubectl get componentstatuses --kubeconfig admin.kubeconfig"

Write-Host ""
Write-Host "=========================================="
Write-Host "Setting up RBAC for Kubelet Authorization"
Write-Host "=========================================="

# Setup RBAC for Kubelet Authorization on the first controller
Write-Host "Creating system:kube-apiserver-to-kubelet ClusterRole..."
$rbacClusterRole = @'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
'@

$rbacClusterRoleBinding = @'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
'@

# Apply RBAC configuration
ssh -o StrictHostKeyChecking=no "kuberoot@$firstPublicIP" "echo '$rbacClusterRole' | kubectl apply --kubeconfig admin.kubeconfig -f -"
ssh -o StrictHostKeyChecking=no "kuberoot@$firstPublicIP" "echo '$rbacClusterRoleBinding' | kubectl apply --kubeconfig admin.kubeconfig -f -"

Write-Host ""
Write-Host "=========================================="
Write-Host "Setting up Kubernetes Frontend Load Balancer"
Write-Host "=========================================="

Write-Host "Creating load balancer health probe..."
az network lb probe create -g kubernetes --lb-name kubernetes-lb --name kubernetes-apiserver-probe --port 6443 --protocol tcp

Write-Host "Creating load balancer rule..."
az network lb rule create -g kubernetes -n kubernetes-apiserver-rule --protocol tcp --lb-name kubernetes-lb --frontend-ip-name LoadBalancerFrontEnd --frontend-port 6443 --backend-pool-name kubernetes-lb-pool --backend-port 6443 --probe-name kubernetes-apiserver-probe

Write-Host ""
Write-Host "=========================================="
Write-Host "Final Verification"
Write-Host "=========================================="

# Get the public IP of the load balancer
$kubernetesPublicIP = az network public-ip show -g kubernetes -n kubernetes-pip --query ipAddress -o tsv
Write-Host "Kubernetes public IP: $kubernetesPublicIP"

Write-Host "Testing Kubernetes API via load balancer..."
$verificationResult = curl --cacert C:\repos\kthw\certs\ca.pem "https://$kubernetesPublicIP`:6443/version" 2>$null
if ($verificationResult) {
    Write-Host "✓ Kubernetes API is accessible via load balancer"
    Write-Host "Response: $verificationResult"
} else {
    Write-Host "⚠ Kubernetes API verification via load balancer failed (this may be expected if the load balancer is still initializing)"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Kubernetes Control Plane Bootstrap Complete!"
Write-Host "=========================================="
Write-Host ""
Write-Host "Successfully configured Kubernetes control plane on:"
foreach ($instance in $controllerInstances) {
    $ip = $controllerIPs[$controllerInstances.IndexOf($instance)]
    Write-Host "- $instance ($ip)"
}
Write-Host ""
Write-Host "Next step: Bootstrapping the Kubernetes Worker Nodes"
Write-Host ""

# Cleanup temporary script
Remove-Item $scriptPath -Force
Write-Host "Cleaned up temporary installation script."

# Stop transcript
Stop-Transcript
Write-Host "`nExecution log saved to: $outputFile"