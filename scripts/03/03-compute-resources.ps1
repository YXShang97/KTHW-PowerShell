# ============================================================================
# Tutorial Step: 03 - Provisioning Compute Resources
# Tutorial Name: Provisioning Compute Resources
# URL: https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/03-compute-resources.md
# Description: Provision compute resources for a secure and highly available Kubernetes cluster
# ============================================================================

# Requires: Azure CLI installed and authenticated
# Purpose: Create VNet, NSG, Load Balancer, and VMs for Kubernetes cluster

Write-Host "=== Kubernetes The Hard Way - Step 03: Provisioning Compute Resources ===" -ForegroundColor Green
Write-Host "Creating Azure infrastructure for Kubernetes cluster..." -ForegroundColor Yellow

# Variables
$resourceGroup = "kubernetes"
$location = "eastus2"
$ubuntuImage = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"

try {
    # ============================================================================
    # Step 1: Create Virtual Network
    # ============================================================================
    Write-Host "`nStep 1: Creating Virtual Network..." -ForegroundColor Yellow
    
    Write-Host "Creating VNet: kubernetes-vnet with subnet: kubernetes-subnet" -ForegroundColor Cyan
    az network vnet create -g $resourceGroup `
        -n kubernetes-vnet `
        --address-prefix 10.240.0.0/24 `
        --subnet-name kubernetes-subnet `
        --location $location
    
    Write-Host "Virtual network created successfully!" -ForegroundColor Green

    # ============================================================================
    # Step 2: Create Network Security Group and Rules
    # ============================================================================
    Write-Host "`nStep 2: Creating Network Security Group..." -ForegroundColor Yellow
    
    Write-Host "Creating NSG: kubernetes-nsg" -ForegroundColor Cyan
    az network nsg create -g $resourceGroup -n kubernetes-nsg --location $location
    
    Write-Host "Associating NSG with subnet" -ForegroundColor Cyan
    az network vnet subnet update -g $resourceGroup `
        -n kubernetes-subnet `
        --vnet-name kubernetes-vnet `
        --network-security-group kubernetes-nsg
    
    Write-Host "Creating firewall rules..." -ForegroundColor Cyan
    
    # SSH access rule
    az network nsg rule create -g $resourceGroup `
        -n kubernetes-allow-ssh `
        --access allow `
        --destination-address-prefix '*' `
        --destination-port-range 22 `
        --direction inbound `
        --nsg-name kubernetes-nsg `
        --protocol tcp `
        --source-address-prefix '*' `
        --source-port-range '*' `
        --priority 1000
    
    # Kubernetes API Server access rule
    az network nsg rule create -g $resourceGroup `
        -n kubernetes-allow-api-server `
        --access allow `
        --destination-address-prefix '*' `
        --destination-port-range 6443 `
        --direction inbound `
        --nsg-name kubernetes-nsg `
        --protocol tcp `
        --source-address-prefix '*' `
        --source-port-range '*' `
        --priority 1001
    
    Write-Host "Network security group and rules created successfully!" -ForegroundColor Green

    # ============================================================================
    # Step 3: Create Load Balancer with Public IP
    # ============================================================================
    Write-Host "`nStep 3: Creating Load Balancer..." -ForegroundColor Yellow
    
    Write-Host "Creating load balancer with static public IP" -ForegroundColor Cyan
    az network lb create -g $resourceGroup `
        -n kubernetes-lb `
        --backend-pool-name kubernetes-lb-pool `
        --public-ip-zone 1 `
        --sku Standard `
        --public-ip-address kubernetes-pip `
        --public-ip-address-allocation static `
        --location $location
    
    Write-Host "Load balancer created successfully!" -ForegroundColor Green

    # ============================================================================
    # Step 4: Create Controller VMs (3 instances)
    # ============================================================================
    Write-Host "`nStep 4: Creating Controller VMs..." -ForegroundColor Yellow
    
    Write-Host "Creating controller availability set" -ForegroundColor Cyan
    az vm availability-set create -g $resourceGroup -n controller-as --location $location
    
    for ($i = 0; $i -le 2; $i++) {
        Write-Host "Creating controller-$i..." -ForegroundColor Cyan
        
        # Create public IP
        Write-Host "  [Controller $i] Creating public IP..." -ForegroundColor White
        az network public-ip create --sku Standard -z 1 -n "controller-$i-pip" -g $resourceGroup --location $location | Out-Null
        
        # Create NIC
        Write-Host "  [Controller $i] Creating network interface..." -ForegroundColor White
        az network nic create -g $resourceGroup `
            -n "controller-$i-nic" `
            --private-ip-address "10.240.0.1$i" `
            --public-ip-address "controller-$i-pip" `
            --vnet kubernetes-vnet `
            --subnet kubernetes-subnet `
            --ip-forwarding `
            --lb-name kubernetes-lb `
            --lb-address-pools kubernetes-lb-pool `
            --location $location | Out-Null
        
        # Create VM
        Write-Host "  [Controller $i] Creating virtual machine..." -ForegroundColor White
        az vm create -g $resourceGroup `
            -n "controller-$i" `
            --image $ubuntuImage `
            --nics "controller-$i-nic" `
            --public-ip-sku Standard `
            --availability-set controller-as `
            --admin-username 'kuberoot' `
            --generate-ssh-keys `
            --size Standard_B2s `
            --location $location | Out-Null
    }
    
    Write-Host "Controller VMs created successfully!" -ForegroundColor Green

    # ============================================================================
    # Step 5: Create Worker VMs (2 instances)
    # ============================================================================
    Write-Host "`nStep 5: Creating Worker VMs..." -ForegroundColor Yellow
    
    Write-Host "Creating worker availability set" -ForegroundColor Cyan
    az vm availability-set create -g $resourceGroup -n worker-as --location $location
    
    for ($i = 0; $i -le 1; $i++) {
        Write-Host "Creating worker-$i..." -ForegroundColor Cyan
        
        # Create public IP
        Write-Host "  [Worker $i] Creating public IP..." -ForegroundColor White
        az network public-ip create --sku Standard -z 1 -n "worker-$i-pip" -g $resourceGroup --location $location | Out-Null
        
        # Create NIC
        Write-Host "  [Worker $i] Creating network interface..." -ForegroundColor White
        az network nic create -g $resourceGroup `
            -n "worker-$i-nic" `
            --private-ip-address "10.240.0.2$i" `
            --public-ip-address "worker-$i-pip" `
            --vnet kubernetes-vnet `
            --subnet kubernetes-subnet `
            --ip-forwarding `
            --location $location | Out-Null
        
        # Create VM with pod CIDR tag
        Write-Host "  [Worker $i] Creating virtual machine..." -ForegroundColor White
        az vm create -g $resourceGroup `
            -n "worker-$i" `
            --image $ubuntuImage `
            --nics "worker-$i-nic" `
            --public-ip-sku Standard `
            --tags "pod-cidr=10.200.$i.0/24" `
            --availability-set worker-as `
            --generate-ssh-keys `
            --admin-username 'kuberoot' `
            --size Standard_B2s `
            --location $location | Out-Null
    }
    
    Write-Host "Worker VMs created successfully!" -ForegroundColor Green

} catch {
    Write-Error "Azure resource creation failed: $($_.Exception.Message)"
    Write-Host "Please check the execution output file for troubleshooting steps." -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Azure Infrastructure Provisioning Complete ===" -ForegroundColor Green
Write-Host "All resources created in resource group: $resourceGroup" -ForegroundColor Cyan
Write-Host "Run validation commands separately to verify the deployment." -ForegroundColor Yellow
Write-Host "See 03-execution-output.md for validation steps and troubleshooting." -ForegroundColor Yellow