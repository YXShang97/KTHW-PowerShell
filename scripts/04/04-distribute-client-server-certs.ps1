# This file recreates the bash script from the kubernetes-the-hard-way repository
# This is from tutorial 4: Certificate Authority - https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/04-certificate-authority.md
# This script distributes the client and server certificates
# Note that from the previous steps in the tutorial the username used to create the linux VMs is 'kuberoot'

# Change to the certs directory first
Set-Location "C:\repos\kthw\certs"

# Copy the appropriate certificates and private keys to each worker instance:
Write-Host "Distributing certificates to worker instances..."

$workerInstances = @("worker-0", "worker-1")

foreach ($instance in $workerInstances) {
    Write-Host "Processing worker instance: $instance"
    
    # Get the public IP address for the worker instance
    $publicIpAddress = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    
    Write-Host "Public IP for $instance : $publicIpAddress"
    
    # Copy certificates to the worker instance
    scp -o StrictHostKeyChecking=no ca.pem "$instance-key.pem" "$instance.pem" "kuberoot@$publicIpAddress" :~/
    
    Write-Host "Certificates copied to $instance successfully."
}

Write-Host "`nDistributing certificates to controller instances..."

# Copy the appropriate certificates and private keys to each controller instance:
$controllerInstances = @("controller-0", "controller-1", "controller-2")

foreach ($instance in $controllerInstances) {
    Write-Host "Processing controller instance: $instance"
    
    # Get the public IP address for the controller instance
    $publicIpAddress = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    
    Write-Host "Public IP for $instance : $publicIpAddress"
    
    # Copy certificates to the controller instance
    scp -o StrictHostKeyChecking=no ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem service-account-key.pem service-account.pem "kuberoot@$publicIpAddress" :~/
    
    Write-Host "Certificates copied to $instance successfully."
}

Write-Host "`nCertificate distribution completed successfully!"
Write-Host "`nThe kube-proxy, kube-controller-manager, kube-scheduler, and kubelet client certificates will be used to generate client authentication configuration files in the next lab."
Write-Host "Next lab - Generating Kubernetes Configuration Files for Authentication"