#requires -Version 5.1
<#
.SYNOPSIS
    Tutorial Step 05: Generating Kubernetes Configuration Files for Authentication

.DESCRIPTION
    In this lab you will generate Kubernetes configuration files, also known as kubeconfigs,
    which enable Kubernetes clients to locate and authenticate to the Kubernetes API Servers.
    These configuration files will be used by kubelet, kube-proxy, kube-controller-manager,
    kube-scheduler, and admin users.

.NOTES
    Tutorial Step: 05
    Tutorial Name: Generating Kubernetes Configuration Files for Authentication
    Original URL: https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/05-kubernetes-configuration-files.md
    
    Prerequisites:
    - kubectl installed and available in PATH
    - Certificates generated from Tutorial Step 04
    - Azure infrastructure deployed (Tutorial Step 03)
#>

# Set working directory to configs folder
$configsPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\configs"
if (-not (Test-Path $configsPath)) {
    New-Item -ItemType Directory -Path $configsPath -Force | Out-Null
}

# Set path to certificates
$certsPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\certs"

# Change to configs directory for kubeconfig generation
Set-Location $configsPath

Write-Host "Working in: $(Get-Location)" -ForegroundColor Green
Write-Host "Certificates path: $certsPath" -ForegroundColor Gray

# Get the Kubernetes public IP address (load balancer)
Write-Host "Retrieving Kubernetes public IP address..." -ForegroundColor Yellow
$kubernetesPublicAddress = az network public-ip show -g kubernetes -n kubernetes-pip --query "ipAddress" -o tsv
Write-Host "Kubernetes API Server Public IP: $kubernetesPublicAddress" -ForegroundColor Cyan

# Generate kubelet kubeconfig files for worker nodes
Write-Host "Generating kubelet kubeconfig files for worker nodes..." -ForegroundColor Yellow
$workers = @("worker-0", "worker-1")

foreach ($instance in $workers) {
    Write-Host "Creating kubeconfig for $instance..." -ForegroundColor Cyan
    
    # Set cluster configuration
    kubectl config set-cluster kubernetes-the-hard-way `
        --certificate-authority="$certsPath\ca.pem" `
        --embed-certs=true `
        --server="https://$kubernetesPublicAddress`:6443" `
        --kubeconfig="$instance.kubeconfig"
    
    # Set user credentials
    kubectl config set-credentials "system:node:$instance" `
        --client-certificate="$certsPath\$instance.pem" `
        --client-key="$certsPath\$instance-key.pem" `
        --embed-certs=true `
        --kubeconfig="$instance.kubeconfig"
    
    # Set context
    kubectl config set-context default `
        --cluster=kubernetes-the-hard-way `
        --user="system:node:$instance" `
        --kubeconfig="$instance.kubeconfig"
    
    # Use context
    kubectl config use-context default --kubeconfig="$instance.kubeconfig"
    
    Write-Host "✅ Created $instance.kubeconfig" -ForegroundColor Green
}

# Generate kube-proxy kubeconfig file
Write-Host "Generating kube-proxy kubeconfig file..." -ForegroundColor Yellow

kubectl config set-cluster kubernetes-the-hard-way `
    --certificate-authority="$certsPath\ca.pem" `
    --embed-certs=true `
    --server="https://$kubernetesPublicAddress`:6443" `
    --kubeconfig="kube-proxy.kubeconfig"

kubectl config set-credentials kube-proxy `
    --client-certificate="$certsPath\kube-proxy.pem" `
    --client-key="$certsPath\kube-proxy-key.pem" `
    --embed-certs=true `
    --kubeconfig="kube-proxy.kubeconfig"

kubectl config set-context default `
    --cluster=kubernetes-the-hard-way `
    --user=kube-proxy `
    --kubeconfig="kube-proxy.kubeconfig"

kubectl config use-context default --kubeconfig="kube-proxy.kubeconfig"

Write-Host "✅ Created kube-proxy.kubeconfig" -ForegroundColor Green

# Generate kube-controller-manager kubeconfig file
Write-Host "Generating kube-controller-manager kubeconfig file..." -ForegroundColor Yellow

kubectl config set-cluster kubernetes-the-hard-way `
    --certificate-authority="$certsPath\ca.pem" `
    --embed-certs=true `
    --server="https://127.0.0.1:6443" `
    --kubeconfig="kube-controller-manager.kubeconfig"

kubectl config set-credentials system:kube-controller-manager `
    --client-certificate="$certsPath\kube-controller-manager.pem" `
    --client-key="$certsPath\kube-controller-manager-key.pem" `
    --embed-certs=true `
    --kubeconfig="kube-controller-manager.kubeconfig"

kubectl config set-context default `
    --cluster=kubernetes-the-hard-way `
    --user=system:kube-controller-manager `
    --kubeconfig="kube-controller-manager.kubeconfig"

kubectl config use-context default --kubeconfig="kube-controller-manager.kubeconfig"

Write-Host "✅ Created kube-controller-manager.kubeconfig" -ForegroundColor Green

# Generate kube-scheduler kubeconfig file
Write-Host "Generating kube-scheduler kubeconfig file..." -ForegroundColor Yellow

kubectl config set-cluster kubernetes-the-hard-way `
    --certificate-authority="$certsPath\ca.pem" `
    --embed-certs=true `
    --server="https://127.0.0.1:6443" `
    --kubeconfig="kube-scheduler.kubeconfig"

kubectl config set-credentials system:kube-scheduler `
    --client-certificate="$certsPath\kube-scheduler.pem" `
    --client-key="$certsPath\kube-scheduler-key.pem" `
    --embed-certs=true `
    --kubeconfig="kube-scheduler.kubeconfig"

kubectl config set-context default `
    --cluster=kubernetes-the-hard-way `
    --user=system:kube-scheduler `
    --kubeconfig="kube-scheduler.kubeconfig"

kubectl config use-context default --kubeconfig="kube-scheduler.kubeconfig"

Write-Host "✅ Created kube-scheduler.kubeconfig" -ForegroundColor Green

# Generate admin kubeconfig file
Write-Host "Generating admin kubeconfig file..." -ForegroundColor Yellow

kubectl config set-cluster kubernetes-the-hard-way `
    --certificate-authority="$certsPath\ca.pem" `
    --embed-certs=true `
    --server="https://127.0.0.1:6443" `
    --kubeconfig="admin.kubeconfig"

kubectl config set-credentials admin `
    --client-certificate="$certsPath\admin.pem" `
    --client-key="$certsPath\admin-key.pem" `
    --embed-certs=true `
    --kubeconfig="admin.kubeconfig"

kubectl config set-context default `
    --cluster=kubernetes-the-hard-way `
    --user=admin `
    --kubeconfig="admin.kubeconfig"

kubectl config use-context default --kubeconfig="admin.kubeconfig"

Write-Host "✅ Created admin.kubeconfig" -ForegroundColor Green

# Distribute kubeconfig files to worker instances
Write-Host "Distributing kubeconfig files to worker instances..." -ForegroundColor Yellow

foreach ($instance in $workers) {
    $publicIP = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    Write-Host "Copying to $instance ($publicIP)..." -ForegroundColor Cyan
    
    & scp "$instance.kubeconfig" "kube-proxy.kubeconfig" "kuberoot@$publicIP`:~/"
    Write-Host "✅ Copied kubeconfig files to $instance" -ForegroundColor Green
}

# Distribute kubeconfig files to controller instances
Write-Host "Distributing kubeconfig files to controller instances..." -ForegroundColor Yellow
$controllers = @("controller-0", "controller-1", "controller-2")

foreach ($instance in $controllers) {
    $publicIP = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    Write-Host "Copying to $instance ($publicIP)..." -ForegroundColor Cyan
    
    & scp "admin.kubeconfig" "kube-controller-manager.kubeconfig" "kube-scheduler.kubeconfig" "kuberoot@$publicIP`:~/"
    Write-Host "✅ Copied kubeconfig files to $instance" -ForegroundColor Green
}

Write-Host "Kubeconfig generation and distribution complete!" -ForegroundColor Green
Write-Host "Generated files:" -ForegroundColor Yellow
Get-ChildItem -Path "." -Filter "*.kubeconfig" | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor White }