# This file recreates the bash script from the kubernetes-the-hard-way repository but using PowerShell syntax
# This is from tutorial 12: Deploying the DNS Cluster Add-on - https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/12-dns-addon.md
# In this lab you will deploy the DNS add-on which provides DNS based service discovery, backed by CoreDNS, to applications running inside the Kubernetes cluster.

# This script deploys the CoreDNS cluster add-on for DNS-based service discovery from your Windows machine
# Enhanced with proactive worker node validation, retry logic, and improved error handling

# Start transcript to capture all output
$outputFile = "C:\repos\kthw\scripts\12\12-execution-output.txt"
Start-Transcript -Path $outputFile -Force

Write-Host "=========================================="
Write-Host "Deploying the DNS Cluster Add-on (Enhanced)"
Write-Host "=========================================="
Write-Host ""

Write-Host "This script will deploy CoreDNS for DNS-based service discovery in the Kubernetes cluster."
Write-Host "Enhanced features include:"
Write-Host "1. Proactive worker node configuration validation"
Write-Host "2. Automatic containerd and kubelet cgroup configuration fixes"
Write-Host "3. Robust CoreDNS deployment with retry logic"
Write-Host "4. Extended timeout and monitoring for pod startup"
Write-Host "5. Comprehensive DNS functionality validation"
Write-Host "6. Enhanced error handling and diagnostics"
Write-Host ""

# Define worker instances and deployment parameters
$workerInstances = @("worker-0", "worker-1")
$maxRetries = 3
$deploymentTimeout = 300  # 5 minutes
$startTime = Get-Date

Write-Host "=========================================="
Write-Host "Proactive Worker Node Configuration Validation"
Write-Host "=========================================="

# Validate and fix worker node configuration before DNS deployment to prevent cgroup issues
foreach ($worker in $workerInstances) {
    Write-Host "Validating configuration for $worker..."
    
    try {
        # Get public IP for SSH connection
        $publicIP = az network public-ip show -g kubernetes -n "$worker-pip" --query "ipAddress" -o tsv
        if (-not $publicIP) {
            Write-Host "⚠ Unable to get public IP for $worker, skipping validation"
            continue
        }
        
        Write-Host "Connecting to $worker ($publicIP)..."
        
        # Check cgroup version and containerd configuration
        Write-Host "  Checking cgroup configuration..."
        $cgroupResult = ssh -o StrictHostKeyChecking=no kuberoot@$publicIP "stat -fc %T /sys/fs/cgroup/ 2>/dev/null"
        
        if ($cgroupResult -eq "cgroup2fs") {
            Write-Host "  ✓ Cgroup v2 detected - checking SystemdCgroup configuration"
            
            # Check containerd configuration
            $containerdCheck = ssh -o StrictHostKeyChecking=no kuberoot@$publicIP "grep -c 'SystemdCgroup.*true' /etc/containerd/config.toml 2>/dev/null || echo 0"
            
            if ($containerdCheck -eq "0") {
                Write-Host "  ⚠ SystemdCgroup not enabled in containerd - fixing..."
                
                # Enable SystemdCgroup in containerd configuration
                $containerdFix = @"
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sleep 5
"@
                ssh -o StrictHostKeyChecking=no kuberoot@$publicIP $containerdFix
                Write-Host "  ✓ SystemdCgroup enabled in containerd"
            } else {
                Write-Host "  ✓ SystemdCgroup already enabled in containerd"
            }
            
            # Check kubelet configuration
            $kubeletCheck = ssh -o StrictHostKeyChecking=no kuberoot@$publicIP "grep -c 'cgroupDriver.*systemd' /var/lib/kubelet/kubelet-config.yaml 2>/dev/null || echo 0"
            
            if ($kubeletCheck -eq "0") {
                Write-Host "  ⚠ cgroupDriver not set to systemd in kubelet - fixing..."
                
                # Set cgroupDriver to systemd in kubelet
                $kubeletFix = @"
echo 'cgroupDriver: systemd' | sudo tee -a /var/lib/kubelet/kubelet-config.yaml
sudo systemctl restart kubelet
sleep 5
"@
                ssh -o StrictHostKeyChecking=no kuberoot@$publicIP $kubeletFix
                Write-Host "  ✓ cgroupDriver set to systemd in kubelet"
            } else {
                Write-Host "  ✓ cgroupDriver already set to systemd in kubelet"
            }
            
            # Verify services are running properly
            Write-Host "  Verifying services status..."
            $containerdStatus = ssh -o StrictHostKeyChecking=no kuberoot@$publicIP "systemctl is-active containerd"
            $kubeletStatus = ssh -o StrictHostKeyChecking=no kuberoot@$publicIP "systemctl is-active kubelet"
            
            if ($containerdStatus -eq "active" -and $kubeletStatus -eq "active") {
                Write-Host "  ✓ Both containerd and kubelet are active"
            } else {
                Write-Host "  ⚠ Service status: containerd=$containerdStatus, kubelet=$kubeletStatus"
            }
        } else {
            Write-Host "  ✓ Cgroup v1 detected - no SystemdCgroup configuration needed"
        }
        
        # Check node readiness in cluster
        Write-Host "  Checking node status in cluster..."
        $nodeStatus = kubectl get node $worker --no-headers 2>$null
        if ($nodeStatus -match "Ready") {
            Write-Host "  ✓ Node $worker is Ready in cluster"
        } else {
            Write-Host "  ⚠ Node $worker status: $($nodeStatus -split '\s+')[1]"
        }
        
    } catch {
        Write-Host "  ⚠ Error validating $worker configuration: $_"
    }
    
    Write-Host ""
}

Write-Host "Worker node validation completed. Proceeding with DNS deployment..."
Write-Host ""

Write-Host "=========================================="
Write-Host "Enhanced Cluster Readiness Verification"
Write-Host "=========================================="

# Enhanced cluster readiness check with retries
$retryCount = 0

do {
    $retryCount++
    Write-Host "Checking cluster connectivity (attempt $retryCount/$maxRetries)..."
    
    try {
        $clusterNodes = kubectl get nodes --no-headers 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Cluster is accessible"
            Write-Host "Cluster nodes:"
            kubectl get nodes
            
            # Check that all nodes are Ready
            $readyNodes = kubectl get nodes --no-headers | Where-Object { $_ -match "\sReady\s" }
            $totalNodes = kubectl get nodes --no-headers | Measure-Object | Select-Object -ExpandProperty Count
            $readyCount = if ($readyNodes) { ($readyNodes | Measure-Object).Count } else { 0 }
            
            if ($readyCount -eq $totalNodes -and $totalNodes -gt 0) {
                Write-Host "✓ All $totalNodes nodes are Ready"
                break
            } else {
                Write-Host "⚠ Only $readyCount/$totalNodes nodes are Ready, waiting..."
                if ($retryCount -lt $maxRetries) {
                    Start-Sleep -Seconds 15
                }
            }
        } else {
            throw "Failed to connect to cluster"
        }
    }
    catch {
        if ($retryCount -eq $maxRetries) {
            Write-Host "ERROR: Cannot connect to Kubernetes cluster after $maxRetries attempts"
            Write-Host "Error: $_"
            Write-Host "Please ensure kubectl is configured and cluster is running"
            Stop-Transcript
            exit 1
        } else {
            Write-Host "Cluster not ready, retrying in 15 seconds..."
            Start-Sleep -Seconds 15
        }
    }
} while ($retryCount -lt $maxRetries)

Write-Host ""
Write-Host "Checking if kube-system namespace exists..."
try {
    $namespaceCheck = kubectl get namespace kube-system --no-headers 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ kube-system namespace exists"
    } else {
        Write-Host "Creating kube-system namespace..."
        kubectl create namespace kube-system
        Write-Host "✓ kube-system namespace created"
    }
}
catch {
    Write-Host "WARNING: Unable to verify kube-system namespace"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Preparing Enhanced CoreDNS Manifest"
Write-Host "=========================================="

# Create a robust CoreDNS manifest with better error handling and timeouts
$coreDnsManifestPath = "C:\repos\kthw\scripts\12\coredns-enhanced.yaml"
$coreDnsManifest = @'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: coredns
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:coredns
rules:
- apiGroups:
  - ""
  resources:
  - endpoints
  - services
  - pods
  - namespaces
  verbs:
  - list
  - watch
- apiGroups:
  - discovery.k8s.io
  resources:
  - endpointslices
  verbs:
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:coredns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:coredns
subjects:
- kind: ServiceAccount
  name: coredns
  namespace: kube-system
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
            lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
            ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
            max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: coredns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/name: "CoreDNS"
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  selector:
    matchLabels:
      k8s-app: kube-dns
  template:
    metadata:
      labels:
        k8s-app: kube-dns
    spec:
      serviceAccountName: coredns
      tolerations:
        - key: "CriticalAddonsOnly"
          operator: "Exists"
        - effect: NoSchedule
          key: node-role.kubernetes.io/control-plane
        - effect: NoSchedule
          key: node-role.kubernetes.io/master
      nodeSelector:
        kubernetes.io/os: linux
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: k8s-app
                  operator: In
                  values: ["kube-dns"]
              topologyKey: kubernetes.io/hostname
      containers:
      - name: coredns
        image: coredns/coredns:1.10.1
        imagePullPolicy: IfNotPresent
        resources:
          limits:
            memory: 170Mi
          requests:
            cpu: 100m
            memory: 70Mi
        args: [ "-conf", "/etc/coredns/Corefile" ]
        volumeMounts:
        - name: config-volume
          mountPath: /etc/coredns
          readOnly: true
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        - containerPort: 9153
          name: metrics
          protocol: TCP
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            add:
            - NET_BIND_SERVICE
            drop:
            - all
          readOnlyRootFilesystem: true
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /ready
            port: 8181
            scheme: HTTP
          initialDelaySeconds: 30
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 3
      dnsPolicy: Default
      volumes:
        - name: config-volume
          configMap:
            name: coredns
            items:
            - key: Corefile
              path: Corefile
---
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  annotations:
    prometheus.io/port: "9153"
    prometheus.io/scrape: "true"
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: "CoreDNS"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP: 10.32.0.10
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP
  - name: metrics
    port: 9153
    protocol: TCP
'@

# Write the enhanced manifest to file
$coreDnsManifest | Out-File -FilePath $coreDnsManifestPath -Encoding UTF8
Write-Host "✓ Created enhanced CoreDNS manifest at $coreDnsManifestPath"

Write-Host ""
Write-Host "=========================================="
Write-Host "Enhanced CoreDNS Deployment with Retry Logic"
Write-Host "=========================================="

# Deploy with retry logic and better error handling
$deployRetries = 3
$deployRetryCount = 0

do {
    $deployRetryCount++
    Write-Host "Deploying CoreDNS (attempt $deployRetryCount/$deployRetries)..."
    
    try {
        # Clean up any existing deployment first on retry
        if ($deployRetryCount -gt 1) {
            Write-Host "Cleaning up previous deployment..."
            kubectl delete -f $coreDnsManifestPath --ignore-not-found=true 2>$null
            Start-Sleep -Seconds 15
        }
        
        $coreDnsDeployResult = kubectl apply -f $coreDnsManifestPath
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ CoreDNS cluster add-on deployed successfully"
            Write-Host ""
            Write-Host "Deployment results:"
            $coreDnsDeployResult | ForEach-Object { Write-Host "  $_" }
            break
        } else {
            throw "Failed to deploy CoreDNS"
        }
    }
    catch {
        if ($deployRetryCount -eq $deployRetries) {
            Write-Host "ERROR: Failed to deploy CoreDNS cluster add-on after $deployRetries attempts"
            Write-Host "Error: $_"
            Stop-Transcript
            exit 1
        } else {
            Write-Host "Deployment failed, retrying in 15 seconds..."
            Start-Sleep -Seconds 15
        }
    }
} while ($deployRetryCount -lt $deployRetries)

Write-Host ""
Write-Host "=========================================="
Write-Host "Enhanced CoreDNS Deployment Verification"
Write-Host "=========================================="

# Enhanced waiting with better status reporting and timeout handling
Write-Host "Waiting for CoreDNS pods to start (timeout: $deploymentTimeout seconds)..."
$waitInterval = 10   # 10 seconds
$elapsedTime = 0

do {
    Start-Sleep -Seconds $waitInterval
    $elapsedTime += $waitInterval
    
    try {
        $coreDnsPods = kubectl get pods -l k8s-app=kube-dns -n kube-system --no-headers 2>$null
        $readyPods = 0
        $runningPods = 0
        $totalPods = 0
        
        if ($coreDnsPods) {
            $totalPods = ($coreDnsPods | Measure-Object).Count
            $readyPods = ($coreDnsPods | Where-Object { $_ -match "(\d+)/(\d+)" -and $matches[1] -eq $matches[2] -and $_ -match "Running" }).Count
            $runningPods = ($coreDnsPods | Where-Object { $_ -match "Running" }).Count
        }
        
        Write-Host "CoreDNS pods status: $readyPods/$totalPods Ready, $runningPods/$totalPods Running (Elapsed: ${elapsedTime}s)"
        
        if ($totalPods -gt 0) {
            Write-Host "Pod details:"
            $coreDnsPods | ForEach-Object { Write-Host "  $_" }
            
            # Accept if at least one pod is ready and running
            if ($readyPods -gt 0) {
                Write-Host "✓ At least one CoreDNS pod is ready and running"
                break
            } elseif ($elapsedTime -gt 180 -and $readyPods -eq 0) {
                # If no pods are ready after 3 minutes, check for issues
                Write-Host "⚠ No pods ready after 3 minutes, checking for issues..."
                kubectl describe pods -l k8s-app=kube-dns -n kube-system | Select-String -Pattern "Events:" -A 10 -Context 0,5
            }
        } else {
            Write-Host "⚠ No CoreDNS pods found, checking deployment status..."
            kubectl get deployment coredns -n kube-system
        }
    }
    catch {
        Write-Host "Checking pod status..."
    }
} while ($elapsedTime -lt $deploymentTimeout)

if ($elapsedTime -ge $deploymentTimeout) {
    Write-Host "⚠ Timeout waiting for CoreDNS pods to be ready"
    Write-Host "Current pod status:"
    kubectl get pods -l k8s-app=kube-dns -n kube-system
    Write-Host "Checking recent events for debugging..."
    kubectl get events -n kube-system --sort-by='.lastTimestamp' | Select-Object -Last 15
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Final Verification and Validation"
Write-Host "=========================================="

# Final comprehensive verification
Write-Host "Running final CoreDNS verification..."

try {
    # Check pod status
    Write-Host "CoreDNS pod status:"
    kubectl get pods -l k8s-app=kube-dns -n kube-system
    
    # Check service status
    Write-Host ""
    Write-Host "CoreDNS service status:"
    kubectl get service kube-dns -n kube-system
    
    # Check deployment status
    Write-Host ""
    Write-Host "CoreDNS deployment status:"
    kubectl get deployment coredns -n kube-system
    
    # Extended DNS resolution test
    Write-Host ""
    Write-Host "Testing DNS resolution capabilities..."
    
    # Create a test pod with more comprehensive DNS testing
    $testPodManifest = @'
apiVersion: v1
kind: Pod
metadata:
  name: dns-test-pod
  namespace: default
spec:
  containers:
  - name: dns-test
    image: busybox:1.35
    command: ['sh', '-c', 'sleep 3600']
    resources:
      requests:
        cpu: 50m
        memory: 32Mi
      limits:
        cpu: 100m
        memory: 64Mi
  restartPolicy: Never
  terminationGracePeriodSeconds: 5
'@
    
    $testPodPath = "C:\repos\kthw\scripts\12\dns-test-pod.yaml"
    $testPodManifest | Out-File -FilePath $testPodPath -Encoding UTF8
    
    Write-Host "Creating DNS test pod..."
    kubectl apply -f $testPodPath | Out-Null
    
    # Wait for test pod to be ready
    Write-Host "Waiting for test pod to start..."
    $testWaitTime = 0
    do {
        Start-Sleep -Seconds 5
        $testWaitTime += 5
        $testPodStatus = kubectl get pod dns-test-pod --no-headers 2>$null
        if ($testPodStatus -match "Running") {
            Write-Host "✓ Test pod is running"
            break
        }
    } while ($testWaitTime -lt 60)
    
    if ($testWaitTime -lt 60) {
        Write-Host ""
        Write-Host "Performing DNS resolution tests..."
        
        # Test various DNS queries
        $dnsTests = @(
            @{Name="Kubernetes service"; Query="kubernetes.default.svc.cluster.local"},
            @{Name="CoreDNS service"; Query="kube-dns.kube-system.svc.cluster.local"},
            @{Name="External DNS"; Query="google.com"}
        )
        
        foreach ($test in $dnsTests) {
            Write-Host "Testing $($test.Name) ($($test.Query))..."
            try {
                $dnsResult = kubectl exec dns-test-pod -- nslookup $test.Query 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✓ $($test.Name) resolution successful"
                    # Show first few lines of result
                    $dnsResult | Select-Object -First 3 | ForEach-Object { 
                        if ($_ -and $_.Trim() -ne "") { Write-Host "    $_" }
                    }
                } else {
                    Write-Host "  ⚠ $($test.Name) resolution failed"
                }
            }
            catch {
                Write-Host "  ⚠ $($test.Name) test failed: $_"
            }
        }
        
        # Test service discovery
        Write-Host ""
        Write-Host "Testing service discovery..."
        try {
            $servicesResult = kubectl exec dns-test-pod -- nslookup kubernetes 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✓ Service discovery functional"
            } else {
                Write-Host "  ⚠ Service discovery may have issues"
            }
        }
        catch {
            Write-Host "  ⚠ Service discovery test failed"
        }
    } else {
        Write-Host "⚠ Test pod failed to start, skipping DNS resolution tests"
    }
    
    # Cleanup test pod
    Write-Host ""
    Write-Host "Cleaning up test resources..."
    kubectl delete pod dns-test-pod --ignore-not-found=true 2>$null | Out-Null
    Remove-Item -Path $testPodPath -Force -ErrorAction SilentlyContinue
    
} catch {
    Write-Host "Error during final verification: $_"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "CoreDNS Deployment Summary"
Write-Host "=========================================="

# Final summary
$endTime = Get-Date
$totalDuration = $endTime - $startTime

Write-Host "Deployment completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Total deployment time: $([math]::Round($totalDuration.TotalMinutes, 2)) minutes"
Write-Host ""

# Check final status
try {
    $finalPods = kubectl get pods -l k8s-app=kube-dns -n kube-system --no-headers 2>$null
    $readyCount = 0
    $totalCount = 0
    
    if ($finalPods) {
        $totalCount = ($finalPods | Measure-Object).Count
        $readyCount = ($finalPods | Where-Object { $_ -match "(\d+)/(\d+)" -and $matches[1] -eq $matches[2] -and $_ -match "Running" }).Count
    }
    
    if ($readyCount -gt 0) {
        Write-Host "✅ CoreDNS cluster add-on deployment SUCCESSFUL"
        Write-Host "   - $readyCount/$totalCount pods are ready and running"
        Write-Host "   - DNS resolution capabilities have been added to the cluster"
        Write-Host "   - Services can now be discovered using DNS names"
        Write-Host ""
        Write-Host "Next steps:"
        Write-Host "   - Verify your applications can resolve service names"
        Write-Host "   - Monitor CoreDNS logs if you encounter DNS issues"
        Write-Host "   - Consider adjusting DNS configuration for specific use cases"
    } else {
        Write-Host "⚠ CoreDNS deployment completed with issues"
        Write-Host "   - $readyCount/$totalCount pods are ready"
        Write-Host "   - Manual verification and troubleshooting may be required"
        Write-Host ""
        Write-Host "Troubleshooting suggestions:"
        Write-Host "   - Check pod logs: kubectl logs -l k8s-app=kube-dns -n kube-system"
        Write-Host "   - Verify node resources: kubectl describe nodes"
        Write-Host "   - Check for scheduling issues: kubectl get events -n kube-system"
    }
} catch {
    Write-Host "⚠ Unable to determine final deployment status"
}

Write-Host ""
Write-Host "Deployment log saved to: $outputFile"
Write-Host "Enhanced manifest saved to: C:\repos\kthw\scripts\12\coredns-enhanced.yaml"

# Stop transcript
Stop-Transcript

Write-Host ""
Write-Host "CoreDNS deployment process completed!"
Write-Host "Check the transcript file for detailed execution logs."
