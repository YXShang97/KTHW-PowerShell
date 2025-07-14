# Fix missing certificates on controller nodes
# This script copies the required certificates to the controller nodes

Write-Host "=========================================="
Write-Host "Copying Missing Certificates to Controllers"
Write-Host "=========================================="

# Define controller instances
$controllerInstances = @("controller-0", "controller-1", "controller-2")

# Certificate files needed for etcd
$certFiles = @("ca.pem", "kubernetes-key.pem", "kubernetes.pem")

# Verify local certificate files exist
Write-Host "Verifying local certificate files..."
$localCertsPath = "C:\repos\kthw\certs"
$allCertsExist = $true

foreach ($certFile in $certFiles) {
    $localCertPath = Join-Path $localCertsPath $certFile
    if (Test-Path $localCertPath) {
        Write-Host "  ✓ $certFile found"
    } else {
        Write-Host "  ✗ $certFile NOT FOUND at $localCertPath"
        $allCertsExist = $false
    }
}

if (-not $allCertsExist) {
    Write-Host "ERROR: Missing certificate files. Please ensure all certificates are generated first."
    exit 1
}

Write-Host "Copying certificates from: $localCertsPath"
Write-Host ""

foreach ($instance in $controllerInstances) {
    Write-Host "Processing $instance..."
    
    # Get the public IP address for SSH connection
    $publicIpAddress = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    
    Write-Host "Public IP for $instance : $publicIpAddress"
    
    # Copy the required certificates to the controller
    Write-Host "Copying certificates to $instance..."
    
    try {
        # Copy each certificate file individually for better error tracking
        foreach ($certFile in $certFiles) {
            $localCertPath = Join-Path $localCertsPath $certFile
            Write-Host "  Copying $certFile..."
            scp -o StrictHostKeyChecking=no $localCertPath "kuberoot@${publicIpAddress}:~/"
        }
        
        # Verify certificates were copied successfully
        Write-Host "  Verifying certificates on $instance..."
        ssh -o StrictHostKeyChecking=no "kuberoot@$publicIpAddress" "ls -la ca.pem kubernetes*.pem"
        
        Write-Host "  ✓ Certificates copied to $instance successfully!"
    }
    catch {
        Write-Host "  ✗ ERROR copying certificates to $instance"
        Write-Host "  Error: $_"
    }
    Write-Host ""
}

Write-Host "=========================================="
Write-Host "Certificate Copy Complete!"
Write-Host "=========================================="
Write-Host ""
Write-Host "Now you can run the etcd bootstrap script: 07-bootstrapping-etcd.ps1"
