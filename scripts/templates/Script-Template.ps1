#requires -Version 5.1

<#
.SYNOPSIS
Template for Kubernetes the Hard Way PowerShell scripts

.DESCRIPTION
Standardized template following best practices learned from tutorial execution.
Implements proper error handling, cross-platform compatibility, and simplified operations.

.PARAMETER ParameterName
Description of parameter

.EXAMPLE
.\New-Script.ps1 -ParameterName "value"

.NOTES
Author: KTHW PowerShell Tutorial
Version: 2.0
Date: July 15, 2025
Based on: Lessons learned from successful tutorial execution
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ParameterName = "default-value",
    
    [switch]$Force,
    [switch]$Verbose
)

# Set strict mode and error preferences
Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

# Import common functions
. "$PSScriptRoot\..\common\Common-Functions.ps1"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Tutorial Step XX: [Script Description]" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

#region Prerequisites Validation

Write-Host "Validating prerequisites..." -ForegroundColor Yellow

try {
    # Validate Azure authentication
    Test-AzureAuthentication
    
    # Add other prerequisite checks here
    # Example: Check if previous steps completed
    # if (!(Test-Path "certs\ca.pem")) {
    #     throw "CA certificate not found. Run script 04 first."
    # }
    
    Write-Host "✅ Prerequisites validated" -ForegroundColor Green
}
catch {
    Write-Host "❌ Prerequisites validation failed: $_" -ForegroundColor Red
    Write-Host "💡 Ensure previous tutorial steps are completed" -ForegroundColor Yellow
    exit 1
}

#endregion

#region Main Operations

Write-Host ""
Write-Host "Step 1: [First Operation]..." -ForegroundColor Yellow

try {
    # Example of retry operation for Azure CLI commands
    Invoke-CommandWithRetry -Command "az group show --name kubernetes" -Description "Checking resource group"
    
    # Example of remote operations
    $controllers = @("controller-0", "controller-1", "controller-2")
    foreach ($controller in $controllers) {
        $ip = Get-VmPublicIP -ResourceGroup "kubernetes" -VmName $controller
        Write-Host "  Processing $controller ($ip)..." -ForegroundColor Cyan
        
        # Example remote command
        Invoke-RemoteCommand -VmIP $ip -Command "echo 'Hello from $controller'" -Description "Testing connectivity"
        
        # Example config file creation with proper line endings
        $configContent = @"
# Configuration file example
key: value
another_key: another_value
"@
        New-RemoteConfigFile -VmIP $ip -Content $configContent -RemotePath "/tmp/example.conf"
    }
    
    Write-Host "✅ Step 1 completed successfully" -ForegroundColor Green
}
catch {
    Write-Host "❌ Step 1 failed: $_" -ForegroundColor Red
    throw
}

Write-Host ""
Write-Host "Step 2: [Second Operation]..." -ForegroundColor Yellow

try {
    # Additional operations here
    Write-Host "✅ Step 2 completed successfully" -ForegroundColor Green
}
catch {
    Write-Host "❌ Step 2 failed: $_" -ForegroundColor Red
    throw
}

#endregion

#region Validation

Write-Host ""
Write-Host "Validating results..." -ForegroundColor Yellow

try {
    # Validate the operations performed
    # Example: Check service status
    # $status = Invoke-RemoteCommand -VmIP $ip -Command "sudo systemctl is-active service-name" -Description "Checking service status"
    # if ($status -ne "active") {
    #     throw "Service is not active: $status"
    # }
    
    Write-Host "✅ Validation completed successfully" -ForegroundColor Green
}
catch {
    Write-Host "❌ Validation failed: $_" -ForegroundColor Red
    Write-Host "🔧 Run troubleshooting script if needed:" -ForegroundColor Yellow
    Write-Host "   .\scripts\troubleshooting\Repair-Cluster.ps1 -Component all" -ForegroundColor White
    throw
}

#endregion

#region Completion

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Tutorial Step XX Complete" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ All operations completed successfully" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Run validation script: .\scripts\validation\Validate-Cluster.ps1" -ForegroundColor White
Write-Host "2. Proceed to next tutorial step" -ForegroundColor White
Write-Host ""

#endregion

#region Error Handling Template

<#
Common error handling patterns:

try {
    # Operation that might fail
}
catch [System.Management.Automation.CommandNotFoundException] {
    Write-Host "❌ Command not found: $_" -ForegroundColor Red
    Write-Host "💡 Ensure required tools are installed" -ForegroundColor Yellow
}
catch [System.Net.NetworkInformation.PingException] {
    Write-Host "❌ Network connectivity issue: $_" -ForegroundColor Red
    Write-Host "💡 Check Azure VM status and network security groups" -ForegroundColor Yellow
}
catch {
    Write-Host "❌ Unexpected error: $_" -ForegroundColor Red
    Write-Host "🔍 Check the error details above for more information" -ForegroundColor Yellow
}

#>

#endregion
