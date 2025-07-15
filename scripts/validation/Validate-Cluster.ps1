#requires -Version 5.1

<#
.SYNOPSIS
Comprehensive cluster validation script for Kubernetes the Hard Way

.DESCRIPTION
Validates all components of the Kubernetes cluster built through the tutorial.
Based on lessons learned from successful tutorial execution and common issues encountered.

.NOTES
Author: KTHW PowerShell Tutorial
Version: 2.0
Date: July 15, 2025
#>

param(
    [switch]$SkipNetworkTests,
    [switch]$Verbose
)

# Import common functions
. "$PSScriptRoot\..\common\Common-Functions.ps1"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Kubernetes Cluster Validation" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Test results tracking
$testResults = @()

function Add-TestResult {
    param($TestName, $Status, $Details = "")
    $testResults += [PSCustomObject]@{
        Test = $TestName
        Status = $Status
        Details = $Details
        Timestamp = Get-Date
    }
}

#region Azure Infrastructure Validation

Write-Host "Step 1: Validating Azure Infrastructure..." -ForegroundColor Yellow

try {
    # Validate Azure authentication
    Test-AzureAuthentication
    Add-TestResult "Azure Authentication" "✅ PASS"
    
    # Check resource group
    $rg = az group show --name kubernetes --query "name" -o tsv 2>$null
    if ($rg -eq "kubernetes") {
        Write-Host "✅ Resource group 'kubernetes' exists" -ForegroundColor Green
        Add-TestResult "Resource Group" "✅ PASS"
    } else {
        Write-Host "❌ Resource group 'kubernetes' not found" -ForegroundColor Red
        Add-TestResult "Resource Group" "❌ FAIL" "Resource group not found"
    }
    
    # Check VMs
    $vms = @("controller-0", "controller-1", "controller-2", "worker-0", "worker-1")
    foreach ($vm in $vms) {
        try {
            $vmStatus = az vm show -g kubernetes -n $vm --query "powerState" -o tsv 2>$null
            if ($vmStatus -eq "VM running") {
                Write-Host "✅ $vm is running" -ForegroundColor Green
                Add-TestResult "VM Status: $vm" "✅ PASS"
            } else {
                Write-Host "❌ $vm status: $vmStatus" -ForegroundColor Red
                Add-TestResult "VM Status: $vm" "❌ FAIL" $vmStatus
            }
        }
        catch {
            Write-Host "❌ Failed to check $vm status" -ForegroundColor Red
            Add-TestResult "VM Status: $vm" "❌ FAIL" "VM not found"
        }
    }
    
    # Check load balancer
    $lbIP = az network public-ip show -g kubernetes -n kubernetes-pip --query "ipAddress" -o tsv 2>$null
    if (![string]::IsNullOrEmpty($lbIP)) {
        Write-Host "✅ Load balancer public IP: $lbIP" -ForegroundColor Green
        Add-TestResult "Load Balancer IP" "✅ PASS" $lbIP
    } else {
        Write-Host "❌ Load balancer public IP not found" -ForegroundColor Red
        Add-TestResult "Load Balancer IP" "❌ FAIL"
    }
}
catch {
    Write-Host "❌ Azure infrastructure validation failed: $_" -ForegroundColor Red
    Add-TestResult "Azure Infrastructure" "❌ FAIL" $_.Exception.Message
}

#endregion

#region Network Connectivity Validation

if (-not $SkipNetworkTests) {
    Write-Host ""
    Write-Host "Step 2: Validating Network Connectivity..." -ForegroundColor Yellow
    
    try {
        # Test SSH connectivity to all VMs
        foreach ($vm in $vms) {
            try {
                $ip = Get-VmPublicIP -ResourceGroup "kubernetes" -VmName $vm
                $sshTest = Test-NetworkConnectivity -ComputerName $ip -Port 22
                
                if ($sshTest) {
                    # Test actual SSH command
                    $result = ssh kuberoot@$ip "echo 'SSH test successful'" 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "✅ SSH connectivity to $vm ($ip) successful" -ForegroundColor Green
                        Add-TestResult "SSH Connectivity: $vm" "✅ PASS"
                    } else {
                        Write-Host "❌ SSH authentication to $vm ($ip) failed" -ForegroundColor Red
                        Add-TestResult "SSH Connectivity: $vm" "❌ FAIL" "SSH auth failed"
                    }
                } else {
                    Add-TestResult "SSH Connectivity: $vm" "❌ FAIL" "Port 22 unreachable"
                }
            }
            catch {
                Write-Host "❌ Network test to $vm failed: $_" -ForegroundColor Red
                Add-TestResult "SSH Connectivity: $vm" "❌ FAIL" $_.Exception.Message
            }
        }
        
        # Test API server connectivity
        if (![string]::IsNullOrEmpty($lbIP)) {
            $apiTest = Test-NetworkConnectivity -ComputerName $lbIP -Port 6443
            if ($apiTest) {
                Write-Host "✅ API server port 6443 accessible on load balancer" -ForegroundColor Green
                Add-TestResult "API Server Connectivity" "✅ PASS"
            } else {
                Write-Host "❌ API server port 6443 not accessible on load balancer" -ForegroundColor Red
                Add-TestResult "API Server Connectivity" "❌ FAIL"
            }
        }
    }
    catch {
        Write-Host "❌ Network connectivity validation failed: $_" -ForegroundColor Red
        Add-TestResult "Network Connectivity" "❌ FAIL" $_.Exception.Message
    }
}

#endregion

#region Kubernetes Cluster Validation

Write-Host ""
Write-Host "Step 3: Validating Kubernetes Cluster..." -ForegroundColor Yellow

try {
    # Check if kubectl is configured
    $kubeConfig = kubectl config current-context 2>$null
    if ($LASTEXITCODE -eq 0 -and $kubeConfig -eq "kubernetes-the-hard-way") {
        Write-Host "✅ kubectl configured with kubernetes-the-hard-way context" -ForegroundColor Green
        Add-TestResult "kubectl Configuration" "✅ PASS"
        
        # Test cluster connectivity
        $clusterInfo = kubectl cluster-info 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Cluster connectivity successful" -ForegroundColor Green
            Add-TestResult "Cluster Connectivity" "✅ PASS"
            
            # Check component status
            $componentStatus = kubectl get componentstatuses --no-headers 2>$null
            if ($LASTEXITCODE -eq 0) {
                $healthyComponents = ($componentStatus -split "`n" | Where-Object { $_ -match "Healthy" }).Count
                Write-Host "✅ Component status: $healthyComponents healthy components" -ForegroundColor Green
                Add-TestResult "Component Status" "✅ PASS" "$healthyComponents healthy"
            } else {
                Write-Host "⚠️ Could not retrieve component status" -ForegroundColor Yellow
                Add-TestResult "Component Status" "⚠️ WARN" "Unable to retrieve"
            }
            
            # Check node status
            $nodes = kubectl get nodes --no-headers 2>$null
            if ($LASTEXITCODE -eq 0) {
                $readyNodes = ($nodes -split "`n" | Where-Object { $_ -match "Ready" }).Count
                Write-Host "✅ Node status: $readyNodes nodes ready" -ForegroundColor Green
                Add-TestResult "Node Status" "✅ PASS" "$readyNodes nodes ready"
            } else {
                Write-Host "❌ Failed to retrieve node status" -ForegroundColor Red
                Add-TestResult "Node Status" "❌ FAIL"
            }
            
            # Check system pods
            $systemPods = kubectl get pods -n kube-system --no-headers 2>$null
            if ($LASTEXITCODE -eq 0) {
                $runningPods = ($systemPods -split "`n" | Where-Object { $_ -match "Running" }).Count
                Write-Host "✅ System pods: $runningPods pods running" -ForegroundColor Green
                Add-TestResult "System Pods" "✅ PASS" "$runningPods running"
            } else {
                Write-Host "⚠️ Could not retrieve system pod status" -ForegroundColor Yellow
                Add-TestResult "System Pods" "⚠️ WARN" "Unable to retrieve"
            }
            
        } else {
            Write-Host "❌ Cluster connectivity failed" -ForegroundColor Red
            Add-TestResult "Cluster Connectivity" "❌ FAIL"
        }
        
    } else {
        Write-Host "❌ kubectl not configured or wrong context" -ForegroundColor Red
        Write-Host "💡 Run script 10-configure-kubectl.ps1 to configure kubectl" -ForegroundColor Yellow
        Add-TestResult "kubectl Configuration" "❌ FAIL" "Not configured"
    }
}
catch {
    Write-Host "❌ Kubernetes cluster validation failed: $_" -ForegroundColor Red
    Add-TestResult "Kubernetes Cluster" "❌ FAIL" $_.Exception.Message
}

#endregion

#region Service-Specific Validation

Write-Host ""
Write-Host "Step 4: Validating Individual Services..." -ForegroundColor Yellow

# Check etcd cluster
try {
    $controller0IP = Get-VmPublicIP -ResourceGroup "kubernetes" -VmName "controller-0"
    $etcdStatus = Invoke-RemoteCommand -VmIP $controller0IP -Command "sudo ETCDCTL_API=3 etcdctl member list --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem" -Description "Checking etcd cluster status"
    
    if ($etcdStatus -match "started") {
        $memberCount = ($etcdStatus -split "`n" | Where-Object { $_ -match "started" }).Count
        Write-Host "✅ etcd cluster: $memberCount members active" -ForegroundColor Green
        Add-TestResult "etcd Cluster" "✅ PASS" "$memberCount members"
    } else {
        Write-Host "❌ etcd cluster status check failed" -ForegroundColor Red
        Add-TestResult "etcd Cluster" "❌ FAIL"
    }
}
catch {
    Write-Host "❌ etcd validation failed: $_" -ForegroundColor Red
    Add-TestResult "etcd Cluster" "❌ FAIL" $_.Exception.Message
}

# Check containerd on workers
$workers = @("worker-0", "worker-1")
foreach ($worker in $workers) {
    try {
        $workerIP = Get-VmPublicIP -ResourceGroup "kubernetes" -VmName $worker
        $containerdStatus = Invoke-RemoteCommand -VmIP $workerIP -Command "sudo systemctl is-active containerd" -Description "Checking containerd status on $worker"
        
        if ($containerdStatus -eq "active") {
            Write-Host "✅ containerd on $worker is active" -ForegroundColor Green
            Add-TestResult "containerd: $worker" "✅ PASS"
        } else {
            Write-Host "❌ containerd on $worker is not active: $containerdStatus" -ForegroundColor Red
            Add-TestResult "containerd: $worker" "❌ FAIL" $containerdStatus
        }
    }
    catch {
        Write-Host "❌ containerd validation on $worker failed: $_" -ForegroundColor Red
        Add-TestResult "containerd: $worker" "❌ FAIL" $_.Exception.Message
    }
}

#endregion

#region Results Summary

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Validation Results Summary" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

$passCount = ($testResults | Where-Object { $_.Status -match "✅" }).Count
$failCount = ($testResults | Where-Object { $_.Status -match "❌" }).Count
$warnCount = ($testResults | Where-Object { $_.Status -match "⚠️" }).Count
$totalCount = $testResults.Count

Write-Host ""
Write-Host "📊 Overall Results:" -ForegroundColor White
Write-Host "  ✅ Passed: $passCount" -ForegroundColor Green
Write-Host "  ❌ Failed: $failCount" -ForegroundColor Red
Write-Host "  ⚠️ Warnings: $warnCount" -ForegroundColor Yellow
Write-Host "  📋 Total Tests: $totalCount" -ForegroundColor Cyan

if ($failCount -eq 0) {
    Write-Host ""
    Write-Host "🎉 All critical tests passed! Cluster is healthy." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "⚠️ Some tests failed. Review the details below:" -ForegroundColor Yellow
    
    $failedTests = $testResults | Where-Object { $_.Status -match "❌" }
    foreach ($test in $failedTests) {
        Write-Host "  ❌ $($test.Test): $($test.Details)" -ForegroundColor Red
    }
}

# Detailed results table
if ($Verbose) {
    Write-Host ""
    Write-Host "📋 Detailed Test Results:" -ForegroundColor Cyan
    $testResults | Format-Table -AutoSize Test, Status, Details, Timestamp
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan

#endregion
