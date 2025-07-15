#requires -Version 5.1

<#
.SYNOPSIS
Essential cluster validation for Kubernetes the Hard Way

.DESCRIPTION
Simplified validation script that checks core cluster functionality.
Focuses on the most important validation tests without unnecessary complexity.

.NOTES
Author: KTHW PowerShell Tutorial
Version: 2.1-Simplified
Date: July 15, 2025
#>

param(
    [switch]$SkipNetworkTests,
    [switch]$Verbose
)

# Import common functions
. "$PSScriptRoot\..\common\Common-Functions.ps1"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Kubernetes Cluster Validation (Simplified)" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

$passCount = 0
$failCount = 0

#region Essential Validation

Write-Host "Step 1: Basic Infrastructure Check..." -ForegroundColor Yellow

try {
    # Check Azure authentication
    Test-AzureAuthentication
    Write-Host "✅ Azure authentication" -ForegroundColor Green
    $passCount++
    
    # Check resource group
    $rg = az group show --name kubernetes --query "name" -o tsv 2>$null
    if ($rg -eq "kubernetes") {
        Write-Host "✅ Resource group exists" -ForegroundColor Green
        $passCount++
    } else {
        Write-Host "❌ Resource group not found" -ForegroundColor Red
        $failCount++
    }
    
    # Check key VMs
    $vms = @("controller-0", "worker-0", "worker-1")
    foreach ($vm in $vms) {
        $vmStatus = az vm show -g kubernetes -n $vm --query "powerState" -o tsv 2>$null
        if ($vmStatus -eq "VM running") {
            Write-Host "✅ $vm running" -ForegroundColor Green
            $passCount++
        } else {
            Write-Host "❌ $vm not running" -ForegroundColor Red
            $failCount++
        }
    }
}
catch {
    Write-Host "❌ Infrastructure check failed: $_" -ForegroundColor Red
    $failCount++
}

Write-Host ""
Write-Host "Step 2: Kubernetes Cluster Check..." -ForegroundColor Yellow

try {
    # Check kubectl configuration
    $kubeConfig = kubectl config current-context 2>$null
    if ($LASTEXITCODE -eq 0 -and $kubeConfig -eq "kubernetes-the-hard-way") {
        Write-Host "✅ kubectl configured" -ForegroundColor Green
        $passCount++
        
        # Check cluster connectivity
        kubectl cluster-info --request-timeout=10s >$null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Cluster connectivity" -ForegroundColor Green
            $passCount++
            
            # Check nodes
            $nodes = kubectl get nodes --no-headers 2>$null
            if ($LASTEXITCODE -eq 0) {
                $readyNodes = ($nodes -split "`n" | Where-Object { $_ -match "Ready" }).Count
                Write-Host "✅ Nodes ready: $readyNodes" -ForegroundColor Green
                $passCount++
            } else {
                Write-Host "❌ Cannot get node status" -ForegroundColor Red
                $failCount++
            }
        } else {
            Write-Host "❌ Cluster not accessible" -ForegroundColor Red
            $failCount++
        }
    } else {
        Write-Host "❌ kubectl not configured" -ForegroundColor Red
        Write-Host "💡 Run script 10-configure-kubectl.ps1" -ForegroundColor Yellow
        $failCount++
    }
}
catch {
    Write-Host "❌ Kubernetes check failed: $_" -ForegroundColor Red
    $failCount++
}

#endregion

#region Simple Results Summary

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Validation Results" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "📊 Results: ✅ $passCount passed, ❌ $failCount failed" -ForegroundColor White

if ($failCount -eq 0) {
    Write-Host ""
    Write-Host "🎉 All tests passed! Cluster is healthy." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "⚠️ Some tests failed. Check the output above for details." -ForegroundColor Yellow
    Write-Host "💡 Run individual scripts to fix issues, then re-validate." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan

#endregion
