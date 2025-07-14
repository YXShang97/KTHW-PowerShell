# This file recreates the bash script from the kubernetes-the-hard-way repository but using PowerShell syntax
# This is from tutorial 5: Kubernetes Configuration Files - https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/05-kubernetes-configuration-files.md
# This scripts in this lab distributes the Kubernetes Configuration Files

# Change to the configs directory first
Set-Location "C:\repos\kthw\configs"

# Copy the appropriate kubelet and kube-proxy kubeconfig files to each worker instance:

Write-Host "Distributing kubeconfig files to worker instances..."

$workerInstances = @("worker-0", "worker-1")

foreach ($instance in $workerInstances) {
    Write-Host "Processing worker instance: $instance"
    
    # Get the public IP address for the worker instance
    $publicIpAddress = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    
    Write-Host "Public IP for $instance : $publicIpAddress"
    
    # Copy kubeconfig files to the worker instance
    scp -o StrictHostKeyChecking=no "$instance.kubeconfig" kube-proxy.kubeconfig "kuberoot@${publicIpAddress}:~/"
    
    Write-Host "Kubeconfig files copied to $instance successfully."
}

Write-Host "`nDistributing kubeconfig files to controller instances..."

# Copy the appropriate kube-controller-manager and kube-scheduler kubeconfig files to each controller instance:

$controllerInstances = @("controller-0", "controller-1", "controller-2")

foreach ($instance in $controllerInstances) {
    Write-Host "Processing controller instance: $instance"
    
    # Get the public IP address for the controller instance
    $publicIpAddress = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    
    Write-Host "Public IP for $instance : $publicIpAddress"
    
    # Copy kubeconfig files to the controller instance
    scp -o StrictHostKeyChecking=no admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig "kuberoot@${publicIpAddress}:~/"
    
    Write-Host "Kubeconfig files copied to $instance successfully."
}

Write-Host "`nKubeconfig file distribution completed successfully!"
Write-Host "`nNext: Generating the Data Encryption Config and Key"