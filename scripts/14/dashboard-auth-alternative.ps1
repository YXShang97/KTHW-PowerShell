# Alternative Dashboard Authentication Fix
# This script creates a kubeconfig file for dashboard authentication as an alternative to token auth

Write-Host "=========================================="
Write-Host "Creating Kubeconfig Authentication"
Write-Host "=========================================="
Write-Host ""

# Get cluster information
$clusterInfo = kubectl cluster-info | Select-String "Kubernetes control plane"
$controlPlaneUrl = ($clusterInfo -split "running at ")[1]
Write-Host "Control Plane URL: $controlPlaneUrl"

# Get cluster CA certificate
Write-Host ""
Write-Host "Extracting cluster CA certificate..."
$clusterCA = kubectl get configmap -n kube-public cluster-info -o jsonpath='{.data.kubeconfig}' | Select-String "certificate-authority-data" | ForEach-Object { ($_ -split ": ")[1].Trim() }

if (-not $clusterCA) {
    # Alternative method to get CA data
    $caData = kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'
    $clusterCA = $caData
}

Write-Host "CA Certificate extracted: $($clusterCA.Substring(0, 50))..."

# Create kubeconfig for dashboard
$dashboardKubeconfig = @"
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $clusterCA
    server: $controlPlaneUrl
  name: kubernetes-dashboard-cluster
contexts:
- context:
    cluster: kubernetes-dashboard-cluster
    user: admin-user
  name: admin-user@kubernetes-dashboard
current-context: admin-user@kubernetes-dashboard
users:
- name: admin-user
  user:
    token: $(Get-Content "C:\repos\kthw\scripts\14\dashboard-token-WORKING.txt")
"@

$kubeconfigPath = "C:\repos\kthw\scripts\14\dashboard-kubeconfig.yaml"
$dashboardKubeconfig | Out-File -FilePath $kubeconfigPath -Encoding UTF8

Write-Host "✓ Kubeconfig created: $kubeconfigPath"

Write-Host ""
Write-Host "=========================================="
Write-Host "ALTERNATIVE AUTHENTICATION METHOD"
Write-Host "=========================================="
Write-Host ""
Write-Host "Since token authentication is not working, try using kubeconfig instead:"
Write-Host ""
Write-Host "1. Start kubectl proxy (if not already running):"
Write-Host "   kubectl proxy"
Write-Host ""
Write-Host "2. Open dashboard URL:"
Write-Host "   http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
Write-Host ""
Write-Host "3. On the login page:"
Write-Host "   • Select 'Kubeconfig' (NOT Token)"
Write-Host "   • Click 'Choose file'"
Write-Host "   • Select the file: $kubeconfigPath"
Write-Host "   • Click 'Sign in'"
Write-Host ""

# Also try creating a simpler token without duration
Write-Host ""
Write-Host "=========================================="
Write-Host "TRYING SIMPLER TOKEN GENERATION"
Write-Host "=========================================="

$simpleToken = kubectl -n kubernetes-dashboard create token admin-user 2>$null
if ($LASTEXITCODE -eq 0 -and $simpleToken) {
    Write-Host "✓ Simple token (no duration) generated:"
    Write-Host $simpleToken
    
    $simpleTokenFile = "C:\repos\kthw\scripts\14\dashboard-token-simple.txt"
    $simpleToken | Out-File -FilePath $simpleTokenFile -Encoding UTF8 -NoNewline
    Write-Host ""
    Write-Host "Simple token saved to: $simpleTokenFile"
    Write-Host "Try this token if kubeconfig doesn't work"
} else {
    Write-Host "❌ Simple token generation failed"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "DIRECT SERVICE ACCESS TEST"
Write-Host "=========================================="

# Try accessing dashboard service directly
Write-Host "Testing direct access to dashboard service..."
try {
    $dashboardSvc = kubectl get service kubernetes-dashboard -n kubernetes-dashboard -o jsonpath='{.spec.clusterIP}'
    Write-Host "Dashboard service IP: $dashboardSvc"
    
    Write-Host ""
    Write-Host "Alternative access method:"
    Write-Host "1. Port forward to dashboard service:"
    Write-Host "   kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443"
    Write-Host ""
    Write-Host "2. Access dashboard directly:"
    Write-Host "   https://localhost:8443"
    Write-Host ""
    Write-Host "3. Accept the certificate warning and use token authentication"
} catch {
    Write-Host "Could not get service information"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "VERIFICATION STEPS"
Write-Host "=========================================="

Write-Host ""
Write-Host "Let's verify the dashboard configuration..."

# Check if dashboard is configured for token authentication
Write-Host "Dashboard deployment args:"
kubectl get deployment kubernetes-dashboard -n kubernetes-dashboard -o jsonpath='{.spec.template.spec.containers[0].args}' | Write-Host

Write-Host ""
Write-Host "Dashboard service configuration:"
kubectl get service kubernetes-dashboard -n kubernetes-dashboard -o yaml | Select-String -Pattern "port|targetPort|protocol"

Write-Host ""
Write-Host "All authentication options prepared. Try them in this order:"
Write-Host "1. Kubeconfig file authentication"
Write-Host "2. Simple token (no duration)"
Write-Host "3. Direct port forwarding"
