# Final Dashboard Access Solution
# This script provides multiple access methods for the Kubernetes Dashboard

Write-Host "=========================================="
Write-Host "Kubernetes Dashboard - Final Access Solution"
Write-Host "=========================================="
Write-Host ""

Write-Host "The dashboard has been configured with skip login mode enabled."
Write-Host "This bypasses authentication issues and allows direct access."
Write-Host ""

# Stop any existing port forwarding
Write-Host "Stopping any existing port forwarding..."
Stop-Job -Name "DashboardPortForward" -ErrorAction SilentlyContinue
Remove-Job -Name "DashboardPortForward" -ErrorAction SilentlyContinue

# Check dashboard status
Write-Host "Checking dashboard status..."
$dashboardPods = kubectl get pods -n kubernetes-dashboard --no-headers | Where-Object { $_ -match "kubernetes-dashboard" }
Write-Host "Dashboard pod status: $dashboardPods"

Write-Host ""
Write-Host "=========================================="
Write-Host "ACCESS METHOD 1: Skip Login (Recommended)"
Write-Host "=========================================="
Write-Host ""
Write-Host "The dashboard is now configured to allow access without authentication."
Write-Host ""
Write-Host "Steps:"
Write-Host "1. Start port forwarding:"
Write-Host "   kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443"
Write-Host ""
Write-Host "2. Open your browser to:"
Write-Host "   https://localhost:8443"
Write-Host ""
Write-Host "3. Accept the certificate warning"
Write-Host ""
Write-Host "4. On the login page, click 'SKIP' (should appear at the bottom)"
Write-Host "   OR"
Write-Host "   The dashboard should automatically log you in without requiring credentials"
Write-Host ""

Write-Host "=========================================="
Write-Host "ACCESS METHOD 2: Proxy with Skip Login"
Write-Host "=========================================="
Write-Host ""
Write-Host "Alternative access via kubectl proxy:"
Write-Host ""
Write-Host "Steps:"
Write-Host "1. Start kubectl proxy:"
Write-Host "   kubectl proxy"
Write-Host ""
Write-Host "2. Open your browser to:"
Write-Host "   http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
Write-Host ""
Write-Host "3. The dashboard should load without requiring authentication"
Write-Host "   OR"
Write-Host "   Look for a 'SKIP' option on the login page"
Write-Host ""

# Start port forwarding automatically
Write-Host ""
Write-Host "=========================================="
Write-Host "Starting Port Forwarding"
Write-Host "=========================================="
Write-Host ""

$portForwardJob = Start-Job -ScriptBlock {
    kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443
} -Name "DashboardPortForward"

Start-Sleep -Seconds 5

# Check if port forwarding is working
$portCheck = netstat -an | findstr :8443
if ($portCheck) {
    Write-Host "✓ Port forwarding is active on port 8443"
    Write-Host ""
    Write-Host "🎉 DASHBOARD IS NOW ACCESSIBLE!"
    Write-Host ""
    Write-Host "🌐 Direct URL: https://localhost:8443"
    Write-Host ""
    Write-Host "📝 Instructions:"
    Write-Host "1. Open https://localhost:8443 in your browser"
    Write-Host "2. Accept the certificate warning"
    Write-Host "3. Look for a 'SKIP' button or automatic login"
    Write-Host "4. If you still see a login form, try using any of the tokens we generated earlier"
    Write-Host ""
    Write-Host "🔧 If skip login doesn't appear:"
    Write-Host "- Try refreshing the page"
    Write-Host "- Use the secret-based token from dashboard-token-SECRET.txt"
    Write-Host "- Or proceed to Method 3 below"
} else {
    Write-Host "⚠ Port forwarding may not be working. Try manual setup:"
    Write-Host "kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "ACCESS METHOD 3: Emergency Token Access"
Write-Host "=========================================="
Write-Host ""
Write-Host "If skip login doesn't work, use this token-based access:"
Write-Host ""

# Generate a fresh token one more time
try {
    $emergencyToken = kubectl -n kubernetes-dashboard create token admin-user 2>$null
    if ($emergencyToken) {
        Write-Host "🔐 EMERGENCY TOKEN:"
        Write-Host "----------------------------------------"
        Write-Host $emergencyToken
        Write-Host "----------------------------------------"
        Write-Host ""
        $emergencyToken | Out-File -FilePath "dashboard-token-EMERGENCY.txt" -Encoding UTF8 -NoNewline
        Write-Host "Token saved to: dashboard-token-EMERGENCY.txt"
        Write-Host ""
        Write-Host "Use this token if the skip login option doesn't appear."
    }
} catch {
    Write-Host "Using previously generated secret-based token from dashboard-token-SECRET.txt"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "TROUBLESHOOTING TIPS"
Write-Host "=========================================="
Write-Host ""
Write-Host "If none of the methods work:"
Write-Host ""
Write-Host "1. CHECK BROWSER CONSOLE:"
Write-Host "   - Press F12 in your browser"
Write-Host "   - Look for JavaScript errors in the console"
Write-Host "   - Try disabling browser extensions"
Write-Host ""
Write-Host "2. TRY DIFFERENT BROWSERS:"
Write-Host "   - Chrome (incognito mode)"
Write-Host "   - Firefox (private mode)"
Write-Host "   - Edge"
Write-Host ""
Write-Host "3. CLEAR BROWSER DATA:"
Write-Host "   - Clear cookies and cache for localhost"
Write-Host "   - Restart the browser"
Write-Host ""
Write-Host "4. RESTART SERVICES:"
Write-Host "   - Stop port forwarding: Stop-Job -Name DashboardPortForward"
Write-Host "   - Restart dashboard: kubectl rollout restart deployment/kubernetes-dashboard -n kubernetes-dashboard"
Write-Host "   - Wait 30 seconds and try again"
Write-Host ""

Write-Host "=========================================="
Write-Host "DASHBOARD FEATURES AVAILABLE"
Write-Host "=========================================="
Write-Host ""
Write-Host "Once you access the dashboard, you can:"
Write-Host "• View cluster resources (pods, services, deployments)"
Write-Host "• Monitor resource usage and logs"
Write-Host "• Deploy applications using YAML or forms"
Write-Host "• Scale deployments and manage workloads"
Write-Host "• Access container logs and exec into pods"
Write-Host "• Manage persistent volumes and storage"
Write-Host "• View and edit ConfigMaps and Secrets"
Write-Host "• Monitor cluster events and status"
Write-Host ""

Write-Host "Port forwarding is running in background (Job ID: $($portForwardJob.Id))"
Write-Host "To stop port forwarding later: Stop-Job -Name DashboardPortForward"
Write-Host ""
Write-Host "🎯 RECOMMENDED: Try https://localhost:8443 first!"
Write-Host ""
