#requires -Version 5.1

<#
.SYNOPSIS
Common functions and utilities for Kubernetes the Hard Way PowerShell scripts

.DESCRIPTION
This module contains shared functions used across all tutorial scripts.
Implements best practices for cross-platform compatibility, error handling,
and simplified operations based on lessons learned from tutorial execution.

.NOTES
Author: KTHW PowerShell Tutorial
Version: 2.0
Date: July 15, 2025
Based on: Lessons learned from successful tutorial execution
#>

# Set error action preference for consistent behavior
$ErrorActionPreference = 'Stop'

#region Helper Functions

<#
.SYNOPSIS
Creates a file with proper Unix line endings for Linux compatibility

.DESCRIPTION
Addresses the CRLF/LF line ending issues encountered during tutorial execution.
Uses explicit UTF-8 encoding and converts Windows line endings to Unix format.

.PARAMETER Content
The content to write to the file

.PARAMETER FilePath
The path where the file should be created

.EXAMPLE
New-UnixFile -Content $configContent -FilePath "/tmp/config.yaml"
#>
function New-UnixFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    try {
        # Convert CRLF to LF for Unix compatibility
        $unixContent = $Content -replace "`r`n", "`n"
        
        # Use explicit UTF-8 encoding
        [System.IO.File]::WriteAllText($FilePath, $unixContent, [System.Text.Encoding]::UTF8)
        
        Write-Host "✅ File created with Unix line endings: $FilePath" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to create Unix file: $FilePath" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        throw
    }
}

<#
.SYNOPSIS
Executes a command with retry logic and proper error handling

.DESCRIPTION
Implements exponential backoff retry pattern for network operations and Azure CLI commands.
Reduces failures from transient network issues encountered during tutorial execution.

.PARAMETER Command
The command to execute

.PARAMETER Description
Description for user feedback

.PARAMETER MaxRetries
Maximum number of retry attempts (default: 3)

.PARAMETER InitialDelay
Initial delay in seconds (default: 2)

.EXAMPLE
Invoke-CommandWithRetry -Command "az vm create ..." -Description "Creating VM"
#>
function Invoke-CommandWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        
        [Parameter(Mandatory = $true)]
        [string]$Description,
        
        [int]$MaxRetries = 3,
        [int]$InitialDelay = 2
    )
    
    $retryCount = 0
    
    do {
        try {
            Write-Host "$Description..." -ForegroundColor Yellow
            
            # Execute command
            Invoke-Expression $Command
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ $Description completed" -ForegroundColor Green
                return
            }
            else {
                throw "Command failed with exit code $LASTEXITCODE"
            }
        }
        catch {
            $retryCount++
            
            if ($retryCount -eq $MaxRetries) {
                Write-Host "❌ $Description failed after $MaxRetries attempts" -ForegroundColor Red
                Write-Host "Error: $_" -ForegroundColor Red
                throw
            }
            
            $delay = $InitialDelay * [math]::Pow(2, $retryCount - 1)
            Write-Host "⚠️ Attempt $retryCount failed, retrying in $delay seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds $delay
        }
    } while ($retryCount -lt $MaxRetries)
}

<#
.SYNOPSIS
Gets the public IP address for an Azure VM

.DESCRIPTION
Simplified function to retrieve VM public IP addresses with error handling.
Prevents repetitive code across scripts.

.PARAMETER ResourceGroup
Azure resource group name

.PARAMETER VmName
Virtual machine name

.EXAMPLE
$ip = Get-VmPublicIP -ResourceGroup "kubernetes" -VmName "controller-0"
#>
function Get-VmPublicIP {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,
        
        [Parameter(Mandatory = $true)]
        [string]$VmName
    )
    
    try {
        $ip = az network public-ip show -g $ResourceGroup -n "$VmName-pip" --query "ipAddress" -o tsv
        
        if ([string]::IsNullOrEmpty($ip)) {
            throw "No public IP found for $VmName"
        }
        
        return $ip
    }
    catch {
        Write-Host "❌ Failed to get public IP for $VmName" -ForegroundColor Red
        throw
    }
}

<#
.SYNOPSIS
Executes a command on a remote VM via SSH

.DESCRIPTION
Simplified SSH command execution with consistent error handling and output formatting.
Addresses SSH connectivity issues encountered during tutorial execution.

.PARAMETER VmIP
The public IP address of the target VM

.PARAMETER Command
The command to execute remotely

.PARAMETER Description
Description for user feedback

.PARAMETER Username
SSH username (default: kuberoot)

.EXAMPLE
Invoke-RemoteCommand -VmIP $ip -Command "sudo systemctl status etcd" -Description "Checking etcd status"
#>
function Invoke-RemoteCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VmIP,
        
        [Parameter(Mandatory = $true)]
        [string]$Command,
        
        [Parameter(Mandatory = $true)]
        [string]$Description,
        
        [string]$Username = "kuberoot"
    )
    
    try {
        Write-Host "  $Description on VM ($VmIP)..." -ForegroundColor Cyan
        
        $result = ssh "$Username@$VmIP" $Command 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✅ $Description completed" -ForegroundColor Green
            if ($result) {
                Write-Host "    Output: $result" -ForegroundColor Gray
            }
            return $result
        }
        else {
            Write-Host "    ❌ $Description failed" -ForegroundColor Red
            Write-Host "    Error: $result" -ForegroundColor Red
            throw "SSH command failed: $Command"
        }
    }
    catch {
        Write-Host "    ❌ SSH execution failed: $_" -ForegroundColor Red
        throw
    }
}

<#
.SYNOPSIS
Creates a remote configuration file with proper line endings

.DESCRIPTION
Addresses the line ending and encoding issues encountered during tutorial execution.
Creates temporary files with Unix line endings and transfers them via SCP.

.PARAMETER VmIP
The public IP address of the target VM

.PARAMETER Content
The file content to transfer

.PARAMETER RemotePath
The destination path on the remote VM

.PARAMETER Username
SSH username (default: kuberoot)

.EXAMPLE
New-RemoteConfigFile -VmIP $ip -Content $configYaml -RemotePath "/etc/kubernetes/config.yaml"
#>
function New-RemoteConfigFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VmIP,
        
        [Parameter(Mandatory = $true)]
        [string]$Content,
        
        [Parameter(Mandatory = $true)]
        [string]$RemotePath,
        
        [string]$Username = "kuberoot"
    )
    
    try {
        # Create temporary file with Unix line endings
        $tempFile = [System.IO.Path]::GetTempFileName()
        New-UnixFile -Content $Content -FilePath $tempFile
        
        # Transfer file via SCP
        scp $tempFile "$Username@$VmIP`:/tmp/config_temp" 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            throw "SCP transfer failed"
        }
        
        # Move file to final destination
        Invoke-RemoteCommand -VmIP $VmIP -Command "sudo mv /tmp/config_temp $RemotePath" -Description "Moving config file to $RemotePath"
        
        # Cleanup
        Remove-Item $tempFile -Force
        
        Write-Host "    ✅ Config file created: $RemotePath" -ForegroundColor Green
    }
    catch {
        Write-Host "    ❌ Failed to create remote config file: $RemotePath" -ForegroundColor Red
        throw
    }
}

<#
.SYNOPSIS
Validates Azure CLI authentication and subscription access

.DESCRIPTION
Performs pre-flight checks to ensure Azure CLI is properly configured.
Prevents authentication failures during script execution.

.EXAMPLE
Test-AzureAuthentication
#>
function Test-AzureAuthentication {
    [CmdletBinding()]
    param()
    
    Write-Host "Validating Azure CLI authentication..." -ForegroundColor Yellow
    
    try {
        # Check if Azure CLI is available
        $azVersion = az version --query '"azure-cli"' -o tsv 2>$null
        if ([string]::IsNullOrEmpty($azVersion)) {
            throw "Azure CLI not found or not responding"
        }
        
        # Check authentication
        $account = az account show --query "user.name" -o tsv 2>$null
        if ([string]::IsNullOrEmpty($account)) {
            throw "Not authenticated to Azure CLI. Run 'az login'"
        }
        
        # Check subscription access
        $subscription = az account show --query "name" -o tsv 2>$null
        if ([string]::IsNullOrEmpty($subscription)) {
            throw "No active Azure subscription found"
        }
        
        Write-Host "✅ Azure CLI authenticated as: $account" -ForegroundColor Green
        Write-Host "✅ Active subscription: $subscription" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Host "❌ Azure authentication validation failed: $_" -ForegroundColor Red
        Write-Host "💡 Run 'az login' to authenticate" -ForegroundColor Yellow
        throw
    }
}

<#
.SYNOPSIS
Tests network connectivity to a remote host and port

.DESCRIPTION
Validates network connectivity before attempting operations.
Helps identify network issues early in the process.

.PARAMETER ComputerName
Target hostname or IP address

.PARAMETER Port
Target port number

.PARAMETER TimeoutSeconds
Connection timeout in seconds (default: 10)

.EXAMPLE
Test-NetworkConnectivity -ComputerName "10.240.0.10" -Port 22
#>
function Test-NetworkConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,
        
        [Parameter(Mandatory = $true)]
        [int]$Port,
        
        [int]$TimeoutSeconds = 10
    )
    
    try {
        $result = Test-NetConnection -ComputerName $ComputerName -Port $Port -WarningAction SilentlyContinue
        
        if ($result.TcpTestSucceeded) {
            Write-Host "✅ Network connectivity to $ComputerName`:$Port successful" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "❌ Network connectivity to $ComputerName`:$Port failed" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "❌ Network test failed: $_" -ForegroundColor Red
        return $false
    }
}

#endregion

#region Export Functions

# Export functions for use in other scripts
Export-ModuleMember -Function @(
    'New-UnixFile',
    'Invoke-CommandWithRetry', 
    'Get-VmPublicIP',
    'Invoke-RemoteCommand',
    'New-RemoteConfigFile',
    'Test-AzureAuthentication',
    'Test-NetworkConnectivity'
)

#endregion

Write-Host "✅ Common functions module loaded successfully" -ForegroundColor Green
