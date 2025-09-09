
# Kubernetes the Hard Way - Step 14: Dashboard Configuration
# This script installs and configures the Kubernetes Dashboard with proper authentication
# Original tutorial: https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/14-dashboard.md

Write-Host "Starting Kubernetes Dashboard Configuration..." -ForegroundColor Green
Write-Host ("=" * 50) -ForegroundColor Green

# Step 1: Deploy the Kubernetes Dashboard
Write-Host "`nStep 1: Deploying Kubernetes Dashboard..." -ForegroundColor Yellow
Write-Host "Applying dashboard manifests from official repository..."

try {
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Dashboard deployed successfully" -ForegroundColor Green
    } else {
        throw "Failed to deploy dashboard"
    }
} catch {
    Write-Host "❌ Error deploying dashboard: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 2: Wait for dashboard pods to be ready
Write-Host "`nStep 2: Waiting for dashboard pods to start..." -ForegroundColor Yellow
Write-Host "This may take a few minutes..."

$timeout = 120
$elapsed = 0
do {
    Start-Sleep 10
    $elapsed += 10
    try {
        $podStatus = kubectl get pods -n kubernetes-dashboard --no-headers
        if ($LASTEXITCODE -eq 0 -and $podStatus) {
            $runningPods = ($podStatus | Where-Object { $_ -match "Running" } | Measure-Object).Count
            $totalPods = ($podStatus | Measure-Object).Count
            Write-Host "Dashboard pods: $runningPods/$totalPods running (${elapsed}s elapsed)"
            
            if ($runningPods -eq $totalPods -and $totalPods -gt 0) {
                Write-Host "✅ All dashboard pods are running" -ForegroundColor Green
                break
            }
        }
    } catch {
        # Continue waiting if pods aren't ready yet
    }
} while ($elapsed -lt $timeout)

if ($elapsed -ge $timeout) {
    Write-Host "⚠️ Timeout waiting for pods, continuing anyway..." -ForegroundColor Yellow
}

# Step 3: Create Service Account for Dashboard Access
Write-Host "`nStep 3: Creating dashboard admin service account..." -ForegroundColor Yellow

# Create the service account YAML content
$dashboardAdminUser = @'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
'@

# Save to file
$dashboardAdminUser | Out-File -FilePath "dashboard-adminuser.yaml" -Encoding UTF8
Write-Host "Created dashboard-adminuser.yaml"

# Apply the service account
try {
    kubectl apply -f dashboard-adminuser.yaml
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Service account created successfully" -ForegroundColor Green
    } else {
        throw "Failed to create service account"
    }
} catch {
    Write-Host "❌ Error creating service account: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 4: Create Cluster Role Binding
Write-Host "`nStep 4: Creating cluster role binding..." -ForegroundColor Yellow

try {
    # Check if cluster role binding already exists
    $existingBinding = kubectl get clusterrolebinding dashboard-admin --ignore-not-found 2>$null
    if ($existingBinding) {
        Write-Host "✅ Cluster role binding already exists" -ForegroundColor Green
    } else {
        kubectl create clusterrolebinding dashboard-admin -n default --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:admin-user
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Cluster role binding created successfully" -ForegroundColor Green
        } else {
            throw "Failed to create cluster role binding"
        }
    }
} catch {
    Write-Host "❌ Error with cluster role binding: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 5: Generate Access Token
Write-Host "`nStep 5: Generating access token..." -ForegroundColor Yellow

try {
    # Wait a moment for service account to be fully ready
    Start-Sleep 5
    
    $token = kubectl -n kubernetes-dashboard create token admin-user
    if ($LASTEXITCODE -eq 0 -and $token) {
        Write-Host "✅ Access token generated successfully" -ForegroundColor Green
        Write-Host ""
        Write-Host ("=" * 50) -ForegroundColor Cyan
        Write-Host "DASHBOARD ACCESS TOKEN:" -ForegroundColor Cyan
        Write-Host ("=" * 50) -ForegroundColor Cyan
        Write-Host $token -ForegroundColor White
        Write-Host ("=" * 50) -ForegroundColor Cyan
        
        # Save token to file for reference
        $token | Out-File -FilePath "dashboard-token.txt" -Encoding UTF8
        Write-Host "Token saved to dashboard-token.txt"
    } else {
        throw "Failed to generate access token"
    }
} catch {
    Write-Host "❌ Error generating token: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 6: Display access instructions
Write-Host "`nStep 6: Dashboard access instructions" -ForegroundColor Yellow
Write-Host ""
Write-Host "🌐 To access the Kubernetes Dashboard:" -ForegroundColor Green
Write-Host "1. Run: kubectl proxy" -ForegroundColor White
Write-Host "2. Open your browser to:" -ForegroundColor White
Write-Host "   http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/" -ForegroundColor Cyan
Write-Host "3. Select 'Token' authentication method" -ForegroundColor White
Write-Host "4. Paste the token from above (or from dashboard-token.txt)" -ForegroundColor White
Write-Host ""

# Final status check
Write-Host "Final Status Check:" -ForegroundColor Yellow
Write-Host "Dashboard pods:"
kubectl get pods -n kubernetes-dashboard
Write-Host "`nDashboard services:"
kubectl get services -n kubernetes-dashboard
Write-Host "`nService account:"
kubectl get serviceaccount admin-user -n kubernetes-dashboard

Write-Host "`n✅ Dashboard configuration completed successfully!" -ForegroundColor Green
Write-Host "Files created:" -ForegroundColor Yellow
Write-Host "- dashboard-adminuser.yaml" -ForegroundColor White
Write-Host "- dashboard-token.txt" -ForegroundColor White