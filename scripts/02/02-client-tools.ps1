# ============================================================================
# Tutorial Step: 02 - Installing the Client Tools
# Tutorial Name: Installing the Client Tools  
# URL: https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/02-client-tools.md
# Description: Install command line utilities required for this tutorial: cfssl, cfssljson, and kubectl
# ============================================================================

# Requires: PowerShell 5.1+ and Administrator privileges
# Purpose: Download and install essential Kubernetes tools for Windows

Write-Host "=== Kubernetes The Hard Way - Step 02: Installing Client Tools ===" -ForegroundColor Green
Write-Host "Installing cfssl, cfssljson, and kubectl..." -ForegroundColor Yellow

# Create tools directory in current location
$toolsPath = "$PWD\cfssl"
if (!(Test-Path $toolsPath)) {
    New-Item -ItemType Directory -Path $toolsPath -Force | Out-Null
    Write-Host "Created tools directory: $toolsPath" -ForegroundColor Cyan
}

# Set working directory to tools folder
Push-Location $toolsPath

try {
    # ============================================================================
    # Step 1: Download cfssl and cfssljson
    # ============================================================================
    Write-Host "`nStep 1: Downloading cfssl tools..." -ForegroundColor Yellow
    
    # Download cfssl
    Write-Host "Downloading cfssl v1.6.3..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri "https://github.com/cloudflare/cfssl/releases/download/v1.6.3/cfssl_1.6.3_windows_amd64.exe" -OutFile "cfssl.exe"
    
    # Download cfssljson  
    Write-Host "Downloading cfssljson v1.6.3..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri "https://github.com/cloudflare/cfssl/releases/download/v1.6.3/cfssljson_1.6.3_windows_amd64.exe" -OutFile "cfssljson.exe"
    
    Write-Host "cfssl tools downloaded successfully!" -ForegroundColor Green

    # ============================================================================
    # Step 2: Install kubectl via Chocolatey
    # ============================================================================
    Write-Host "`nStep 2: Installing kubectl..." -ForegroundColor Yellow
    
    # Check if Chocolatey is installed
    $chocoInstalled = Get-Command choco -ErrorAction SilentlyContinue
    if (-not $chocoInstalled) {
        Write-Host "Chocolatey not found. Installing Chocolatey first..." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    
    # Install kubectl
    Write-Host "Installing kubectl via Chocolatey..." -ForegroundColor Cyan
    choco install kubernetes-cli -y
    
    Write-Host "kubectl installation completed!" -ForegroundColor Green

} catch {
    Write-Error "Installation failed: $($_.Exception.Message)"
    Write-Host "Please see the execution output file for troubleshooting steps." -ForegroundColor Red
} finally {
    # Return to original directory
    Pop-Location
}

Write-Host "`n=== Installation Complete ===" -ForegroundColor Green
Write-Host "Tools installed in: $toolsPath" -ForegroundColor Cyan
Write-Host "Run validation commands separately to verify installation." -ForegroundColor Yellow
Write-Host "See 02-execution-output.md for validation steps and troubleshooting." -ForegroundColor Yellow