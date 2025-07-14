# This file recreates the bash script from the kubernetes-the-hard-way repository but using PowerShell syntax
# This is from tutorial 6: Generating the Data Encryption Config and Key - https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/06-data-encryption-keys.md
# Kubernetes stores a variety of data including cluster state, application configurations, and secrets. Kubernetes supports the ability to encrypt cluster data at rest.
# In this lab you will generate an encryption key and an encryption config suitable for encrypting Kubernetes Secrets.

# Change to the certs directory first
Set-Location "C:\repos\kthw\certs"

Write-Host "Generating data encryption config and key..."

# Generate a 32-byte random encryption key and encode it as base64
Write-Host "Generating encryption key..."
$randomBytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($randomBytes)
$encryptionKey = [System.Convert]::ToBase64String($randomBytes)
$rng.Dispose()

Write-Host "Encryption key generated successfully."

# Create the encryption-config.yaml encryption config file
Write-Host "Creating encryption-config.yaml file..."

$encryptionConfig = @"
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
$encryptionConfig | Out-File -FilePath "encryption-config.yaml" -Encoding UTF8

Write-Host "encryption-config.yaml file created successfully."

# Copy the encryption-config.yaml encryption config file to each controller instance:
Write-Host "`nDistributing encryption config to controller instances..."

$controllerInstances = @("controller-0", "controller-1", "controller-2")

foreach ($instance in $controllerInstances) {
    Write-Host "Processing controller instance: $instance"
    
    # Get the public IP address for the controller instance
    $publicIpAddress = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    
    Write-Host "Public IP for $instance : $publicIpAddress"
    
    # Copy encryption config file to the controller instance
    scp -o StrictHostKeyChecking=no encryption-config.yaml "kuberoot@${publicIpAddress}:~/"
    
    Write-Host "Encryption config copied to $instance successfully."
}

Write-Host "`nData encryption config and key generation completed successfully!"
Write-Host "`nNext: Bootstrapping the etcd Cluster"