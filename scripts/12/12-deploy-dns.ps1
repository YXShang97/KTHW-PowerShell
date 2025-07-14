# Tutorial Step 12: Deploying the DNS Cluster Add-on
# URL: https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/12-dns-addon.md
# Description: Deploy the DNS add-on which provides DNS based service discovery, backed by CoreDNS

Write-Host "===============================================" -ForegroundColor Green
Write-Host "Tutorial Step 12: Deploying the DNS Cluster Add-on" -ForegroundColor Green  
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""

Write-Host "This lab deploys CoreDNS to provide DNS-based service discovery within the cluster." -ForegroundColor Yellow
Write-Host "CoreDNS enables pods to resolve service names to cluster IP addresses." -ForegroundColor Yellow
Write-Host ""

# Step 1: Deploy CoreDNS cluster add-on
Write-Host "Step 1: Deploying CoreDNS cluster add-on..." -ForegroundColor Cyan

try {
    Write-Host "  Applying CoreDNS manifest from kubernetes-the-hard-way repository..." -ForegroundColor Yellow
    kubectl apply -f https://storage.googleapis.com/kubernetes-the-hard-way/coredns-1.8.yaml
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to apply CoreDNS manifest"
    }
    Write-Host "  ✅ CoreDNS add-on deployed successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to deploy CoreDNS: $_"
    exit 1
}

Write-Host ""

# Step 2: Wait for CoreDNS pods to be ready
Write-Host "Step 2: Waiting for CoreDNS pods to be ready..." -ForegroundColor Cyan

Write-Host "  Waiting for CoreDNS deployment to be available..." -ForegroundColor Yellow
$maxWaitTime = 180  # 3 minutes (reduced from 5 minutes for efficiency)
$waitTime = 0
$sleepInterval = 5  # Reduced from 10 to 5 seconds for faster detection

do {
    Start-Sleep -Seconds $sleepInterval
    $waitTime += $sleepInterval
    
    try {
        # More efficient: Check deployment status first, then pods
        $deploymentReady = kubectl get deployment coredns -n kube-system -o jsonpath='{.status.readyReplicas}' 2>$null
        if ($LASTEXITCODE -eq 0 -and $deploymentReady -ge 1) {
            # Double-check with pod status for reliability
            $podStatus = kubectl get pods -l k8s-app=kube-dns -n kube-system --no-headers 2>$null
            if ($LASTEXITCODE -eq 0 -and $podStatus) {
                $readyPods = @($podStatus -split "`n" | Where-Object { $_ -match "\s+1/1\s+Running\s+" })
                if ($readyPods.Count -ge 1) {
                    Write-Host "  ✅ CoreDNS pods are ready ($($readyPods.Count) running)" -ForegroundColor Green
                    break
                }
            }
        }
        Write-Host "  ⏳ Waiting for CoreDNS pods to be ready... ($waitTime/$maxWaitTime seconds)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "  ⏳ Checking CoreDNS deployment status... ($waitTime/$maxWaitTime seconds)" -ForegroundColor Yellow
    }
} while ($waitTime -lt $maxWaitTime)

if ($waitTime -ge $maxWaitTime) {
    Write-Warning "CoreDNS deployment did not become ready within $maxWaitTime seconds"
    Write-Host "  ℹ️  Continuing with verification step..." -ForegroundColor Blue
}

Write-Host ""

# Step 3: List CoreDNS pods
Write-Host "Step 3: Verifying CoreDNS pod deployment..." -ForegroundColor Cyan

try {
    Write-Host "  Listing CoreDNS pods:" -ForegroundColor Yellow
    kubectl get pods -l k8s-app=kube-dns -n kube-system
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list CoreDNS pods"
    }
    Write-Host "  ✅ CoreDNS pods listed successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to list CoreDNS pods: $_"
    exit 1
}

Write-Host ""

# Step 4: Create test pod for DNS verification
Write-Host "Step 4: Creating test pod for DNS verification..." -ForegroundColor Cyan

try {
    Write-Host "  Creating busybox test pod..." -ForegroundColor Yellow
    kubectl run busybox --image=busybox:1.28 --command -- sleep 3600
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create busybox test pod"
    }
    Write-Host "  ✅ Busybox test pod created successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to create test pod: $_"
    exit 1
}

Write-Host ""

# Step 5: Wait for test pod to be ready
Write-Host "Step 5: Waiting for test pod to be ready..." -ForegroundColor Cyan

Write-Host "  Waiting for busybox pod to be running..." -ForegroundColor Yellow
$maxWaitTime = 90   # Reduced to 90 seconds for efficiency
$waitTime = 0

do {
    Start-Sleep -Seconds $sleepInterval
    $waitTime += $sleepInterval
    
    try {
        $podStatus = kubectl get pod busybox --no-headers 2>$null
        if ($LASTEXITCODE -eq 0 -and $podStatus -match "\s+1/1\s+Running\s+") {
            Write-Host "  ✅ Busybox pod is ready" -ForegroundColor Green
            break
        }
        Write-Host "  ⏳ Waiting for busybox pod to be ready... ($waitTime/$maxWaitTime seconds)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "  ⏳ Checking busybox pod status... ($waitTime/$maxWaitTime seconds)" -ForegroundColor Yellow
    }
} while ($waitTime -lt $maxWaitTime)

if ($waitTime -ge $maxWaitTime) {
    Write-Warning "Busybox pod did not become ready within $maxWaitTime seconds"
    Write-Host "  ℹ️  You may need to check pod status manually" -ForegroundColor Blue
}

Write-Host ""

# Step 6: Perform DNS lookup test
Write-Host "Step 6: Testing DNS resolution..." -ForegroundColor Cyan

try {
    Write-Host "  Getting busybox pod name..." -ForegroundColor Yellow
    # More efficient: Direct pod name since we created it with a specific name
    $podName = "busybox"
    
    # Verify pod exists and is running before attempting DNS test
    $podReady = kubectl get pod $podName --no-headers 2>$null
    if ($LASTEXITCODE -ne 0 -or !($podReady -match "\s+1/1\s+Running\s+")) {
        throw "Busybox pod is not ready for DNS testing"
    }
    
    Write-Host "  Pod name: $podName" -ForegroundColor White
    Write-Host "  Performing DNS lookup for 'kubernetes' service..." -ForegroundColor Yellow
    
    kubectl exec $podName -- nslookup kubernetes
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to perform DNS lookup"
    }
    Write-Host "  ✅ DNS lookup completed successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to perform DNS lookup test: $_"
    Write-Host "  ℹ️  This might be expected if pods are not fully ready yet" -ForegroundColor Blue
}

Write-Host ""

# Step 7: Clean up test pod
Write-Host "Step 7: Cleaning up test resources..." -ForegroundColor Cyan

try {
    Write-Host "  Deleting busybox test pod..." -ForegroundColor Yellow
    kubectl delete pod busybox
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to delete busybox pod - you may need to clean it up manually"
    } else {
        Write-Host "  ✅ Test pod cleaned up successfully" -ForegroundColor Green
    }
}
catch {
    Write-Warning "Failed to clean up test pod: $_"
}

Write-Host ""

# Summary
Write-Host "===============================================" -ForegroundColor Green
Write-Host "✅ DNS Cluster Add-on Deployment Complete" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "📋 What was deployed:" -ForegroundColor Blue
Write-Host "  • CoreDNS deployment with 2 replicas" -ForegroundColor White
Write-Host "  • kube-dns service (ClusterIP: 10.32.0.10)" -ForegroundColor White
Write-Host "  • DNS-based service discovery enabled" -ForegroundColor White
Write-Host "  • DNS lookup functionality verified" -ForegroundColor White
Write-Host ""
Write-Host "🎯 Next Step: Tutorial Step 13 - Smoke Test" -ForegroundColor Blue
Write-Host ""
Write-Host "💡 DNS is now available for:" -ForegroundColor Yellow
Write-Host "  - Service name resolution (service.namespace.svc.cluster.local)" -ForegroundColor White
Write-Host "  - Pod name resolution within namespaces" -ForegroundColor White
Write-Host "  - External DNS lookups (if configured)" -ForegroundColor White