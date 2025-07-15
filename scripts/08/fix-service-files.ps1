# Fix systemd service files with proper line endings
$controllers = @("controller-0", "controller-1", "controller-2")

function Get-ControllerPublicIP($controllerName) {
    return az network public-ip show -g kubernetes -n "$controllerName-pip" --query "ipAddress" -o tsv
}

function Get-ControllerInternalIP($controllerName) {
    $index = [int]$controllerName.Split('-')[1]
    return "10.240.0.$((10 + $index))"
}

$etcdEndpoints = "https://10.240.0.10:2379,https://10.240.0.11:2379,https://10.240.0.12:2379"

foreach ($controller in $controllers) {
    $publicIP = Get-ControllerPublicIP $controller
    $internalIP = Get-ControllerInternalIP $controller
    Write-Host "Fixing service files on $controller ($internalIP)..." -ForegroundColor Yellow
    
    # Stop services first
    ssh kuberoot@$publicIP 'sudo systemctl stop kube-apiserver kube-controller-manager kube-scheduler'
    
    # Create fixed API Server service (without backslashes)
    ssh kuberoot@$publicIP @"
cat > /tmp/kube-apiserver.service << 'EOF'
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver --advertise-address=$internalIP --allow-privileged=true --audit-log-maxage=30 --audit-log-maxbackup=3 --audit-log-maxsize=100 --audit-log-path=/var/log/audit.log --authorization-mode=Node,RBAC --bind-address=0.0.0.0 --client-ca-file=/var/lib/kubernetes/ca.pem --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota --etcd-cafile=/var/lib/kubernetes/ca.pem --etcd-certfile=/var/lib/kubernetes/kubernetes.pem --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem --etcd-servers=$etcdEndpoints --event-ttl=1h --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem --runtime-config=api/all=true --service-account-key-file=/var/lib/kubernetes/service-account.pem --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem --service-account-issuer=https://$internalIP:6443 --service-cluster-ip-range=10.32.0.0/24 --service-node-port-range=30000-32767 --tls-cert-file=/var/lib/kubernetes/kubernetes.pem --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
"@
    
    # Create fixed Controller Manager service (without backslashes)
    ssh kuberoot@$publicIP @"
cat > /tmp/kube-controller-manager.service << 'EOF'
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager --bind-address=0.0.0.0 --cluster-cidr=10.200.0.0/16 --cluster-name=kubernetes --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig --leader-elect=true --root-ca-file=/var/lib/kubernetes/ca.pem --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem --service-cluster-ip-range=10.32.0.0/24 --use-service-account-credentials=true --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
"@

    # Create fixed Scheduler service (without backslashes)
    ssh kuberoot@$publicIP @"
cat > /tmp/kube-scheduler.service << 'EOF'
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler --config=/etc/kubernetes/config/kube-scheduler.yaml --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
"@
    
    # Install the fixed service files
    ssh kuberoot@$publicIP 'sudo mv /tmp/kube-*.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler && sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler'
    
    Write-Host "✅ Fixed service files on $controller" -ForegroundColor Green
}

Write-Host ""
Write-Host "Waiting for services to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 20

# Check status on all controllers
foreach ($controller in $controllers) {
    $publicIP = Get-ControllerPublicIP $controller
    $status = ssh kuberoot@$publicIP "sudo systemctl is-active kube-apiserver kube-controller-manager kube-scheduler"
    $activeCount = ($status -split "`n" | Where-Object { $_ -eq "active" }).Count
    
    if ($activeCount -eq 3) {
        Write-Host "✅ ${controller}: All services active" -ForegroundColor Green
    } else {
        Write-Host "⚠️ ${controller}: $activeCount/3 services active" -ForegroundColor Yellow
    }
}
