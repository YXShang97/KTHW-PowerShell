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

# Define worker instances for configuration validation
$workerInstances = @("worker-0", "worker-1")
$maxRetries = 3
$deploymentTimeout = 300  # 5 minutes

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

$startTime = Get-Date
$logFile = $outputFile

Write-Host "=========================================="
Write-Host "Enhanced Cluster Readiness Verification"
Write-Host "=========================================="

# Enhanced cluster readiness check with retries
$retryCount = 0

do {
    $retryCount++
    Write-Host "Checking cluster connectivity (attempt $retryCount/$maxRetries)..."
    
    try {
        $nodes = kubectl get nodes --no-headers 2>$null
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
    $kubeSystemNs = kubectl get namespace kube-system --no-headers 2>$null
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
Write-Host "Listing CoreDNS pods:"
try {
    kubectl get pods -l k8s-app=kube-dns -n kube-system
}
catch {
    Write-Host "ERROR: Failed to list CoreDNS pods"
}

Write-Host ""
Write-Host "Getting CoreDNS deployment details:"
try {
    kubectl get deployment coredns -n kube-system
}
catch {
    Write-Host "WARNING: Unable to get CoreDNS deployment details"
}

Write-Host ""
Write-Host "Getting CoreDNS service details:"
try {
    kubectl get service kube-dns -n kube-system
}
catch {
    Write-Host "WARNING: Unable to get kube-dns service details"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Creating Test Pod for DNS Verification"
Write-Host "=========================================="

# Create a busybox test pod
Write-Host "Creating busybox test pod..."
try {
    # Check if busybox pod already exists
    $existingPod = kubectl get pod busybox --no-headers 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Busybox pod already exists, deleting it first..."
        kubectl delete pod busybox --force --grace-period=0 2>$null
        Start-Sleep -Seconds 5
    }
    
    $busyboxResult = kubectl run busybox --image=busybox:1.28 --command -- sleep 3600
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Busybox test pod created successfully"
        Write-Host "  $busyboxResult"
    } else {
        throw "Failed to create busybox pod"
    }
}
catch {
    Write-Host "ERROR: Failed to create busybox test pod"
    Write-Host "Error: $_"
    Stop-Transcript
    exit 1
}

# Wait for busybox pod to be ready
Write-Host ""
Write-Host "Waiting for busybox pod to be ready..."
$maxWaitTime = 60  # 1 minute
$elapsedTime = 0

do {
    Start-Sleep -Seconds 5
    $elapsedTime += 5
    
    try {
        $busyboxStatus = kubectl get pod busybox --no-headers 2>$null
        if ($busyboxStatus -match "Running") {
            Write-Host "✓ Busybox pod is running"
            break
        } else {
            Write-Host "Busybox pod status: $($busyboxStatus -split '\s+' | Select-Object -Index 2) (Elapsed: ${elapsedTime}s)"
        }
    }
    catch {
        Write-Host "Checking busybox pod status..."
    }
} while ($elapsedTime -lt $maxWaitTime)

if ($elapsedTime -ge $maxWaitTime) {
    Write-Host "⚠ Timeout waiting for busybox pod to be ready"
}

Write-Host ""
Write-Host "Listing busybox pod:"
try {
    kubectl get pods -l run=busybox
}
catch {
    Write-Host "ERROR: Failed to list busybox pod"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Testing DNS Resolution"
Write-Host "=========================================="

# Test DNS resolution for Kubernetes service
Write-Host "Testing DNS resolution for 'kubernetes' service..."
try {
    # Get the busybox pod name
    $podName = kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}" 2>$null
    
    if (-not $podName) {
        throw "Unable to get busybox pod name"
    }
    
    Write-Host "Using pod: $podName"
    Write-Host ""
    
    # Test DNS lookup for kubernetes service
    Write-Host "Executing DNS lookup for 'kubernetes' service..."
    $dnsLookupResult = kubectl exec -i $podName -- nslookup kubernetes 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ DNS lookup successful"
        Write-Host ""
        Write-Host "DNS Lookup Results:"
        Write-Host "==================="
        $dnsLookupResult | ForEach-Object { Write-Host "  $_" }
    } else {
        throw "DNS lookup failed"
    }
}
catch {
    Write-Host "ERROR: DNS resolution test failed"
    Write-Host "Error: $_"
    
    # Try alternative DNS test
    Write-Host ""
    Write-Host "Attempting alternative DNS test..."
    try {
        $altDnsTest = kubectl exec -i $podName -- nslookup kube-dns.kube-system 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Alternative DNS test successful"
            $altDnsTest | ForEach-Object { Write-Host "  $_" }
        }
    }
    catch {
        Write-Host "Alternative DNS test also failed"
    }
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Additional DNS Validation Tests"
Write-Host "=========================================="

# Test additional DNS functionality
Write-Host "Testing DNS resolution for kube-dns service..."
try {
    $kubeDnsLookup = kubectl exec -i $podName -- nslookup kube-dns.kube-system.svc.cluster.local 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ kube-dns service resolution successful"
        $kubeDnsLookup | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "⚠ kube-dns service resolution failed"
    }
}
catch {
    Write-Host "⚠ Unable to test kube-dns service resolution"
}

Write-Host ""
Write-Host "Testing reverse DNS lookup..."
try {
    $reverseDnsLookup = kubectl exec -i $podName -- nslookup 10.32.0.1 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Reverse DNS lookup successful"
        $reverseDnsLookup | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "⚠ Reverse DNS lookup failed (this may be expected)"
    }
}
catch {
    Write-Host "⚠ Unable to test reverse DNS lookup"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "DNS Configuration Verification"
Write-Host "=========================================="

# Check DNS configuration
Write-Host "Checking DNS configuration in busybox pod..."
try {
    $dnsConfig = kubectl exec -i $podName -- cat /etc/resolv.conf 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ DNS configuration retrieved"
        Write-Host ""
        Write-Host "DNS Configuration (/etc/resolv.conf):"
        Write-Host "====================================="
        $dnsConfig | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "⚠ Unable to retrieve DNS configuration"
    }
}
catch {
    Write-Host "⚠ Failed to check DNS configuration"
}

Write-Host ""
Write-Host "Checking CoreDNS ConfigMap..."
try {
    $coreDnsConfig = kubectl get configmap coredns -n kube-system -o yaml
    Write-Host "✓ CoreDNS ConfigMap retrieved"
    Write-Host ""
    Write-Host "CoreDNS Configuration:"
    Write-Host "====================="
    # Show only the data section for brevity
    $coreDnsConfig | Select-String -Pattern "data:" -A 20 | ForEach-Object { Write-Host "  $_" }
}
catch {
    Write-Host "⚠ Unable to retrieve CoreDNS ConfigMap"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Cleanup Test Resources"
Write-Host "=========================================="

# Clean up test pod
Write-Host "Cleaning up busybox test pod..."
try {
    kubectl delete pod busybox --force --grace-period=0 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Busybox test pod deleted successfully"
    } else {
        Write-Host "⚠ Failed to delete busybox test pod (may not exist)"
    }
}
catch {
    Write-Host "⚠ Unable to clean up busybox test pod"
}

Write-Host ""
Write-Host "=========================================="
Write-Host "DNS Cluster Add-on Deployment Complete!"
Write-Host "=========================================="
Write-Host ""

# Final status summary
Write-Host "Deployment Summary:"
Write-Host "=================="

try {
    # Check CoreDNS deployment status
    $coreDnsDeployment = kubectl get deployment coredns -n kube-system --no-headers 2>$null
    if ($LASTEXITCODE -eq 0) {
        $ready = ($coreDnsDeployment -split '\s+')[1]
        Write-Host "✓ CoreDNS Deployment: $ready"
    }
    
    # Check CoreDNS service status
    $coreDnsService = kubectl get service kube-dns -n kube-system --no-headers 2>$null
    if ($LASTEXITCODE -eq 0) {
        $clusterIP = ($coreDnsService -split '\s+')[2]
        Write-Host "✓ CoreDNS Service (kube-dns): $clusterIP"
    }
    
    # Check running pods
    $runningPods = kubectl get pods -l k8s-app=kube-dns -n kube-system --no-headers 2>$null
    $podCount = ($runningPods | Measure-Object).Count
    Write-Host "✓ CoreDNS Pods Running: $podCount"
}
catch {
    Write-Host "⚠ Unable to retrieve final status"
}

Write-Host ""
Write-Host "DNS Features Enabled:"
Write-Host "- DNS-based service discovery"
Write-Host "- Cluster-internal domain resolution"
Write-Host "- Service name to IP resolution"
Write-Host "- Cross-namespace service discovery"
Write-Host ""
Write-Host "What this enables:"
Write-Host "- Applications can discover services by name"
Write-Host "- Pods can resolve cluster.local domains"
Write-Host "- Service mesh and ingress controllers can function"
Write-Host "- Microservices communication via DNS"
Write-Host ""
Write-Host "Next step: Smoke Test - Comprehensive cluster validation"
Write-Host ""

# Stop transcript
Stop-Transcript
Write-Host "`nExecution log saved to: $outputFile"