# Tutorial Step 11: Provisioning Pod Network Routes
# URL: https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/11-pod-network-routes.md
# Description: Create routes for each worker node that maps the node's Pod CIDR range to the node's internal IP address

Write-Host "===============================================" -ForegroundColor Green
Write-Host "Tutorial Step 11: Provisioning Pod Network Routes" -ForegroundColor Green  
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""

Write-Host "This lab creates network routes to enable pod-to-pod communication across worker nodes." -ForegroundColor Yellow
Write-Host "Without these routes, pods on different nodes cannot communicate with each other." -ForegroundColor Yellow
Write-Host ""

# Step 1: Gather worker node information for routing table
Write-Host "Step 1: Gathering worker node information for routing table..." -ForegroundColor Cyan

$workerNodes = @("worker-0", "worker-1")
$routingInfo = @()

foreach ($worker in $workerNodes) {
    Write-Host "  Processing $worker..." -ForegroundColor Yellow
    
    try {
        # Get private IP address
        $privateIP = az vm show -d -g kubernetes -n $worker --query "privateIps" -o tsv
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get private IP for $worker"
        }
        
        # Get Pod CIDR from VM tags
        $podCIDR = az vm show -g kubernetes --name $worker --query "tags.podCidr" -o tsv
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get Pod CIDR for $worker"
        }
        
        $routingInfo += [PSCustomObject]@{
            WorkerNode = $worker
            PrivateIP = $privateIP.Trim()
            PodCIDR = $podCIDR.Trim()
        }
        
        Write-Host "    ✅ $worker - IP: $($privateIP.Trim()), Pod CIDR: $($podCIDR.Trim())" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to get information for $worker : $_"
        exit 1
    }
}

Write-Host ""

# Step 2: Create route table
Write-Host "Step 2: Creating route table 'kubernetes-routes'..." -ForegroundColor Cyan

try {
    # Get the location of the VNet to ensure route table is created in the same region
    $vnetLocation = az network vnet show -g kubernetes -n kubernetes-vnet --query "location" -o tsv
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get VNet location"
    }
    
    az network route-table create -g kubernetes -n kubernetes-routes --location $vnetLocation.Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create route table"
    }
    Write-Host "  ✅ Route table 'kubernetes-routes' created successfully in $($vnetLocation.Trim())" -ForegroundColor Green
}
catch {
    Write-Error "Failed to create route table: $_"
    exit 1
}

Write-Host ""

# Step 3: Associate route table with subnet
Write-Host "Step 3: Associating route table with kubernetes-subnet..." -ForegroundColor Cyan

try {
    az network vnet subnet update -g kubernetes `
        -n kubernetes-subnet `
        --vnet-name kubernetes-vnet `
        --route-table kubernetes-routes
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to associate route table with subnet"
    }
    Write-Host "  ✅ Route table associated with kubernetes-subnet successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to associate route table with subnet: $_"
    exit 1
}

Write-Host ""

# Step 4: Create routes for each worker node
Write-Host "Step 4: Creating network routes for worker nodes..." -ForegroundColor Cyan

foreach ($info in $routingInfo) {
    $routeName = "kubernetes-route-$($info.PodCIDR.Replace('/', '-').Replace('.', '-'))"
    
    Write-Host "  Creating route for $($info.WorkerNode)..." -ForegroundColor Yellow
    Write-Host "    Route Name: $routeName" -ForegroundColor White
    Write-Host "    Address Prefix: $($info.PodCIDR)" -ForegroundColor White
    Write-Host "    Next Hop IP: $($info.PrivateIP)" -ForegroundColor White
    
    try {
        az network route-table route create -g kubernetes `
            -n $routeName `
            --route-table-name kubernetes-routes `
            --address-prefix $info.PodCIDR `
            --next-hop-ip-address $info.PrivateIP `
            --next-hop-type VirtualAppliance
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create route for $($info.WorkerNode)"
        }
        Write-Host "    ✅ Route created successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create route for $($info.WorkerNode): $_"
        exit 1
    }
}

Write-Host ""

# Step 5: Verify created routes
Write-Host "Step 5: Verifying created routes..." -ForegroundColor Cyan

try {
    Write-Host "  Listing routes in kubernetes-routes table:" -ForegroundColor Yellow
    az network route-table route list -g kubernetes --route-table-name kubernetes-routes -o table
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list routes"
    }
    Write-Host "  ✅ Routes listed successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to list routes: $_"
    exit 1
}

Write-Host ""

# Summary
Write-Host "===============================================" -ForegroundColor Green
Write-Host "✅ Pod Network Routes Provisioning Complete" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Summary of created routes:" -ForegroundColor Blue
foreach ($info in $routingInfo) {
    Write-Host "  • $($info.WorkerNode): $($info.PodCIDR) → $($info.PrivateIP)" -ForegroundColor White
}
Write-Host ""
Write-Host "🎯 Next Step: Tutorial Step 12 - Deploying the DNS Cluster Add-on" -ForegroundColor Blue
Write-Host ""
Write-Host "💡 What this enables:" -ForegroundColor Yellow
Write-Host "  - Pods on worker-0 can communicate with pods on worker-1" -ForegroundColor White
Write-Host "  - Cross-node pod networking via custom routes" -ForegroundColor White
Write-Host "  - Foundation for service discovery and networking" -ForegroundColor White