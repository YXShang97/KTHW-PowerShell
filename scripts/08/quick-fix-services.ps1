#requires -Version 5.1
<#
.SYNOPSIS
    [DEPRECATED] Quick Fix for Step 08 Service Files - Fix line continuation issues

.DESCRIPTION
    ⚠️  This script is now DEPRECATED as the main 08-bootstrapping-CP.ps1 script has been 
    updated to use single-line ExecStart format to avoid PowerShell escaping issues.
    
    This script was used to fix systemd service files that had double backslashes
    and missing service-account-issuer URL when the main script had PowerShell 
    here-document escaping problems.
    
    Use the updated 08-bootstrapping-CP.ps1 script instead.

.NOTES
    Kept for reference and emergency troubleshooting if needed.
#>

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Quick Fix for Service Files" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

$controllers = @("controller-0", "controller-1", "controller-2")

function Get-ControllerPublicIP($controllerName) {
    return az network public-ip show -g kubernetes -n "$controllerName-pip" --query "ipAddress" -o tsv
}

function Get-ControllerInternalIP($controllerName) {
    $index = [int]$controllerName.Split('-')[1]
    return "10.240.0.$((10 + $index))"
}

foreach ($controller in $controllers) {
    $publicIP = Get-ControllerPublicIP $controller
    $internalIP = Get-ControllerInternalIP $controller
    Write-Host "Quick fix for $controller ($internalIP)..." -ForegroundColor Yellow
    
    # Stop services
    Write-Host "  Stopping services..." -ForegroundColor Cyan
    ssh kuberoot@$publicIP "sudo systemctl stop kube-apiserver kube-controller-manager kube-scheduler"
    
    # Fix the API server service file by replacing double backslashes and fixing the issuer URL
    Write-Host "  Fixing API server service..." -ForegroundColor Cyan
    ssh kuberoot@$publicIP "sudo sed -i 's/\\\\\\\\/\\\\/g' /etc/systemd/system/kube-apiserver.service"
    ssh kuberoot@$publicIP "sudo sed -i 's|--service-account-issuer=https:// \\\\|--service-account-issuer=https://$internalIP:6443 \\\\|g' /etc/systemd/system/kube-apiserver.service"
    
    # Fix the controller manager service file
    Write-Host "  Fixing controller manager service..." -ForegroundColor Cyan  
    ssh kuberoot@$publicIP "sudo sed -i 's/\\\\\\\\/\\\\/g' /etc/systemd/system/kube-controller-manager.service"
    
    # Fix the scheduler service file
    Write-Host "  Fixing scheduler service..." -ForegroundColor Cyan
    ssh kuberoot@$publicIP "sudo sed -i 's/\\\\\\\\/\\\\/g' /etc/systemd/system/kube-scheduler.service"
    
    # Reload and start services
    Write-Host "  Reloading and starting services..." -ForegroundColor Cyan
    ssh kuberoot@$publicIP "sudo systemctl daemon-reload"
    ssh kuberoot@$publicIP "sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler"
    
    Write-Host "  ✅ $controller fixed" -ForegroundColor Green
}

Write-Host ""
Write-Host "Waiting 10 seconds for services to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host ""
Write-Host "Checking service status..." -ForegroundColor Yellow
foreach ($controller in $controllers) {
    $publicIP = Get-ControllerPublicIP $controller
    $status = ssh kuberoot@$publicIP "sudo systemctl is-active kube-apiserver kube-controller-manager kube-scheduler 2>/dev/null"
    $statusArray = $status -split "`n"
    $activeCount = ($statusArray | Where-Object { $_ -eq "active" }).Count
    
    if ($activeCount -eq 3) {
        Write-Host "  ✅ ${controller}: All services active" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ ${controller}: $activeCount/3 services active" -ForegroundColor Yellow
        Write-Host "    API Server: $($statusArray[0])" -ForegroundColor Gray
        Write-Host "    Controller Manager: $($statusArray[1])" -ForegroundColor Gray  
        Write-Host "    Scheduler: $($statusArray[2])" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "✅ Quick fix complete! Services should now be running." -ForegroundColor Green
