#requires -Version 5.1
<#
.SYNOPSIS
    Tutorial Step 06: Generating the Data Encryption Config and Key

.DESCRIPTION
    Kubernetes stores a variety of data including cluster state, application configurations, 
    and secrets. Kubernetes supports the ability to encrypt cluster data at rest.
    In this lab you will generate an encryption key and an encryption config suitable 
    for encrypting Kubernetes Secrets.

.NOTES
    Tutorial Step: 06
    Tutorial Name: Generating the Data Encryption Config and Key
    Original URL: https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/06-data-encryption-keys.md
    
    Prerequisites:
    - Azure infrastructure deployed (Tutorial Step 03)
    - Controller VMs accessible via SSH
#>

# Set working directory to certs folder where we'll store the encryption config
$certsPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\certs"
if (-not (Test-Path $certsPath)) {
    Write-Error "Certs directory not found at: $certsPath"
    exit 1
}

Set-Location $certsPath
Write-Host "Working in: $(Get-Location)" -ForegroundColor Green

# Generate a random 32-byte encryption key and encode it in base64
Write-Host "Generating encryption key..." -ForegroundColor Yellow

# PowerShell equivalent of: head -c 32 /dev/urandom | base64
$randomBytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
$rng.GetBytes($randomBytes)
$encryptionKey = [Convert]::ToBase64String($randomBytes)
$rng.Dispose()

Write-Host "✅ Generated encryption key: $($encryptionKey.Substring(0,20))..." -ForegroundColor Green

# Create the encryption-config.yaml file
Write-Host "Creating encryption-config.yaml file..." -ForegroundColor Yellow

$encryptionConfigContent = @"
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: $encryptionKey
      - identity: {}
"@

# Write the encryption config to file
$encryptionConfigContent | Out-File -FilePath "encryption-config.yaml" -Encoding UTF8
Write-Host "✅ Created encryption-config.yaml" -ForegroundColor Green

# Display the created file content for verification
Write-Host "Encryption config file contents:" -ForegroundColor Cyan
Get-Content "encryption-config.yaml" | ForEach-Object { Write-Host "  $_" -ForegroundColor White }

# Copy the encryption config file to each controller instance
Write-Host "Distributing encryption-config.yaml to controller instances..." -ForegroundColor Yellow
$controllers = @("controller-0", "controller-1", "controller-2")

foreach ($instance in $controllers) {
    $publicIP = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    Write-Host "Copying to $instance ($publicIP)..." -ForegroundColor Cyan
    
    & scp -o StrictHostKeyChecking=no "encryption-config.yaml" "kuberoot@$publicIP`:~/"
    Write-Host "✅ Copied encryption-config.yaml to $instance" -ForegroundColor Green
}

Write-Host "Encryption configuration setup complete!" -ForegroundColor Green
Write-Host "Encryption key and config file have been distributed to all controller nodes." -ForegroundColor Yellow