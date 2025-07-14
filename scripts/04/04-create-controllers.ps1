# Define your Ubuntu image
$UBUNTULTS = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"

# Loop to create the three controllers
for ($i=0; $i -lt 3; $i++) {
    Write-Host "[Controller $i] Creating public IP..."
    az network public-ip create --sku Standard -z 1 -n "controller-${i}-pip" -g kubernetes | Out-Null

    Write-Host "[Controller $i] Creating NIC..."
    az network nic create -g kubernetes `
        -n "controller-${i}-nic" `
        --private-ip-address "10.240.0.1${i}" `
        --public-ip-address "controller-${i}-pip" `
        --vnet kubernetes-vnet `
        --subnet kubernetes-subnet `
        --ip-forwarding `
        --lb-name kubernetes-lb `
        --lb-address-pools kubernetes-lb-pool | Out-Null

    Write-Host "[Controller $i] Creating VM..."
    az vm create -g kubernetes `
        -n "controller-${i}" `
        --image $UBUNTULTS `
        --nics "controller-${i}-nic" `
        --public-ip-sku Standard `
        --availability-set controller-as `
        --admin-username 'kuberoot' `
        --generate-ssh-keys | Out-Null
}

Write-Host "Controllers created successfully!"


