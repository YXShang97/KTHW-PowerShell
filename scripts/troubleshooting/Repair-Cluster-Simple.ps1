#requires -Version 5.1

<#
.SYNOPSIS
Simple troubleshooting tools for Kubernetes the Hard Way

.DESCRIPTION
Basic diagnostic and repair tools for common cluster issues.
Simplified version focusing on essential troubleshooting.

.NOTES
Author: KTHW PowerShell Tutorial
Version: 2.1-Simplified
Date: July 15, 2025
#>

param(
    [ValidateSet("etcd", "containerd", "networking", "all")]
    [string]$Component = "all",
    
    [switch]$AutoFix
)

# Import common functions
. "$PSScriptRoot\..\common\Common-Functions.ps1"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Kubernetes Simple Troubleshooting" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

function Test-EtcdService {
    Write-Host "Checking etcd service..." -ForegroundColor Yellow
    
    try {
        $controller0IP = Get-VmPublicIP -ResourceGroup "kubernetes" -VmName "controller-0"
        $status = Invoke-RemoteCommand -VmIP $controller0IP -Command "sudo systemctl is-active etcd"
        
        if ($status -eq "active") {
            Write-Host "✅ etcd service is running" -ForegroundColor Green
        } else {
            Write-Host "❌ etcd service is not active: $status" -ForegroundColor Red
            if ($AutoFix) {
                Write-Host "🔧 Restarting etcd..." -ForegroundColor Yellow
                Invoke-RemoteCommand -VmIP $controller0IP -Command "sudo systemctl restart etcd"
                Start-Sleep 5
                Write-Host "✅ etcd restart attempted" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Host "❌ etcd check failed: $_" -ForegroundColor Red
    }
}

function Test-ContainerdService {
    Write-Host "Checking containerd service..." -ForegroundColor Yellow
    
    $workers = @("worker-0", "worker-1")
    foreach ($worker in $workers) {
        try {
            $workerIP = Get-VmPublicIP -ResourceGroup "kubernetes" -VmName $worker
            $status = Invoke-RemoteCommand -VmIP $workerIP -Command "sudo systemctl is-active containerd"
            
            if ($status -eq "active") {
                Write-Host "✅ containerd on $worker is running" -ForegroundColor Green
            } else {
                Write-Host "❌ containerd on $worker is not active: $status" -ForegroundColor Red
                if ($AutoFix) {
                    Write-Host "🔧 Restarting containerd on $worker..." -ForegroundColor Yellow
                    Invoke-RemoteCommand -VmIP $workerIP -Command "sudo systemctl restart containerd"
                    Start-Sleep 3
                    Write-Host "✅ containerd restart attempted on $worker" -ForegroundColor Green
                }
            }
        }
        catch {
            Write-Host "❌ containerd check failed on ${worker}: $_" -ForegroundColor Red
        }
    }
}

function Test-BasicConnectivity {
    Write-Host "Checking basic connectivity..." -ForegroundColor Yellow
    
    try {
        # Test kubectl
        kubectl cluster-info --request-timeout=5s >$null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ kubectl connectivity working" -ForegroundColor Green
        } else {
            Write-Host "❌ kubectl connectivity failed" -ForegroundColor Red
            Write-Host "💡 Run script 10-configure-kubectl.ps1" -ForegroundColor Yellow
        }
        
        # Test nodes
        $nodes = kubectl get nodes --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $nodes) {
            $readyCount = ($nodes -split "`n" | Where-Object { $_ -match "Ready" }).Count
            Write-Host "✅ $readyCount nodes ready" -ForegroundColor Green
        } else {
            Write-Host "❌ No nodes found or not ready" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Connectivity check failed: $_" -ForegroundColor Red
    }
}

# Main execution
switch ($Component) {
    "etcd" { Test-EtcdService }
    "containerd" { Test-ContainerdService }
    "networking" { Test-BasicConnectivity }
    "all" {
        Test-EtcdService
        Write-Host ""
        Test-ContainerdService
        Write-Host ""
        Test-BasicConnectivity
    }
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Troubleshooting complete!" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

if (-not $AutoFix) {
    Write-Host ""
    Write-Host "💡 Use -AutoFix to automatically attempt repairs" -ForegroundColor Yellow
}
