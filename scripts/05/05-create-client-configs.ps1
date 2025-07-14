# This file recreates the bash script from the kubernetes-the-hard-way repository but using PowerShell syntax
# This is from tutorial 5: Kubernetes Configuration Files - https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/05-kubernetes-configuration-files.md
# This scripts in this lab generate the client authentication configuration files for kube-proxy, kube-controller-manager, kube-scheduler, and kubelet
# The kube-proxy, kube-controller-manager, kube-scheduler, and kubelet client certificates will be used to generate these configuration files.

# Change to the configs directory first
Set-Location "C:\repos\kthw\configs"

# Retrieve the kubernetes-the-hard-way static IP address:
Write-Host "Retrieving Kubernetes public IP address..."
$kubernetesPublicAddress = az network public-ip show -g kubernetes -n kubernetes-pip --query "ipAddress" -o tsv
Write-Host "Kubernetes public IP: $kubernetesPublicAddress"


# The kubelet Kubernetes Configuration File
# When generating kubeconfig files for Kubelets the client certificate matching the Kubelet's node name must be used. This will ensure Kubelets are properly authorized by the Kubernetes Node Authorizer.

# Generate a kubeconfig file for each worker node.
# Expected results: worker-0.kubeconfig, worker-1.kubeconfig

Write-Host "`nGenerating kubeconfig files for worker nodes..."

$workerInstances = @("worker-0", "worker-1")

foreach ($instance in $workerInstances) {
    Write-Host "Creating kubeconfig for $instance..."
    
    kubectl config set-cluster kubernetes-the-hard-way `
        --certificate-authority="../certs/ca.pem" `
        --embed-certs=true `
        --server="https://$kubernetesPublicAddress`:6443" `
        --kubeconfig="$instance.kubeconfig"

    kubectl config set-credentials "system:node:$instance" `
        --client-certificate="../certs/$instance.pem" `
        --client-key="../certs/$instance-key.pem" `
        --embed-certs=true `
        --kubeconfig="$instance.kubeconfig"

    kubectl config set-context default `
        --cluster=kubernetes-the-hard-way `
        --user="system:node:$instance" `
        --kubeconfig="$instance.kubeconfig"

    kubectl config use-context default --kubeconfig="$instance.kubeconfig"
    
    Write-Host "Kubeconfig for $instance created successfully."
}

# Generate a kubeconfig file for the kube-proxy service:
# Expected Result: kube-proxy.kubeconfig

Write-Host "`nGenerating kubeconfig for kube-proxy..."

kubectl config set-cluster kubernetes-the-hard-way `
    --certificate-authority="../certs/ca.pem" `
    --embed-certs=true `
    --server="https://$kubernetesPublicAddress`:6443" `
    --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials kube-proxy `
    --client-certificate="../certs/kube-proxy.pem" `
    --client-key="../certs/kube-proxy-key.pem" `
    --embed-certs=true `
    --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default `
    --cluster=kubernetes-the-hard-way `
    --user=kube-proxy `
    --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

Write-Host "Kubeconfig for kube-proxy created successfully."


# Generate a kubeconfig file for the kube-controller-manager service:
# Expected Result: kube-controller-manager.kubeconfig

Write-Host "`nGenerating kubeconfig for kube-controller-manager..."

kubectl config set-cluster kubernetes-the-hard-way `
    --certificate-authority="../certs/ca.pem" `
    --embed-certs=true `
    --server=https://127.0.0.1:6443 `
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager `
    --client-certificate="../certs/kube-controller-manager.pem" `
    --client-key="../certs/kube-controller-manager-key.pem" `
    --embed-certs=true `
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default `
    --cluster=kubernetes-the-hard-way `
    --user=system:kube-controller-manager `
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

Write-Host "Kubeconfig for kube-controller-manager created successfully."

# Generate a kubeconfig file for the kube-scheduler service:
# Expected Result: kube-scheduler.kubeconfig

Write-Host "`nGenerating kubeconfig for kube-scheduler..."

kubectl config set-cluster kubernetes-the-hard-way `
    --certificate-authority="../certs/ca.pem" `
    --embed-certs=true `
    --server=https://127.0.0.1:6443 `
    --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler `
    --client-certificate="../certs/kube-scheduler.pem" `
    --client-key="../certs/kube-scheduler-key.pem" `
    --embed-certs=true `
    --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default `
    --cluster=kubernetes-the-hard-way `
    --user=system:kube-scheduler `
    --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

Write-Host "Kubeconfig for kube-scheduler created successfully."

# Generate a kubeconfig file for the admin user:
# Expected Result: admin.kubeconfig

Write-Host "`nGenerating kubeconfig for admin user..."

kubectl config set-cluster kubernetes-the-hard-way `
    --certificate-authority="../certs/ca.pem" `
    --embed-certs=true `
    --server=https://127.0.0.1:6443 `
    --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin `
    --client-certificate="../certs/admin.pem" `
    --client-key="../certs/admin-key.pem" `
    --embed-certs=true `
    --kubeconfig=admin.kubeconfig

kubectl config set-context default `
    --cluster=kubernetes-the-hard-way `
    --user=admin `
    --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig

Write-Host "Kubeconfig for admin user created successfully."
Write-Host "`nAll kubeconfig files have been generated successfully!"