# Ultimate Dashboard Authentication Fix
# This script uses the traditional secret-based approach for older Kubernetes versions

Write-Host "=========================================="
Write-Host "Ultimate Dashboard Authentication Fix"
Write-Host "Using Traditional Secret-Based Method"
Write-Host "=========================================="
Write-Host ""

# Step 1: Completely remove existing setup
Write-Host "Step 1: Cleaning up all existing authentication resources..."
kubectl delete serviceaccount admin-user -n kubernetes-dashboard 2>$null
kubectl delete clusterrolebinding admin-user 2>$null
kubectl delete secret admin-user-token -n kubernetes-dashboard 2>$null

Start-Sleep -Seconds 5

# Step 2: Create traditional service account with secret
Write-Host ""
Write-Host "Step 2: Creating service account with traditional secret method..."

$traditionalManifest = @'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: v1
kind: Secret
metadata:
  name: admin-user-token
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: admin-user
type: kubernetes.io/service-account-token
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

$traditionalPath = "C:\repos\kthw\scripts\14\traditional-admin-user.yaml"
$traditionalManifest | Out-File -FilePath $traditionalPath -Encoding UTF8

kubectl apply -f $traditionalPath

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Traditional service account and secret created"
} else {
    Write-Host "❌ Failed to create traditional setup"
    exit 1
}

# Step 3: Wait for secret to be populated
Write-Host ""
Write-Host "Step 3: Waiting for secret to be populated by Kubernetes..."
$maxWait = 60
$waited = 0

do {
    Start-Sleep -Seconds 5
    $waited += 5
    
    $secretData = kubectl get secret admin-user-token -n kubernetes-dashboard -o jsonpath='{.data.token}' 2>$null
    if ($secretData -and $secretData.Length -gt 10) {
        Write-Host "✓ Secret populated after $waited seconds"
        break
    } else {
        Write-Host "⏳ Waiting for secret population... ($waited/$maxWait seconds)"
    }
} while ($waited -lt $maxWait)

if ($waited -ge $maxWait) {
    Write-Host "❌ Secret was not populated within $maxWait seconds"
    Write-Host "Checking secret status..."
    kubectl describe secret admin-user-token -n kubernetes-dashboard
    exit 1
}

# Step 4: Extract token from secret
Write-Host ""
Write-Host "Step 4: Extracting token from secret..."

try {
    $base64Token = kubectl get secret admin-user-token -n kubernetes-dashboard -o jsonpath='{.data.token}'
    $secretToken = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($base64Token))
    
    if ($secretToken -and $secretToken.Length -gt 50) {
        Write-Host "✓ Token successfully extracted from secret"
        Write-Host "Token length: $($secretToken.Length) characters"
        
        # Save the secret-based token
        $secretTokenFile = "C:\repos\kthw\scripts\14\dashboard-token-SECRET.txt"
        $secretToken | Out-File -FilePath $secretTokenFile -Encoding UTF8 -NoNewline
        
        Write-Host ""
        Write-Host "=========================================="
        Write-Host "SECRET-BASED TOKEN (Traditional Method)"
        Write-Host "=========================================="
        Write-Host $secretToken
        Write-Host ""
        Write-Host "Token saved to: $secretTokenFile"
        
        $workingToken = $secretToken
    } else {
        throw "Token extraction failed or token is too short"
    }
} catch {
    Write-Host "❌ Failed to extract token from secret: $($_.Exception.Message)"
    
    Write-Host "Debugging secret information:"
    kubectl get secret admin-user-token -n kubernetes-dashboard -o yaml
    exit 1
}

# Step 5: Create a minimal kubeconfig for this token
Write-Host ""
Write-Host "Step 5: Creating minimal kubeconfig with secret-based token..."

# Get cluster info
$clusterServer = kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
$clusterCA = kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'

$minimalKubeconfig = @"
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $clusterCA
    server: $clusterServer
  name: dashboard-cluster
contexts:
- context:
    cluster: dashboard-cluster
    user: admin-user
  name: admin-user@dashboard
current-context: admin-user@dashboard
users:
- name: admin-user
  user:
    token: $workingToken
"@

$minimalKubeconfigPath = "C:\repos\kthw\scripts\14\dashboard-minimal-kubeconfig.yaml"
$minimalKubeconfig | Out-File -FilePath $minimalKubeconfigPath -Encoding UTF8

Write-Host "✓ Minimal kubeconfig created: $minimalKubeconfigPath"

# Step 6: Test the token
Write-Host ""
Write-Host "Step 6: Testing the secret-based token..."

# Test with kubectl using the token
$testResult = kubectl auth can-i get pods --token="$workingToken" 2>$null
if ($testResult -match "yes") {
    Write-Host "✓ Secret-based token has valid permissions"
} else {
    Write-Host "⚠ Token permissions test inconclusive"
}

# Check service account details
Write-Host ""
Write-Host "Service account details:"
kubectl get serviceaccount admin-user -n kubernetes-dashboard -o yaml | Select-String -Pattern "name:|uid:|secrets:"

Write-Host ""
Write-Host "Secret details:"
kubectl get secret admin-user-token -n kubernetes-dashboard | Select-String -Pattern "admin-user-token"

# Step 7: Alternative browser test
Write-Host ""
Write-Host "=========================================="
Write-Host "FINAL INSTRUCTIONS - SECRET-BASED METHOD"
Write-Host "=========================================="
Write-Host ""
Write-Host "The traditional secret-based token has been created."
Write-Host "This method works with older Kubernetes versions and dashboard configurations."
Write-Host ""
Write-Host "🔐 SECRET-BASED TOKEN:"
Write-Host "----------------------------------------"
Write-Host $workingToken
Write-Host "----------------------------------------"
Write-Host ""
Write-Host "📋 TRY THESE METHODS IN ORDER:"
Write-Host ""
Write-Host "METHOD 1: Port Forward + Secret Token"
Write-Host "1. kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443"
Write-Host "2. https://localhost:8443"
Write-Host "3. Accept certificate warning"
Write-Host "4. Use Token authentication with the SECRET-BASED token above"
Write-Host ""
Write-Host "METHOD 2: Proxy + Secret Token"
Write-Host "1. kubectl proxy"
Write-Host "2. http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
Write-Host "3. Use Token authentication with the SECRET-BASED token above"
Write-Host ""
Write-Host "METHOD 3: Minimal Kubeconfig"
Write-Host "1. Use the file: $minimalKubeconfigPath"
Write-Host "2. Upload this file using Kubeconfig authentication method"
Write-Host ""
Write-Host "🚨 IMPORTANT:"
Write-Host "• This token is generated using the traditional secret method"
Write-Host "• It should work with all dashboard versions"
Write-Host "• If this doesn't work, there may be a dashboard configuration issue"
Write-Host ""
Write-Host "Files created:"
Write-Host "- Traditional manifest: $traditionalPath"
Write-Host "- Secret-based token: $secretTokenFile"
Write-Host "- Minimal kubeconfig: $minimalKubeconfigPath"
