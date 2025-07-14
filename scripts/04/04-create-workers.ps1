# Define your Ubuntu image
$UBUNTULTS = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"

# Loop to create the two worker nodes
for ($i=0; $i -lt 2; $i++) {
    Write-Host "[Worker $i] Creating public IP..."
    az network public-ip create --sku Standard -z 1 -n "worker-${i}-pip" -g kubernetes | Out-Null

    Write-Host "[Worker $i] Creating NIC..."
    az network nic create -g kubernetes `
        -n "worker-${i}-nic" `
        --private-ip-address "10.240.0.2${i}" `
        --public-ip-address "worker-${i}-pip" `
        --vnet kubernetes-vnet `
        --subnet kubernetes-subnet `
        --ip-forwarding | Out-Null

    Write-Host "[Worker $i] Creating VM..."
    az vm create -g kubernetes `
        -n "worker-${i}" `
        --image $UBUNTULTS `
        --nics "worker-${i}-nic" `
        --public-ip-sku Standard `
        --tags "pod-cidr=10.200.${i}.0/24" `
        --availability-set worker-as `
        --generate-ssh-keys `
        --admin-username 'kuberoot' | Out-Null
}

Write-Host "Worker VMs created successfully!"
