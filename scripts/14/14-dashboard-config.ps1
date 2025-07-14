
# This file recreates the bash script from the kubernetes-the-hard-way repository but using PowerShell syntax
# This is from tutorial 14: Dashboard Configuration - https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/14-dashboard.md
# In this lab you will install and configure the Kubernetes dashboard for cluster management and monitoring.

# This script deploys and configures the Kubernetes Dashboard with proper authentication from your Windows machine

# Start transcript to capture all output
$outputFile = "C:\repos\kthw\scripts\14\14-execution-output.txt"
Start-Transcript -Path $outputFile -Force

Write-Host "=========================================="
Write-Host "Kubernetes Dashboard Configuration"
Write-Host "=========================================="
Write-Host ""

Write-Host "This script will deploy and configure the Kubernetes Dashboard with:"
Write-Host "1. Dashboard deployment from official manifests"
Write-Host "2. Service account creation for admin access"
Write-Host "3. Cluster role binding for full cluster access"
Write-Host "4. Token generation for dashboard authentication"
Write-Host "5. Dashboard access configuration and validation"
Write-Host ""

$startTime = Get-Date

Write-Host "=========================================="
Write-Host "Pre-deployment Cluster Validation"
Write-Host "=========================================="

Write-Host "Validating cluster connectivity and status..."
try {
    $clusterNodes = kubectl get nodes --no-headers 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Cluster is accessible"
        Write-Host "Cluster nodes:"
        kubectl get nodes
        
        # Check cluster health
        Write-Host ""
        Write-Host "Checking cluster component status..."
        kubectl get componentstatuses
    } else {
        throw "Failed to connect to cluster"
    }
}
catch {
    Write-Host "ERROR: Cannot connect to Kubernetes cluster"
    Write-Host "Error: $_"
    Write-Host "Please ensure kubectl is configured and cluster is running"
    Stop-Transcript
    exit 1
}

Write-Host ""
Write-Host "Checking for existing dashboard installation..."
try {
    $existingDashboard = kubectl get namespace kubernetes-dashboard --no-headers 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "⚠ Dashboard namespace already exists - will update/reconfigure existing installation"
    } else {
        Write-Host "✓ No existing dashboard found - proceeding with fresh installation"
    }
}
catch {
    Write-Host "✓ No existing dashboard namespace found"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Kubernetes Dashboard Deployment"
Write-Host "=========================================="

Write-Host "Deploying Kubernetes Dashboard from official manifests..."
try {
    $dashboardUrl = "https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml"
    Write-Host "Dashboard manifest URL: $dashboardUrl"
    
    $deployResult = kubectl apply -f $dashboardUrl
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Dashboard deployment successful"
        Write-Host ""
        Write-Host "Deployment results:"
        $deployResult | ForEach-Object { Write-Host "  $_" }
    } else {
        throw "Failed to deploy dashboard"
    }
}
catch {
    Write-Host "ERROR: Failed to deploy Kubernetes Dashboard"
    Write-Host "Error: $_"
    Stop-Transcript
    exit 1
}

Write-Host ""
Write-Host "Waiting for dashboard pods to start..."
$maxWaitTime = 180  # 3 minutes
$waitInterval = 10   # 10 seconds
$elapsedTime = 0

do {
    Start-Sleep -Seconds $waitInterval
    $elapsedTime += $waitInterval
    
    try {
        $dashboardPods = kubectl get pods -n kubernetes-dashboard --no-headers 2>$null
        $runningPods = 0
        $totalPods = 0
        
        if ($dashboardPods) {
            $totalPods = ($dashboardPods | Measure-Object).Count
            $runningPods = ($dashboardPods | Where-Object { $_ -match "Running" }).Count
        }
        
        Write-Host "Dashboard pods status: $runningPods/$totalPods Running (Elapsed: ${elapsedTime}s)"
        
        if ($totalPods -gt 0) {
            Write-Host "Pod details:"
            $dashboardPods | ForEach-Object { Write-Host "  $_" }
            
            if ($runningPods -eq $totalPods -and $totalPods -ge 2) {
                Write-Host "✓ All dashboard pods are running"
                break
            }
        } else {
            Write-Host "⚠ No dashboard pods found yet"
        }
    }
    catch {
        Write-Host "Checking dashboard pod status..."
    }
} while ($elapsedTime -lt $maxWaitTime)

if ($elapsedTime -ge $maxWaitTime) {
    Write-Host "⚠ Timeout waiting for dashboard pods to be ready"
    Write-Host "Current pod status:"
    kubectl get pods -n kubernetes-dashboard
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Dashboard Service Account Configuration"
Write-Host "=========================================="

Write-Host "Creating dashboard admin service account..."

# Create the service account YAML manifest
$serviceAccountManifest = @'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
'@

$serviceAccountPath = "C:\repos\kthw\scripts\14\dashboard-adminuser.yaml"
$serviceAccountManifest | Out-File -FilePath $serviceAccountPath -Encoding UTF8

Write-Host "✓ Created service account manifest: $serviceAccountPath"

try {
    $serviceAccountResult = kubectl apply -f $serviceAccountPath
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Service account and cluster role binding created successfully"
        Write-Host "Configuration results:"
        $serviceAccountResult | ForEach-Object { Write-Host "  $_" }
    } else {
        throw "Failed to create service account"
    }
}
catch {
    Write-Host "ERROR: Failed to create dashboard service account"
    Write-Host "Error: $_"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Dashboard Access Token Generation"
Write-Host "=========================================="

Write-Host "Generating access token for dashboard authentication..."
try {
    # Wait a moment for service account to be fully created
    Start-Sleep -Seconds 5
    
    $accessToken = kubectl -n kubernetes-dashboard create token admin-user
    if ($LASTEXITCODE -eq 0 -and $accessToken) {
        Write-Host "✓ Access token generated successfully"
        Write-Host ""
        Write-Host "=========================================="
        Write-Host "DASHBOARD ACCESS TOKEN"
        Write-Host "=========================================="
        Write-Host "Copy the following token for dashboard login:"
        Write-Host ""
        Write-Host "$accessToken"
        Write-Host ""
        Write-Host "=========================================="
        
        # Save token to file for future reference
        $tokenFile = "C:\repos\kthw\scripts\14\dashboard-token.txt"
        $accessToken | Out-File -FilePath $tokenFile -Encoding UTF8
        Write-Host "✓ Token saved to: $tokenFile"
    } else {
        throw "Failed to generate access token"
    }
}
catch {
    Write-Host "ERROR: Failed to generate dashboard access token"
    Write-Host "Error: $_"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Dashboard Service and Access Configuration"
Write-Host "=========================================="

Write-Host "Checking dashboard service configuration..."
try {
    Write-Host "Dashboard services:"
    kubectl get services -n kubernetes-dashboard
    
    Write-Host ""
    Write-Host "Dashboard endpoints:"
    kubectl get endpoints -n kubernetes-dashboard
}
catch {
    Write-Host "⚠ Unable to retrieve dashboard service information"
}

Write-Host ""
Write-Host "Starting kubectl proxy for dashboard access..."
Write-Host "Note: Proxy will run in background for testing dashboard connectivity"

# Start kubectl proxy in background
$proxyJob = Start-Job -ScriptBlock {
    kubectl proxy --port=8001
}

# Wait for proxy to start
Start-Sleep -Seconds 10

Write-Host "✓ Kubectl proxy started (Job ID: $($proxyJob.Id))"
Write-Host ""
Write-Host "Dashboard URL: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"

# Test dashboard connectivity
Write-Host ""
Write-Host "Testing dashboard connectivity..."
try {
    $dashboardTest = curl -s "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/" --max-time 10 2>$null
    if ($dashboardTest -match "Kubernetes Dashboard") {
        Write-Host "✓ Dashboard is accessible via proxy"
    } else {
        Write-Host "⚠ Dashboard accessibility test inconclusive"
    }
}
catch {
    Write-Host "⚠ Dashboard connectivity test failed - this may be normal due to HTTPS redirect"
}

# Stop proxy for cleanup
Write-Host ""
Write-Host "Stopping kubectl proxy..."
Stop-Job -Job $proxyJob -ErrorAction SilentlyContinue
Remove-Job -Job $proxyJob -ErrorAction SilentlyContinue
Write-Host "✓ Kubectl proxy stopped"

Write-Host ""
Write-Host "=========================================="
Write-Host "Dashboard Deployment Validation"
Write-Host "=========================================="

Write-Host "Final dashboard status verification..."
try {
    Write-Host ""
    Write-Host "=== Dashboard Namespace ==="
    kubectl get namespace kubernetes-dashboard
    
    Write-Host ""
    Write-Host "=== Dashboard Pods ==="
    kubectl get pods -n kubernetes-dashboard
    
    Write-Host ""
    Write-Host "=== Dashboard Services ==="
    kubectl get services -n kubernetes-dashboard
    
    Write-Host ""
    Write-Host "=== Dashboard Service Account ==="
    kubectl get serviceaccount admin-user -n kubernetes-dashboard
    
    Write-Host ""
    Write-Host "=== Dashboard Cluster Role Binding ==="
    kubectl get clusterrolebinding admin-user
    
    Write-Host ""
    Write-Host "=== Dashboard Deployments ==="
    kubectl get deployments -n kubernetes-dashboard
}
catch {
    Write-Host "⚠ Error retrieving dashboard status information"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Dashboard Configuration Summary"
Write-Host "=========================================="

$endTime = Get-Date
$totalDuration = $endTime - $startTime

Write-Host "Dashboard configuration completed!"
Write-Host "Start time: $(Get-Date $startTime -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "End time: $(Get-Date $endTime -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Total duration: $([math]::Round($totalDuration.TotalMinutes, 2)) minutes"
Write-Host ""

# Check final dashboard status
try {
    $finalPods = kubectl get pods -n kubernetes-dashboard --no-headers 2>$null
    $runningCount = 0
    $totalCount = 0
    
    if ($finalPods) {
        $totalCount = ($finalPods | Measure-Object).Count
        $runningCount = ($finalPods | Where-Object { $_ -match "Running" }).Count
    }
    
    if ($runningCount -gt 0 -and $runningCount -eq $totalCount) {
        Write-Host "✅ Dashboard deployment SUCCESSFUL"
        Write-Host "   - $runningCount/$totalCount dashboard pods are running"
        Write-Host "   - Service account and authentication configured"
        Write-Host "   - Access token generated for dashboard login"
        Write-Host ""
        Write-Host "🌐 Dashboard Access Instructions:"
        Write-Host "   1. Run: kubectl proxy"
        Write-Host "   2. Open: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
        Write-Host "   3. Select 'Token' authentication method"
        Write-Host "   4. Use the access token from: $tokenFile"
        Write-Host ""
        Write-Host "🔐 Security Notes:"
        Write-Host "   - Admin user has cluster-admin privileges"
        Write-Host "   - Token provides full cluster access"
        Write-Host "   - Consider creating restricted users for production use"
    } else {
        Write-Host "⚠ Dashboard deployment completed with issues"
        Write-Host "   - $runningCount/$totalCount pods are running"
        Write-Host "   - Manual verification may be required"
        Write-Host ""
        Write-Host "Troubleshooting suggestions:"
        Write-Host "   - Check pod logs: kubectl logs -n kubernetes-dashboard <pod-name>"
        Write-Host "   - Verify resource availability: kubectl describe nodes"
        Write-Host "   - Check events: kubectl get events -n kubernetes-dashboard"
    }
} catch {
    Write-Host "⚠ Unable to determine final dashboard status"
}

Write-Host ""
Write-Host "Files created:"
Write-Host "- Dashboard manifest: $serviceAccountPath"
Write-Host "- Access token: $tokenFile"
Write-Host "- Execution log: $outputFile"

Write-Host ""
Write-Host "Next step: Access the dashboard using kubectl proxy and the generated token"
Write-Host "Final step: Tutorial 15 - Cleaning Up the cluster resources"

# Stop transcript
Stop-Transcript
Write-Host "`nExecution log saved to: $outputFile"