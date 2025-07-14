# This file recreates the bash script from the kubernetes-the-hard-way repository but using PowerShell syntax
# This is from tutorial 11: Provisioning Pod Network Routes - https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/11-pod-network-routes.md
# Pods scheduled to a node receive an IP address from the node's Pod CIDR range. At this point pods can not communicate with other pods running on different nodes due to missing network routes.
# In this lab you will create a route for each worker node that maps the node's Pod CIDR range to the node's internal IP address.

# This script provisions pod network routes for the Kubernetes cluster from your Windows machine

# Start transcript to capture all output
$outputFile = "C:\repos\kthw\scripts\11\11-execution-output.txt"
Start-Transcript -Path $outputFile -Force

Write-Host "=========================================="
Write-Host "Provisioning Pod Network Routes"
Write-Host "=========================================="
Write-Host ""

Write-Host "This script will configure pod network routes for the Kubernetes cluster."
Write-Host "The following actions will be performed:"
Write-Host "1. Gather worker node information (internal IPs and Pod CIDR ranges)"
Write-Host "2. Create a route table for Kubernetes networking"
Write-Host "3. Associate the route table with the Kubernetes subnet"
Write-Host "4. Create specific routes for each worker node's Pod CIDR"
Write-Host "5. Verify the routing configuration"
Write-Host ""

# Define worker instances
$workerInstances = @("worker-0", "worker-1")
$expectedWorkerIPs = @("10.240.0.20", "10.240.0.21")
$expectedPodCIDRs = @("10.200.0.0/24", "10.200.1.0/24")

Write-Host "=========================================="
Write-Host "Gathering Worker Node Information"
Write-Host "=========================================="

# Collect worker node information
$workerInfo = @()
foreach ($i in 0..($workerInstances.Length - 1)) {
    $instance = $workerInstances[$i]
    
    Write-Host "Getting information for $instance..."
    
    try {
        # Get private IP address
        $privateIpAddress = az vm show -d -g kubernetes -n $instance --query "privateIps" -o tsv
        
        # Get Pod CIDR from VM tags
        $vmTags = az vm show -g kubernetes --name $instance --query "tags" -o json | ConvertFrom-Json
        $podCidrTag = $vmTags.'pod-cidr'
        
        if (-not $privateIpAddress) {
            throw "Failed to get private IP for $instance"
        }
        
        if (-not $podCidrTag) {
            throw "Failed to get Pod CIDR tag for $instance"
        }
        
        $workerInfo += @{
            Instance = $instance
            PrivateIP = $privateIpAddress
            PodCIDR = $podCidrTag
            Index = $i
        }
        
        Write-Host "✓ $instance - Private IP: $privateIpAddress, Pod CIDR: $podCidrTag"
    }
    catch {
        Write-Host "ERROR: Failed to get information for $instance"
        Write-Host "Error: $_"
        Stop-Transcript
        exit 1
    }
}

Write-Host ""
Write-Host "Worker node information summary:"
foreach ($worker in $workerInfo) {
    Write-Host "  $($worker.Instance): $($worker.PrivateIP) -> $($worker.PodCIDR)"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Creating Route Table"
Write-Host "=========================================="

# Create the route table for Kubernetes networking
Write-Host "Creating Kubernetes route table..."
try {
    $routeTableResult = az network route-table create -g kubernetes -n kubernetes-routes --output json | ConvertFrom-Json
    Write-Host "✓ Route table 'kubernetes-routes' created successfully"
    Write-Host "  Resource ID: $($routeTableResult.id)"
    Write-Host "  Location: $($routeTableResult.location)"
}
catch {
    Write-Host "ERROR: Failed to create route table"
    Write-Host "Error: $_"
    Stop-Transcript
    exit 1
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Associating Route Table with Subnet"
Write-Host "=========================================="

# Associate the route table with the Kubernetes subnet
Write-Host "Associating route table with kubernetes-subnet..."
try {
    $subnetUpdateResult = az network vnet subnet update -g kubernetes -n kubernetes-subnet --vnet-name kubernetes-vnet --route-table kubernetes-routes --output json | ConvertFrom-Json
    Write-Host "✓ Route table associated with kubernetes-subnet successfully"
    Write-Host "  Subnet: $($subnetUpdateResult.name)"
    Write-Host "  Address prefix: $($subnetUpdateResult.addressPrefix)"
    Write-Host "  Route table: $($subnetUpdateResult.routeTable.id -split '/')[-1]"
}
catch {
    Write-Host "ERROR: Failed to associate route table with subnet"
    Write-Host "Error: $_"
    Stop-Transcript
    exit 1
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Creating Pod Network Routes"
Write-Host "=========================================="

# Create network routes for each worker instance
foreach ($worker in $workerInfo) {
    $routeName = "kubernetes-route-10-200-$($worker.Index)-0-24"
    $addressPrefix = $worker.PodCIDR
    $nextHopIp = $worker.PrivateIP
    
    Write-Host "Creating route for $($worker.Instance)..."
    Write-Host "  Route name: $routeName"
    Write-Host "  Address prefix: $addressPrefix"
    Write-Host "  Next hop IP: $nextHopIp"
    
    try {
        $routeResult = az network route-table route create -g kubernetes -n $routeName --route-table-name kubernetes-routes --address-prefix $addressPrefix --next-hop-ip-address $nextHopIp --next-hop-type VirtualAppliance --output json | ConvertFrom-Json
        
        Write-Host "✓ Route created successfully"
        Write-Host "  Provisioning state: $($routeResult.provisioningState)"
        Write-Host "  Next hop type: $($routeResult.nextHopType)"
    }
    catch {
        Write-Host "ERROR: Failed to create route for $($worker.Instance)"
        Write-Host "Error: $_"
        Stop-Transcript
        exit 1
    }
    Write-Host ""
}

Write-Host "=========================================="
Write-Host "Verifying Route Configuration"
Write-Host "=========================================="

# List and verify the routes in the kubernetes-routes table
Write-Host "Listing all routes in the kubernetes-routes table..."
try {
    $routes = az network route-table route list -g kubernetes --route-table-name kubernetes-routes --output json | ConvertFrom-Json
    
    Write-Host "✓ Route table contains $($routes.Count) routes:"
    Write-Host ""
    Write-Host "Route Summary:"
    Write-Host "============="
    Write-Host "Name                              Address Prefix    Next Hop IP     Next Hop Type     State"
    Write-Host "----                              --------------    -----------     -------------     -----"
    
    foreach ($route in $routes) {
        $name = $route.name.PadRight(32)
        $prefix = $route.addressPrefix.PadRight(16)
        $nextHop = $route.nextHopIpAddress.PadRight(14)
        $hopType = $route.nextHopType.PadRight(16)
        $state = $route.provisioningState
        
        Write-Host "$name  $prefix  $nextHop  $hopType  $state"
    }
}
catch {
    Write-Host "ERROR: Failed to list routes"
    Write-Host "Error: $_"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Testing Route Configuration"
Write-Host "=========================================="

# Verify route table association
Write-Host "Verifying route table is properly associated with subnet..."
try {
    $subnetInfo = az network vnet subnet show -g kubernetes -n kubernetes-subnet --vnet-name kubernetes-vnet --output json | ConvertFrom-Json
    
    if ($subnetInfo.routeTable) {
        Write-Host "✓ Route table is associated with subnet"
        Write-Host "  Subnet: $($subnetInfo.name)"
        Write-Host "  Route table: $($subnetInfo.routeTable.id -split '/')[-1]"
    } else {
        Write-Host "⚠ No route table associated with subnet"
    }
}
catch {
    Write-Host "ERROR: Failed to verify subnet association"
    Write-Host "Error: $_"
}

Write-Host ""
Write-Host "Verifying expected routes exist..."
$expectedRoutes = @(
    @{ Name = "kubernetes-route-10-200-0-0-24"; Prefix = "10.200.0.0/24"; NextHop = "10.240.0.20" },
    @{ Name = "kubernetes-route-10-200-1-0-24"; Prefix = "10.200.1.0/24"; NextHop = "10.240.0.21" }
)

foreach ($expectedRoute in $expectedRoutes) {
    $actualRoute = $routes | Where-Object { $_.name -eq $expectedRoute.Name }
    
    if ($actualRoute) {
        if ($actualRoute.addressPrefix -eq $expectedRoute.Prefix -and $actualRoute.nextHopIpAddress -eq $expectedRoute.NextHop) {
            Write-Host "✓ $($expectedRoute.Name) - Correctly configured"
        } else {
            Write-Host "⚠ $($expectedRoute.Name) - Configuration mismatch"
            Write-Host "  Expected: $($expectedRoute.Prefix) -> $($expectedRoute.NextHop)"
            Write-Host "  Actual: $($actualRoute.addressPrefix) -> $($actualRoute.nextHopIpAddress)"
        }
    } else {
        Write-Host "✗ $($expectedRoute.Name) - Route not found"
    }
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Pod Network Routes Provisioning Complete!"
Write-Host "=========================================="
Write-Host ""
Write-Host "Successfully configured pod network routes:"

foreach ($worker in $workerInfo) {
    Write-Host "✓ $($worker.Instance) ($($worker.PrivateIP)) -> Pod CIDR: $($worker.PodCIDR)"
}

Write-Host ""
Write-Host "Network routing summary:"
Write-Host "- Route table 'kubernetes-routes' created and associated with kubernetes-subnet"
Write-Host "- Routes configured to direct pod traffic to appropriate worker nodes"
Write-Host "- Pods on different nodes can now communicate via the Azure network routing"
Write-Host ""
Write-Host "What this enables:"
Write-Host "- Cross-node pod communication"
Write-Host "- Service discovery across worker nodes"
Write-Host "- Proper Kubernetes networking functionality"
Write-Host ""
Write-Host "Next step: Deploying the DNS Cluster Add-on"
Write-Host ""

# Stop transcript
Stop-Transcript
Write-Host "`nExecution log saved to: $outputFile"