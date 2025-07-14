# Tutorial Step 10: Configuring kubectl for Remote Access
# URL: https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/10-configuring-kubectl.md
# Description: Generate a kubeconfig file for kubectl command line utility based on admin user credentials

Write-Host "===============================================" -ForegroundColor Green
Write-Host "Tutorial Step 10: Configuring kubectl for Remote Access" -ForegroundColor Green  
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""

# Ensure we're in the correct directory (where certificates are located)
$certsPath = "c:\repos\kthw\certs"
if (!(Test-Path $certsPath)) {
    Write-Error "Certificates directory not found at $certsPath"
    Write-Error "Please ensure you've completed the previous steps and certificates exist"
    exit 1
}

Set-Location $certsPath
Write-Host "Working directory: $(Get-Location)" -ForegroundColor Yellow
Write-Host ""

# Step 1: Retrieve the Kubernetes API Server Public IP
Write-Host "Step 1: Retrieving Kubernetes API Server public IP address..." -ForegroundColor Cyan

try {
    $KUBERNETES_PUBLIC_ADDRESS = az network public-ip show -g kubernetes -n kubernetes-pip --query ipAddress -o tsv
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve public IP address"
    }
    Write-Host "  ✅ Kubernetes API Server IP: $KUBERNETES_PUBLIC_ADDRESS" -ForegroundColor Green
}
catch {
    Write-Error "Failed to retrieve Kubernetes public IP address: $_"
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  - Ensure Azure CLI is authenticated: az login" -ForegroundColor Yellow
    Write-Host "  - Verify resource group 'kubernetes' exists" -ForegroundColor Yellow
    Write-Host "  - Check if public IP 'kubernetes-pip' exists" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Step 2: Configure kubectl cluster settings
Write-Host "Step 2: Configuring kubectl cluster settings..." -ForegroundColor Cyan

try {
    kubectl config set-cluster kubernetes-the-hard-way `
        --certificate-authority=ca.pem `
        --embed-certs=true `
        --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set cluster configuration"
    }
    Write-Host "  ✅ Cluster configuration set successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to configure cluster: $_"
    exit 1
}

# Step 3: Configure kubectl user credentials
Write-Host "Step 3: Configuring kubectl admin user credentials..." -ForegroundColor Cyan

try {
    kubectl config set-credentials admin `
        --client-certificate=admin.pem `
        --client-key=admin-key.pem
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set user credentials"
    }
    Write-Host "  ✅ Admin user credentials configured" -ForegroundColor Green
}
catch {
    Write-Error "Failed to configure admin credentials: $_"
    exit 1
}

# Step 4: Configure kubectl context
Write-Host "Step 4: Configuring kubectl context..." -ForegroundColor Cyan

try {
    kubectl config set-context kubernetes-the-hard-way `
        --cluster=kubernetes-the-hard-way `
        --user=admin
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set context"
    }
    Write-Host "  ✅ Context 'kubernetes-the-hard-way' created" -ForegroundColor Green
}
catch {
    Write-Error "Failed to set context: $_"
    exit 1
}

# Step 5: Switch to the new context
Write-Host "Step 5: Switching to the kubernetes-the-hard-way context..." -ForegroundColor Cyan

try {
    kubectl config use-context kubernetes-the-hard-way
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to switch context"
    }
    Write-Host "  ✅ Successfully switched to 'kubernetes-the-hard-way' context" -ForegroundColor Green
}
catch {
    Write-Error "Failed to switch context: $_"
    exit 1
}

Write-Host ""

# Step 6: Verify cluster connectivity and health
Write-Host "Step 6: Verifying cluster connectivity..." -ForegroundColor Cyan

Write-Host "  Checking component status..." -ForegroundColor Yellow
try {
    kubectl get componentstatuses
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Component status check failed - this is expected in newer Kubernetes versions"
        Write-Host "  ℹ️  componentstatuses API is deprecated in Kubernetes v1.26+" -ForegroundColor Blue
    } else {
        Write-Host "  ✅ Component status retrieved successfully" -ForegroundColor Green
    }
}
catch {
    Write-Warning "Component status check failed: $_"
    Write-Host "  ℹ️  This is expected in Kubernetes v1.26+ where componentstatuses is deprecated" -ForegroundColor Blue
}

Write-Host ""
Write-Host "  Checking node status..." -ForegroundColor Yellow
try {
    kubectl get nodes
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve node status"
    }
    Write-Host "  ✅ Node status retrieved successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to check node status: $_"
    Write-Host "This indicates a connectivity or authentication issue" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 7: Display current kubectl configuration
Write-Host "Step 7: Current kubectl configuration summary..." -ForegroundColor Cyan
Write-Host "  Current context:" -ForegroundColor Yellow
kubectl config current-context

Write-Host "  Cluster info:" -ForegroundColor Yellow
kubectl cluster-info

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "✅ kubectl Remote Access Configuration Complete" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "🎯 Next Step: Tutorial Step 11 - Provisioning Pod Network Routes" -ForegroundColor Blue
Write-Host ""
Write-Host "You can now manage your Kubernetes cluster remotely using kubectl!" -ForegroundColor Green
Write-Host "Example commands to try:" -ForegroundColor Yellow
Write-Host "  kubectl get nodes" -ForegroundColor White
Write-Host "  kubectl get pods --all-namespaces" -ForegroundColor White
Write-Host "  kubectl cluster-info" -ForegroundColor White