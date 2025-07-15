#requires -Version 5.1

<#
.SYNOPSIS
Essential common functions for Kubernetes the Hard Way PowerShell scripts

.DESCRIPTION
Simplified shared functions for the tutorial scripts.
Focuses on core functionality needed for cluster deployment.

.NOTES
Author: KTHW PowerShell Tutorial
Version: 2.1-Simplified
Date: July 15, 2025
#>

$ErrorActionPreference = 'Stop'

#region Essential Functions

<#
.SYNOPSIS
Creates a file with Unix line endings for Linux compatibility
#>
function New-UnixFile {
    param([string]$Content, [string]$FilePath)
    
    # Convert CRLF to LF for Linux compatibility
    $unixContent = $Content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($FilePath, $unixContent, [System.Text.Encoding]::UTF8)
}

<#
.SYNOPSIS
Gets VM public IP address
#>
function Get-VmPublicIP {
    param([string]$ResourceGroup, [string]$VmName)
    
    $ip = az network public-ip show -g $ResourceGroup -n "$VmName-pip" --query "ipAddress" -o tsv
    if ([string]::IsNullOrEmpty($ip)) {
        throw "No public IP found for $VmName"
    }
    return $ip
}

<#
.SYNOPSIS
Executes command on remote VM via SSH
#>
function Invoke-RemoteCommand {
    param([string]$VmIP, [string]$Command, [string]$Username = "kuberoot")
    
    $result = ssh -o StrictHostKeyChecking=no "${Username}@${VmIP}" $Command 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "SSH command failed on $VmIP"
    }
    return $result
}

<#
.SYNOPSIS
Tests Azure CLI authentication
#>
function Test-AzureAuthentication {
    try {
        az account show >$null 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Azure CLI not authenticated"
        }
    }
    catch {
        Write-Host "❌ Azure authentication required. Run 'az login'" -ForegroundColor Red
        throw
    }
}

<#
.SYNOPSIS
Creates a remote config file with proper encoding
#>
function New-RemoteConfigFile {
    param([string]$VmIP, [string]$Content, [string]$RemotePath, [string]$Username = "kuberoot")
    
    # Create temporary file with Unix line endings
    $tempFile = [System.IO.Path]::GetTempFileName()
    New-UnixFile -Content $Content -FilePath $tempFile
    
    try {
        # Copy to remote VM
        scp -o StrictHostKeyChecking=no $tempFile "${Username}@${VmIP}:$RemotePath" 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to copy file to $VmIP"
        }
    }
    finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

#endregion

Write-Host "✅ Common functions loaded" -ForegroundColor Green
