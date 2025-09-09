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
    
    Write-Host "        [Azure] Getting IP for $VmName..." -ForegroundColor DarkGray
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        $ip = az network public-ip show -g $ResourceGroup -n "$VmName-pip" --query "ipAddress" -o tsv 2>$null
        $stopwatch.Stop()
        
        if ([string]::IsNullOrEmpty($ip)) {
            throw "No public IP found for $VmName"
        }
        Write-Host "        [Azure] Got IP: $ip (${stopwatch.ElapsedMilliseconds}ms)" -ForegroundColor DarkGray
        return $ip
    }
    catch {
        $stopwatch.Stop()
        Write-Host "        [Azure] Failed to get IP (${stopwatch.ElapsedMilliseconds}ms): $_" -ForegroundColor Red
        throw
    }
}

<#
.SYNOPSIS
Executes command on remote VM via SSH
#>
function Invoke-RemoteCommand {
    param(
        [string]$VmIP, 
        [string]$Command, 
        [string]$Username = "kuberoot"
    )
    
    Write-Host "        [SSH] Executing: $Command" -ForegroundColor DarkGray
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    # Use better SSH options with timeouts
    $result = ssh -o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=2 -o StrictHostKeyChecking=no "${Username}@${VmIP}" $Command 2>$null
    $stopwatch.Stop()
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "        [SSH] Command failed (${stopwatch.ElapsedMilliseconds}ms, exit: $LASTEXITCODE)" -ForegroundColor Red
        throw "SSH command failed on $VmIP with exit code $LASTEXITCODE"
    }
    Write-Host "        [SSH] Success (${stopwatch.ElapsedMilliseconds}ms)" -ForegroundColor DarkGray
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
    
    Write-Host "        [SCP] Creating remote file: $RemotePath" -ForegroundColor DarkGray
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    # Create temporary file with Unix line endings
    $tempFile = [System.IO.Path]::GetTempFileName()
    New-UnixFile -Content $Content -FilePath $tempFile
    
    try {
        # Copy to remote VM with timeout options
        scp -o ConnectTimeout=10 -o ServerAliveInterval=5 -o StrictHostKeyChecking=no $tempFile "${Username}@${VmIP}:$RemotePath" 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to copy file to $VmIP (exit code: $LASTEXITCODE)"
        }
        $stopwatch.Stop()
        Write-Host "        [SCP] File copied successfully (${stopwatch.ElapsedMilliseconds}ms)" -ForegroundColor DarkGray
    }
    finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}

#endregion

Write-Host "✅ Common functions loaded" -ForegroundColor Green
