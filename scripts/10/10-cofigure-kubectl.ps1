# This file recreates the bash script from the kubernetes-the-hard-way repository but using PowerShell syntax
# This is from tutorial 10: Configuring kubectl for Remote Access - https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/10-configuring-kubectl.md
# In this lab you will generate a kubeconfig file for the kubectl command line utility based on the admin user credentials.

# This script configures kubectl for remote access to the Kubernetes cluster from your Windows machine

# Start transcript to capture all output
$outputFile = "C:\repos\kthw\scripts\10\10-execution-output.txt"
Start-Transcript -Path $outputFile -Force

Write-Host "=========================================="
Write-Host "Configuring kubectl for Remote Access"
Write-Host "=========================================="
Write-Host ""

Write-Host "This script will configure kubectl to access the Kubernetes cluster remotely."
Write-Host "The following actions will be performed:"
Write-Host "1. Retrieve the Kubernetes public load balancer IP address"
Write-Host "2. Configure kubectl cluster settings"
Write-Host "3. Configure kubectl admin user credentials"
Write-Host "4. Set kubectl context"
Write-Host "5. Verify cluster access and health"
Write-Host ""

# Ensure we're in the correct directory with certificates
$certsPath = "C:\repos\kthw\certs"
if (-not (Test-Path $certsPath)) {
    Write-Host "ERROR: Certificates directory not found at $certsPath"
    Stop-Transcript
    exit 1
}

# Change to certs directory to access the certificate files
Set-Location $certsPath
Write-Host "Working from certificates directory: $certsPath"
Write-Host ""

Write-Host "=========================================="
Write-Host "Retrieving Kubernetes Public IP Address"
Write-Host "=========================================="

# Retrieve the kubernetes-the-hard-way static IP address
Write-Host "Getting the public IP address of the Kubernetes load balancer..."
try {
    $kubernetesPublicAddress = az network public-ip show -g kubernetes -n kubernetes-pip --query ipAddress -o tsv
    if (-not $kubernetesPublicAddress) {
        throw "Failed to retrieve public IP address"
    }
    Write-Host "Kubernetes public IP address: $kubernetesPublicAddress"
}
catch {
    Write-Host "ERROR: Failed to retrieve Kubernetes public IP address"
    Write-Host "Error: $_"
    Stop-Transcript
    exit 1
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Configuring kubectl"
Write-Host "=========================================="

# Verify required certificate files exist
$requiredFiles = @("ca.pem", "admin.pem", "admin-key.pem")
foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        Write-Host "ERROR: Required certificate file not found: $file"
        Stop-Transcript
        exit 1
    }
}
Write-Host "✓ All required certificate files found"
Write-Host ""

# Generate a kubeconfig file suitable for authenticating as the admin user
Write-Host "Setting cluster configuration..."
try {
    $clusterResult = kubectl config set-cluster kubernetes-the-hard-way --certificate-authority=ca.pem --embed-certs=true --server="https://$kubernetesPublicAddress`:6443"
    Write-Host "✓ Cluster configuration set successfully"
    Write-Host "   $clusterResult"
}
catch {
    Write-Host "ERROR: Failed to set cluster configuration"
    Write-Host "Error: $_"
    Stop-Transcript
    exit 1
}

Write-Host ""
Write-Host "Setting admin user credentials..."
try {
    $credentialsResult = kubectl config set-credentials admin --client-certificate=admin.pem --client-key=admin-key.pem
    Write-Host "✓ Admin credentials set successfully"
    Write-Host "   $credentialsResult"
}
catch {
    Write-Host "ERROR: Failed to set admin credentials"
    Write-Host "Error: $_"
    Stop-Transcript
    exit 1
}

Write-Host ""
Write-Host "Setting kubectl context..."
try {
    $contextResult = kubectl config set-context kubernetes-the-hard-way --cluster=kubernetes-the-hard-way --user=admin
    Write-Host "✓ Context set successfully"
    Write-Host "   $contextResult"
}
catch {
    Write-Host "ERROR: Failed to set context"
    Write-Host "Error: $_"
    Stop-Transcript
    exit 1
}

Write-Host ""
Write-Host "Switching to kubernetes-the-hard-way context..."
try {
    $useContextResult = kubectl config use-context kubernetes-the-hard-way
    Write-Host "✓ Context switched successfully"
    Write-Host "   $useContextResult"
}
catch {
    Write-Host "ERROR: Failed to switch context"
    Write-Host "Error: $_"
    Stop-Transcript
    exit 1
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Verifying Kubernetes Cluster Access"
Write-Host "=========================================="

# Check the health of the remote Kubernetes cluster
Write-Host "Checking cluster component health..."
try {
    $componentStatus = kubectl get componentstatuses
    Write-Host "✓ Cluster components status:"
    Write-Host $componentStatus
}
catch {
    Write-Host "ERROR: Failed to get component status"
    Write-Host "Error: $_"
}

Write-Host ""
Write-Host "Listing cluster nodes..."
try {
    $nodesStatus = kubectl get nodes
    Write-Host "✓ Cluster nodes:"
    Write-Host $nodesStatus
}
catch {
    Write-Host "ERROR: Failed to get nodes status"
    Write-Host "Error: $_"
}

Write-Host ""
Write-Host "Getting detailed cluster information..."
try {
    $clusterInfo = kubectl cluster-info
    Write-Host "✓ Cluster information:"
    Write-Host $clusterInfo
}
catch {
    Write-Host "⚠ Failed to get cluster info (this may be expected)"
}

Write-Host ""
Write-Host "Verifying current kubectl context..."
try {
    $currentContext = kubectl config current-context
    Write-Host "✓ Current kubectl context: $currentContext"
}
catch {
    Write-Host "ERROR: Failed to get current context"
}

Write-Host ""
Write-Host "Displaying kubeconfig view..."
try {
    $kubeconfigView = kubectl config view --minify
    Write-Host "✓ Current kubeconfig configuration:"
    Write-Host $kubeconfigView
}
catch {
    Write-Host "⚠ Failed to display kubeconfig view"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "kubectl Configuration Complete!"
Write-Host "=========================================="
Write-Host ""
Write-Host "✓ kubectl has been successfully configured for remote access"
Write-Host "✓ Cluster endpoint: https://$kubernetesPublicAddress`:6443"
Write-Host "✓ Current context: kubernetes-the-hard-way"
Write-Host "✓ Admin user credentials configured"
Write-Host ""
Write-Host "You can now use kubectl commands to manage your Kubernetes cluster:"
Write-Host "  kubectl get nodes"
Write-Host "  kubectl get pods --all-namespaces"
Write-Host "  kubectl get componentstatuses"
Write-Host ""
Write-Host "Next step: Provisioning Pod Network Routes"
Write-Host ""

# Return to original directory
Set-Location "C:\repos\kthw"

# Stop transcript
Stop-Transcript
Write-Host "`nExecution log saved to: $outputFile"