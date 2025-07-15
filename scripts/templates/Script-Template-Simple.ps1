#requires -Version 5.1

<#
.SYNOPSIS
Simple template for Kubernetes the Hard Way PowerShell scripts

.DESCRIPTION
Basic template for new tutorial scripts.

.NOTES
Author: KTHW PowerShell Tutorial
Version: 2.1-Simplified
Date: July 15, 2025
#>

param(
    [string]$Parameter = "default"
)

$ErrorActionPreference = 'Stop'

# Import common functions
. "$PSScriptRoot\..\common\Common-Functions.ps1"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Tutorial Step XX: [Description]" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Validate Azure authentication
    Test-AzureAuthentication
    
    # Main script logic here
    Write-Host "Starting script execution..." -ForegroundColor Yellow
    
    # Your code here
    
    Write-Host ""
    Write-Host "✅ Script completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "❌ Script failed: $_" -ForegroundColor Red
    Write-Host "Check the error details above and try again." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
