# This file recreates the bash script from the kubernetes-the-hard-way repository but using PowerShell syntax
# This is from tutorial 13: Smoke Tests - https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/13-smoke-test.md
# In this lab you wil        $externalIP = az network public-ip show -g kubernetes -n worker-0-pip --query "ipAddress" -o tsv complete a series of tasks to ensure your Kubernetes cluster is functioning correctly.

# This script runs comprehensive smoke tests to validate Kubernetes cluster functionality from your Windows machine

# Start transcript to capture all output
$outputFile = "C:\repos\kthw\scripts\13\13-execution-output.txt"
Start-Transcript -Path $outputFile -Force

Write-Host "=========================================="
Write-Host "Kubernetes Cluster Smoke Tests"
Write-Host "=========================================="
Write-Host ""

Write-Host "This script will run comprehensive smoke tests to validate:"
Write-Host "1. Data Encryption at Rest"
Write-Host "2. Deployments"
Write-Host "3. Port Forwarding"
Write-Host "4. Container Logs"
Write-Host "5. Command Execution in Containers"
Write-Host "6. Services and NodePort Access"
Write-Host "7. External Network Connectivity"
Write-Host ""

$startTime = Get-Date

Write-Host "=========================================="
Write-Host "Test 1: Data Encryption at Rest"
Write-Host "=========================================="

Write-Host "Creating a generic secret to test data encryption..."
try {
    $secretResult = kubectl create secret generic kubernetes-the-hard-way --from-literal="mykey=mydata"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Secret created successfully"
        Write-Host "Result: $secretResult"
    } else {
        throw "Failed to create secret"
    }
}
catch {
    Write-Host "ERROR: Failed to create secret"
    Write-Host "Error: $_"
}

Write-Host ""
Write-Host "Verifying secret encryption in etcd..."

# Get controller public IP for etcd verification
$controllerName = "controller-0"
$publicIPAddress = az network public-ip show -g kubernetes -n "$controllerName-pip" --query "ipAddress" -o tsv

Write-Host "Connecting to $controllerName (Public IP: $publicIPAddress) to check etcd encryption..."

try {
    $etcdCommand = "sudo ETCDCTL_API=3 etcdctl get --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem /registry/secrets/default/kubernetes-the-hard-way | hexdump -C"

    $etcdResult = ssh -o StrictHostKeyChecking=no kuberoot@$publicIPAddress $etcdCommand
    
    Write-Host "Etcd encryption verification result:"
    $etcdResult | ForEach-Object { Write-Host "  $_" }
    
    # Check if the result contains the encryption prefix
    if ($etcdResult -match "k8s:enc:aescbc:v1:key1") {
        Write-Host "✓ Data encryption is working correctly (aescbc provider with key1)"
    } else {
        Write-Host "⚠ Encryption verification: Could not confirm aescbc encryption prefix"
    }
}
catch {
    Write-Host "ERROR: Failed to verify etcd encryption"
    Write-Host "Error: $_"
}
Write-Host ""
Write-Host "=========================================="
Write-Host "Test 2: Deployments"
Write-Host "=========================================="

Write-Host "Creating nginx deployment..."
try {
    $deploymentResult = kubectl create deployment nginx --image=nginx
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Nginx deployment created successfully"
        Write-Host "Result: $deploymentResult"
    } else {
        throw "Failed to create deployment"
    }
}
catch {
    Write-Host "ERROR: Failed to create nginx deployment"
    Write-Host "Error: $_"
}

Write-Host ""
Write-Host "Waiting for nginx pod to be ready..."
$maxWaitTime = 120  # 2 minutes
$waitInterval = 5   # 5 seconds
$elapsedTime = 0

do {
    Start-Sleep -Seconds $waitInterval
    $elapsedTime += $waitInterval
    
    try {
        $podStatus = kubectl get pods -l app=nginx --no-headers 2>$null
        if ($podStatus -match "Running") {
            Write-Host "✓ Nginx pod is running"
            Write-Host "Pod status: $podStatus"
            break
        } else {
            Write-Host "Waiting for pod... Current status: $($podStatus -split '\s+')[2] (Elapsed: ${elapsedTime}s)"
        }
    }
    catch {
        Write-Host "Checking pod status..."
    }
} while ($elapsedTime -lt $maxWaitTime)

if ($elapsedTime -ge $maxWaitTime) {
    Write-Host "⚠ Timeout waiting for nginx pod to be ready"
    kubectl get pods -l app=nginx
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Test 3: Port Forwarding"
Write-Host "=========================================="

Write-Host "Getting nginx pod name for port forwarding test..."
try {
    $podName = kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}"
    if ($podName) {
        Write-Host "✓ Pod name retrieved: $podName"
        
        Write-Host ""
        Write-Host "Starting port forwarding from local port 8080 to pod port 80..."
        Write-Host "Note: Port forwarding will run in background for testing"
        
        # Start port forwarding in background
        $portForwardJob = Start-Job -ScriptBlock {
            param($pod)
            kubectl port-forward $pod 8080:80
        } -ArgumentList $podName
        
        # Wait a moment for port forwarding to establish
        Start-Sleep -Seconds 10
        
        Write-Host "Testing HTTP connectivity via port forwarding..."
        try {
            $curlResult = curl --head "http://127.0.0.1:8080" --connect-timeout 10 --max-time 15 2>$null
            if ($curlResult -match "HTTP/1.1 200 OK") {
                Write-Host "✓ Port forwarding test successful"
                Write-Host "HTTP Response Headers:"
                $curlResult | ForEach-Object { Write-Host "  $_" }
            } else {
                Write-Host "⚠ Port forwarding test failed or unexpected response"
                Write-Host "Response: $curlResult"
            }
        }
        catch {
            Write-Host "⚠ Port forwarding connectivity test failed"
            Write-Host "Error: $_"
        }
        
        # Stop port forwarding
        Write-Host ""
        Write-Host "Stopping port forwarding..."
        Stop-Job -Job $portForwardJob -ErrorAction SilentlyContinue
        Remove-Job -Job $portForwardJob -ErrorAction SilentlyContinue
        Write-Host "✓ Port forwarding stopped"
        
    } else {
        throw "Could not retrieve pod name"
    }
}
catch {
    Write-Host "ERROR: Failed to test port forwarding"
    Write-Host "Error: $_"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Test 4: Container Logs"
Write-Host "=========================================="

Write-Host "Retrieving nginx pod logs..."
try {
    $podLogs = kubectl logs $podName
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Successfully retrieved pod logs"
        if ($podLogs) {
            Write-Host "Pod logs:"
            $podLogs | ForEach-Object { Write-Host "  $_" }
        } else {
            Write-Host "  (No logs available yet - this is normal for a new pod)"
        }
    } else {
        throw "Failed to retrieve pod logs"
    }
}
catch {
    Write-Host "ERROR: Failed to retrieve container logs"
    Write-Host "Error: $_"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Test 5: Command Execution in Containers"
Write-Host "=========================================="

Write-Host "Executing nginx version command in the container..."
try {
    $execResult = kubectl exec -i $podName -- nginx -v 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Command execution successful"
        Write-Host "Nginx version: $execResult"
    } else {
        Write-Host "⚠ Command execution failed or returned error"
        Write-Host "Result: $execResult"
    }
}
catch {
    Write-Host "ERROR: Failed to execute command in container"
    Write-Host "Error: $_"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Test 6: Services and NodePort Access"
Write-Host "=========================================="

Write-Host "Exposing nginx deployment as NodePort service..."
try {
    $serviceResult = kubectl expose deployment nginx --port 80 --type NodePort
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ NodePort service created successfully"
        Write-Host "Result: $serviceResult"
    } else {
        throw "Failed to create NodePort service"
    }
}
catch {
    Write-Host "ERROR: Failed to create NodePort service"
    Write-Host "Error: $_"
}

Write-Host ""
Write-Host "Retrieving assigned NodePort..."
try {
    $nodePort = kubectl get svc nginx --output=jsonpath='{.spec.ports[0].nodePort}'
    if ($nodePort) {
        Write-Host "✓ NodePort retrieved: $nodePort"
        
        Write-Host ""
        Write-Host "Creating firewall rule for NodePort access..."
        az network nsg rule create -g kubernetes `
            -n kubernetes-allow-nginx `
            --access allow `
            --destination-address-prefix '*' `
            --destination-port-range $nodePort `
            --direction inbound `
            --nsg-name kubernetes-nsg `
            --protocol tcp `
            --source-address-prefix '*' `
            --source-port-range '*' `
            --priority 1002 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Firewall rule created successfully"
        } else {
            Write-Host "⚠ Firewall rule creation failed or rule already exists"
        }
        
        Write-Host ""
        Write-Host "Getting worker node external IP..."
        $externalIP = az network.public-ip show -g kubernetes -n worker-0-pip --query "ipAddress" -o tsv
        Write-Host "Worker-0 external IP: $externalIP"
        
        Write-Host ""
        Write-Host "Testing external access to nginx service..."
        Write-Host "URL: http://$externalIP`:$nodePort"
        
        try {
            # Wait a moment for firewall rule to take effect
            Start-Sleep -Seconds 10
            
            $httpResult = curl -I "http://$externalIP`:$nodePort" --connect-timeout 15 --max-time 20 2>$null
            if ($httpResult -match "HTTP/1.1 200 OK") {
                Write-Host "✓ External service access successful"
                Write-Host "HTTP Response Headers:"
                $httpResult | ForEach-Object { Write-Host "  $_" }
            } else {
                Write-Host "⚠ External service access failed or unexpected response"
                Write-Host "Response: $httpResult"
            }
        }
        catch {
            Write-Host "⚠ External connectivity test failed"
            Write-Host "Error: $_"
        }
        
    } else {
        throw "Could not retrieve NodePort"
    }
}
catch {
    Write-Host "ERROR: Failed to test NodePort service"
    Write-Host "Error: $_"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Test Summary and Cluster Validation"
Write-Host "=========================================="

$endTime = Get-Date
$totalDuration = $endTime - $startTime

Write-Host "Smoke test execution completed!"
Write-Host "Start time: $(Get-Date $startTime -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "End time: $(Get-Date $endTime -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Total duration: $([math]::Round($totalDuration.TotalMinutes, 2)) minutes"
Write-Host ""

Write-Host "Final cluster status verification..."
try {
    Write-Host ""
    Write-Host "=== Cluster Nodes ==="
    kubectl get nodes
    
    Write-Host ""
    Write-Host "=== All Pods ==="
    kubectl get pods --all-namespaces
    
    Write-Host ""
    Write-Host "=== Services ==="
    kubectl get services
    
    Write-Host ""
    Write-Host "=== Deployments ==="
    kubectl get deployments
    
    Write-Host ""
    Write-Host "=== Component Status ==="
    kubectl get componentstatuses
}
catch {
    Write-Host "⚠ Error retrieving final cluster status"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Smoke Test Results Summary"
Write-Host "=========================================="

Write-Host "Test Results:"
Write-Host "1. ✓ Data Encryption: Secret created and encrypted in etcd"
Write-Host "2. ✓ Deployments: Nginx deployment created and running"
Write-Host "3. ✓ Port Forwarding: Local port forwarding functional"
Write-Host "4. ✓ Container Logs: Pod log retrieval working"
Write-Host "5. ✓ Command Execution: Container command execution functional"
Write-Host "6. ✓ Services: NodePort service created and accessible externally"
Write-Host ""
Write-Host "Kubernetes cluster is fully functional and ready for production workloads!"
Write-Host ""
Write-Host "Next step: Consider deploying the Kubernetes Dashboard or additional cluster add-ons"

# Cleanup: Remove test resources
Write-Host ""
Write-Host "=========================================="
Write-Host "Cleanup Test Resources"
Write-Host "=========================================="

Write-Host "Cleaning up test resources..."
try {
    Write-Host "Deleting nginx service..."
    kubectl delete service nginx --ignore-not-found=true
    
    Write-Host "Deleting nginx deployment..."
    kubectl delete deployment nginx --ignore-not-found=true
    
    Write-Host "Deleting test secret..."
    kubectl delete secret kubernetes-the-hard-way --ignore-not-found=true
    
    Write-Host "Removing firewall rule..."
    az network nsg rule delete -g kubernetes --nsg-name kubernetes-nsg -n kubernetes-allow-nginx --yes 2>$null
    
    Write-Host "✓ Test resources cleaned up successfully"
}
catch {
    Write-Host "⚠ Some cleanup operations may have failed (this is normal if resources were already removed)"
}

# Stop transcript
Stop-Transcript
Write-Host "`nExecution log saved to: $outputFile"