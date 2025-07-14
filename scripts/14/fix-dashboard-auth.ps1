# Dashboard Authentication Fix Script
# This script resolves common authentication issues with Kubernetes Dashboard

param(
    [switch]$Verbose
)

Write-Host "=========================================="
Write-Host "Kubernetes Dashboard Authentication Fix"
Write-Host "=========================================="
Write-Host ""

$ErrorActionPreference = "Continue"

# Function to write verbose output
function Write-Verbose-Custom {
    param($Message)
    if ($Verbose) {
        Write-Host "[VERBOSE] $Message" -ForegroundColor Cyan
    }
}

# Step 1: Verify cluster connectivity
Write-Host "Step 1: Verifying cluster connectivity..."
try {
    $nodes = kubectl get nodes --no-headers 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Cluster is accessible"
        Write-Verbose-Custom "Nodes: $($nodes -join ', ')"
    } else {
        throw "Cannot connect to cluster"
    }
} catch {
    Write-Host "❌ ERROR: Cannot connect to Kubernetes cluster"
    Write-Host "Please ensure kubectl is configured and cluster is running"
    exit 1
}

# Step 2: Check dashboard namespace and pods
Write-Host ""
Write-Host "Step 2: Checking dashboard installation..."
try {
    $namespace = kubectl get namespace kubernetes-dashboard --no-headers 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Dashboard namespace exists"
        
        $pods = kubectl get pods -n kubernetes-dashboard --no-headers 2>$null
        if ($pods) {
            Write-Host "✓ Dashboard pods found:"
            $pods | ForEach-Object { Write-Host "  $_" }
        } else {
            Write-Host "⚠ No dashboard pods found"
        }
    } else {
        Write-Host "❌ Dashboard namespace not found - please run 14-dashboard-config.ps1 first"
        exit 1
    }
} catch {
    Write-Host "❌ Error checking dashboard installation"
    exit 1
}

# Step 3: Clean up existing service account (if any issues)
Write-Host ""
Write-Host "Step 3: Cleaning up existing service account..."
try {
    # Check if service account exists
    $existingSA = kubectl get serviceaccount admin-user -n kubernetes-dashboard --no-headers 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "⚠ Existing admin-user service account found - removing for clean setup"
        kubectl delete serviceaccount admin-user -n kubernetes-dashboard 2>$null
        kubectl delete clusterrolebinding admin-user 2>$null
        Start-Sleep -Seconds 5
    }
} catch {
    Write-Verbose-Custom "No existing service account to clean up"
}

# Step 4: Create fresh service account with proper RBAC
Write-Host ""
Write-Host "Step 4: Creating fresh service account with proper RBAC..."

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

$serviceAccountPath = "C:\repos\kthw\scripts\14\dashboard-adminuser-fixed.yaml"
$serviceAccountManifest | Out-File -FilePath $serviceAccountPath -Encoding UTF8

try {
    $result = kubectl apply -f $serviceAccountPath
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Service account and cluster role binding created successfully"
        Write-Verbose-Custom "Result: $($result -join ', ')"
    } else {
        throw "Failed to create service account"
    }
} catch {
    Write-Host "❌ ERROR: Failed to create service account"
    Write-Host "Error: $_"
    exit 1
}

# Wait for service account to be fully ready
Write-Host ""
Write-Host "Waiting for service account to be ready..."
Start-Sleep -Seconds 10

# Step 5: Try multiple token generation methods
Write-Host ""
Write-Host "Step 5: Generating authentication token using multiple methods..."

# Method 1: Modern token API with extended duration
Write-Host ""
Write-Host "Method 1: Trying modern token API with 1-year duration..."
try {
    $token1 = kubectl -n kubernetes-dashboard create token admin-user --duration=8760h 2>$null
    if ($LASTEXITCODE -eq 0 -and $token1 -and $token1.Length -gt 50) {
        Write-Host "✓ Method 1 SUCCESS: Modern token generated"
        
        $tokenFile1 = "C:\repos\kthw\scripts\14\dashboard-token-method1.txt"
        $token1 | Out-File -FilePath $tokenFile1 -Encoding UTF8 -NoNewline
        
        Write-Host ""
        Write-Host "=========================================="
        Write-Host "TOKEN METHOD 1 (Recommended)"
        Write-Host "=========================================="
        Write-Host $token1
        Write-Host ""
        Write-Host "Token length: $($token1.Length) characters"
        Write-Host "Token saved to: $tokenFile1"
        
        $workingToken = $token1
        $workingMethod = "Method 1 (Modern API)"
    } else {
        Write-Host "❌ Method 1 FAILED: Modern token API not working"
    }
} catch {
    Write-Host "❌ Method 1 FAILED: $($_.Exception.Message)"
}

# Method 2: Standard token API (default duration)
if (-not $workingToken) {
    Write-Host ""
    Write-Host "Method 2: Trying standard token API..."
    try {
        $token2 = kubectl -n kubernetes-dashboard create token admin-user 2>$null
        if ($LASTEXITCODE -eq 0 -and $token2 -and $token2.Length -gt 50) {
            Write-Host "✓ Method 2 SUCCESS: Standard token generated"
            
            $tokenFile2 = "C:\repos\kthw\scripts\14\dashboard-token-method2.txt"
            $token2 | Out-File -FilePath $tokenFile2 -Encoding UTF8 -NoNewline
            
            Write-Host ""
            Write-Host "=========================================="
            Write-Host "TOKEN METHOD 2"
            Write-Host "=========================================="
            Write-Host $token2
            Write-Host ""
            Write-Host "Token length: $($token2.Length) characters"
            Write-Host "Token saved to: $tokenFile2"
            
            $workingToken = $token2
            $workingMethod = "Method 2 (Standard API)"
        } else {
            Write-Host "❌ Method 2 FAILED: Standard token API not working"
        }
    } catch {
        Write-Host "❌ Method 2 FAILED: $($_.Exception.Message)"
    }
}

# Method 3: Legacy secret-based token
if (-not $workingToken) {
    Write-Host ""
    Write-Host "Method 3: Trying legacy secret-based token..."
    try {
        # Create secret for token
        $secretManifest = @'
apiVersion: v1
kind: Secret
metadata:
  name: admin-user-token
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: admin-user
type: kubernetes.io/service-account-token
'@
        
        $secretPath = "C:\repos\kthw\scripts\14\admin-user-secret.yaml"
        $secretManifest | Out-File -FilePath $secretPath -Encoding UTF8
        
        kubectl apply -f $secretPath 2>$null
        Start-Sleep -Seconds 15  # Wait longer for secret to be populated
        
        $token3 = kubectl get secret admin-user-token -n kubernetes-dashboard -o jsonpath="{.data.token}" 2>$null | ForEach-Object { 
            [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) 
        }
        
        if ($token3 -and $token3.Length -gt 50) {
            Write-Host "✓ Method 3 SUCCESS: Legacy secret token generated"
            
            $tokenFile3 = "C:\repos\kthw\scripts\14\dashboard-token-method3.txt"
            $token3 | Out-File -FilePath $tokenFile3 -Encoding UTF8 -NoNewline
            
            Write-Host ""
            Write-Host "=========================================="
            Write-Host "TOKEN METHOD 3 (Legacy)"
            Write-Host "=========================================="
            Write-Host $token3
            Write-Host ""
            Write-Host "Token length: $($token3.Length) characters"
            Write-Host "Token saved to: $tokenFile3"
            
            $workingToken = $token3
            $workingMethod = "Method 3 (Legacy Secret)"
        } else {
            Write-Host "❌ Method 3 FAILED: Legacy secret token not working"
        }
    } catch {
        Write-Host "❌ Method 3 FAILED: $($_.Exception.Message)"
    }
}

# Check if we got a working token
if (-not $workingToken) {
    Write-Host ""
    Write-Host "❌ CRITICAL ERROR: All token generation methods failed"
    Write-Host ""
    Write-Host "Debugging information:"
    Write-Host "- Service Account Status:"
    kubectl get serviceaccount admin-user -n kubernetes-dashboard
    Write-Host "- Cluster Role Binding Status:"
    kubectl get clusterrolebinding admin-user
    Write-Host "- Kubernetes Version:"
    kubectl version --short
    exit 1
}

# Step 6: Validate the token and service account permissions
Write-Host ""
Write-Host "Step 6: Validating token and permissions..."
try {
    # Test if the service account can perform cluster-admin actions
    $canDoAll = kubectl auth can-i "*" "*" --as=system:serviceaccount:kubernetes-dashboard:admin-user 2>$null
    if ($canDoAll -match "yes") {
        Write-Host "✓ Service account has cluster-admin permissions"
    } else {
        Write-Host "⚠ Service account permissions may be limited"
    }
    
    # Check token format (should be JWT)
    if ($workingToken -match "^eyJ[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]*$") {
        Write-Host "✓ Token format is valid JWT"
    } else {
        Write-Host "⚠ Token format may not be valid JWT"
    }
} catch {
    Write-Host "⚠ Could not validate permissions"
}

# Step 7: Test dashboard connectivity
Write-Host ""
Write-Host "Step 7: Testing dashboard connectivity..."
try {
    $services = kubectl get services -n kubernetes-dashboard --no-headers 2>$null
    if ($services) {
        Write-Host "✓ Dashboard services are available:"
        $services | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "⚠ No dashboard services found"
    }
} catch {
    Write-Host "⚠ Could not check dashboard services"
}

# Final instructions
Write-Host ""
Write-Host "=========================================="
Write-Host "FINAL DASHBOARD ACCESS INSTRUCTIONS"
Write-Host "=========================================="
Write-Host ""
Write-Host "✅ Token generated successfully using: $workingMethod"
Write-Host ""
Write-Host "🔐 YOUR DASHBOARD TOKEN:"
Write-Host "----------------------------------------"
Write-Host $workingToken
Write-Host "----------------------------------------"
Write-Host ""
Write-Host "📋 STEP-BY-STEP ACCESS INSTRUCTIONS:"
Write-Host ""
Write-Host "1. Start kubectl proxy (in a new terminal):"
Write-Host "   kubectl proxy"
Write-Host ""
Write-Host "2. Open dashboard URL in your browser:"
Write-Host "   http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
Write-Host ""
Write-Host "3. On the login page:"
Write-Host "   • Select 'Token' (NOT Kubeconfig)"
Write-Host "   • Clear the token field completely"
Write-Host "   • Copy the ENTIRE token from above (all characters)"
Write-Host "   • Paste it into the 'Enter token' field"
Write-Host "   • Make sure there are NO extra spaces or line breaks"
Write-Host "   • Click 'Sign in'"
Write-Host ""
Write-Host "🚨 IMPORTANT NOTES:"
Write-Host "• The token is the ENTIRE string between the dashes above"
Write-Host "• Do NOT include any spaces, line breaks, or partial token"
Write-Host "• If copy/paste doesn't work, try typing the token manually"
Write-Host "• The token starts with 'eyJ' and is very long"
Write-Host ""
Write-Host "🔧 TROUBLESHOOTING:"
Write-Host "• If still getting 401 error, restart kubectl proxy"
Write-Host "• Try a different browser or incognito mode"
Write-Host "• Verify the URL is exactly as shown above"
Write-Host "• Check that dashboard pods are running:"
Write-Host "  kubectl get pods -n kubernetes-dashboard"
Write-Host ""

# Save the working token to a clean file
$finalTokenFile = "C:\repos\kthw\scripts\14\dashboard-token-WORKING.txt"
$workingToken | Out-File -FilePath $finalTokenFile -Encoding UTF8 -NoNewline

Write-Host "💾 Working token saved to: $finalTokenFile"
Write-Host ""
Write-Host "If you continue to have issues, the token file contains the exact"
Write-Host "token string that should work. You can also try the other token"
Write-Host "methods saved in different files."

Write-Host ""
Write-Host "=========================================="
Write-Host "Authentication Fix Complete"
Write-Host "=========================================="
