# ============================================================================
# Quick Fix for etcd Certificate Issue
# ============================================================================

Write-Host "=== Quick etcd Certificate Fix ===" -ForegroundColor Green

$controllers = @("controller-0", "controller-1", "controller-2")

Write-Host "The issue: certificates are missing from /etc/etcd/ directory" -ForegroundColor Yellow
Write-Host "Solution: Copy certificates from home directory to /etc/etcd/" -ForegroundColor Cyan

foreach ($instance in $controllers) {
    $publicIP = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    Write-Host "`nFixing $instance ($publicIP)..." -ForegroundColor White
    
    # Stop etcd service first
    Write-Host "  Stopping etcd service..." -ForegroundColor Gray
    ssh -o ConnectTimeout=5 kuberoot@$publicIP "sudo systemctl stop etcd" 2>/dev/null
    
    # Create etcd directory and copy certificates
    Write-Host "  Setting up certificates..." -ForegroundColor Gray
    ssh -o ConnectTimeout=5 kuberoot@$publicIP "
        sudo mkdir -p /etc/etcd &&
        sudo cp ~/ca.pem ~/kubernetes.pem ~/kubernetes-key.pem /etc/etcd/ &&
        sudo chmod 600 /etc/etcd/* &&
        sudo chown root:root /etc/etcd/*
    " 2>/dev/null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Certificates fixed on $instance" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Failed to fix certificates on $instance" -ForegroundColor Red
    }
}

Write-Host "`nNow starting all etcd services simultaneously..." -ForegroundColor Yellow

# Start all etcd services at the same time (critical for cluster formation)
$jobs = @()
foreach ($instance in $controllers) {
    $publicIP = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    Write-Host "Starting etcd on $instance..." -ForegroundColor Cyan
    
    $job = Start-Job -ScriptBlock {
        param($ip)
        ssh -o ConnectTimeout=5 kuberoot@$ip "sudo systemctl start etcd"
    } -ArgumentList $publicIP
    
    $jobs += $job
}

# Wait for all services to start
Write-Host "Waiting for services to start..." -ForegroundColor Gray
$jobs | Wait-Job -Timeout 30 | Out-Null
$jobs | Remove-Job -Force

Write-Host "`nWaiting 10 seconds for cluster to stabilize..." -ForegroundColor Yellow
Start-Sleep 10

Write-Host "`nVerifying etcd cluster..." -ForegroundColor Yellow
$publicIP = az network public-ip show -g kubernetes -n "controller-0-pip" --query "ipAddress" -o tsv
$internalIP = ssh -o ConnectTimeout=5 kuberoot@$publicIP "hostname -I | awk '{print \$1}'"

$verifyCmd = "sudo ETCDCTL_API=3 etcdctl member list --endpoints=https://$internalIP:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem"

Write-Host "Running verification command..." -ForegroundColor Cyan
$result = ssh -o ConnectTimeout=10 kuberoot@$publicIP $verifyCmd 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ etcd cluster is working!" -ForegroundColor Green
    Write-Host "Cluster members:" -ForegroundColor Cyan
    $result | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
} else {
    Write-Host "`n❌ etcd cluster verification failed" -ForegroundColor Red
    Write-Host "Error: $result" -ForegroundColor Red
    
    Write-Host "`nQuick status check:" -ForegroundColor Yellow
    foreach ($instance in $controllers) {
        $ip = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
        $status = ssh -o ConnectTimeout=3 kuberoot@$ip "sudo systemctl is-active etcd" 2>/dev/null
        Write-Host "$instance`: $status" -ForegroundColor White
    }
}

Write-Host "`netcd fix script complete!" -ForegroundColor Green
