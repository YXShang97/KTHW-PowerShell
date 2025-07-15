#requires -Version 5.1

<#
.SYNOPSIS
Comprehensive troubleshooting script for Kubernetes the Hard Way

.DESCRIPTION
Diagnostic and repair script addressing common issues encountered during tutorial execution.
Based on lessons learned from resolving etcd, containerd, cgroups, and networking problems.

.NOTES
Author: KTHW PowerShell Tutorial
Version: 2.0
Date: July 15, 2025
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("etcd", "containerd", "cgroups", "networking", "all")]
    [string]$Component = "all",
    
    [switch]$AutoFix,
    [switch]$Verbose
)

# Import common functions
. "$PSScriptRoot\..\common\Common-Functions.ps1"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Kubernetes Troubleshooting & Repair Tool" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

#region etcd Troubleshooting

function Repair-EtcdCluster {
    Write-Host "Diagnosing etcd cluster issues..." -ForegroundColor Yellow
    
    $controllers = @("controller-0", "controller-1", "controller-2")
    
    foreach ($controller in $controllers) {
        try {
            $ip = Get-VmPublicIP -ResourceGroup "kubernetes" -VmName $controller
            Write-Host "  Checking etcd on $controller ($ip)..." -ForegroundColor Cyan
            
            # Check etcd service status
            $status = Invoke-RemoteCommand -VmIP $ip -Command "sudo systemctl is-active etcd" -Description "Checking etcd service status"
            
            if ($status -ne "active") {
                Write-Host "    ⚠️ etcd service not active: $status" -ForegroundColor Yellow
                
                if ($AutoFix) {
                    Write-Host "    🔧 Attempting to restart etcd service..." -ForegroundColor Yellow
                    Invoke-RemoteCommand -VmIP $ip -Command "sudo systemctl restart etcd" -Description "Restarting etcd service"
                    Start-Sleep -Seconds 10
                    
                    $newStatus = Invoke-RemoteCommand -VmIP $ip -Command "sudo systemctl is-active etcd" -Description "Checking etcd service status after restart"
                    if ($newStatus -eq "active") {
                        Write-Host "    ✅ etcd service restarted successfully" -ForegroundColor Green
                    } else {
                        Write-Host "    ❌ etcd service restart failed" -ForegroundColor Red
                        
                        # Show service logs for diagnosis
                        $logs = Invoke-RemoteCommand -VmIP $ip -Command "sudo journalctl -u etcd --no-pager -l" -Description "Getting etcd service logs"
                        Write-Host "    📋 Recent etcd logs:" -ForegroundColor Cyan
                        Write-Host $logs -ForegroundColor Gray
                    }
                }
                else {
                    Write-Host "    💡 Run with -AutoFix to attempt automatic repair" -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "    ✅ etcd service is active" -ForegroundColor Green
            }
            
            # Check etcd cluster membership
            try {
                $members = Invoke-RemoteCommand -VmIP $ip -Command "sudo ETCDCTL_API=3 etcdctl member list --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem" -Description "Checking etcd cluster membership"
                
                $memberCount = ($members -split "`n" | Where-Object { $_ -match "started" }).Count
                Write-Host "    📋 etcd cluster members: $memberCount active" -ForegroundColor Cyan
                
                if ($memberCount -lt 3) {
                    Write-Host "    ⚠️ etcd cluster has fewer than 3 members" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "    ❌ Could not check etcd cluster membership: $_" -ForegroundColor Red
            }
            
        }
        catch {
            Write-Host "    ❌ Failed to diagnose etcd on $controller: $_" -ForegroundColor Red
        }
    }
}

#endregion

#region containerd Troubleshooting

function Repair-ContainerdServices {
    Write-Host "Diagnosing containerd issues..." -ForegroundColor Yellow
    
    $workers = @("worker-0", "worker-1")
    
    foreach ($worker in $workers) {
        try {
            $ip = Get-VmPublicIP -ResourceGroup "kubernetes" -VmName $worker
            Write-Host "  Checking containerd on $worker ($ip)..." -ForegroundColor Cyan
            
            # Check containerd service status
            $status = Invoke-RemoteCommand -VmIP $ip -Command "sudo systemctl is-active containerd" -Description "Checking containerd service status"
            
            if ($status -ne "active") {
                Write-Host "    ⚠️ containerd service not active: $status" -ForegroundColor Yellow
                
                if ($AutoFix) {
                    Write-Host "    🔧 Attempting to restart containerd service..." -ForegroundColor Yellow
                    Invoke-RemoteCommand -VmIP $ip -Command "sudo systemctl restart containerd" -Description "Restarting containerd service"
                    Start-Sleep -Seconds 5
                    
                    $newStatus = Invoke-RemoteCommand -VmIP $ip -Command "sudo systemctl is-active containerd" -Description "Checking containerd status after restart"
                    if ($newStatus -eq "active") {
                        Write-Host "    ✅ containerd service restarted successfully" -ForegroundColor Green
                    }
                }
            }
            else {
                Write-Host "    ✅ containerd service is active" -ForegroundColor Green
            }
            
            # Check container runtime
            try {
                $containers = Invoke-RemoteCommand -VmIP $ip -Command "sudo crictl ps 2>/dev/null || echo 'No containers'" -Description "Checking running containers"
                Write-Host "    📋 Running containers: $containers" -ForegroundColor Cyan
            }
            catch {
                Write-Host "    ⚠️ Could not list containers" -ForegroundColor Yellow
            }
            
        }
        catch {
            Write-Host "    ❌ Failed to diagnose containerd on $worker: $_" -ForegroundColor Red
        }
    }
}

#endregion

#region cgroups Troubleshooting

function Repair-CgroupsConfiguration {
    Write-Host "Diagnosing cgroups v2 compatibility issues..." -ForegroundColor Yellow
    
    $workers = @("worker-0", "worker-1")
    
    foreach ($worker in $workers) {
        try {
            $ip = Get-VmPublicIP -ResourceGroup "kubernetes" -VmName $worker
            Write-Host "  Checking cgroups configuration on $worker ($ip)..." -ForegroundColor Cyan
            
            # Check cgroup version
            $cgroupVersion = Invoke-RemoteCommand -VmIP $ip -Command "mount | grep cgroup" -Description "Checking cgroup version"
            
            if ($cgroupVersion -match "cgroup2") {
                Write-Host "    📋 System is using cgroups v2" -ForegroundColor Cyan
                
                # Check containerd configuration for systemd cgroups
                $containerdConfig = Invoke-RemoteCommand -VmIP $ip -Command "sudo grep -i systemdcgroup /etc/containerd/config.toml 2>/dev/null || echo 'SystemdCgroup not found'" -Description "Checking containerd cgroup configuration"
                
                if ($containerdConfig -match "SystemdCgroup.*true") {
                    Write-Host "    ✅ containerd configured for systemd cgroups" -ForegroundColor Green
                } else {
                    Write-Host "    ⚠️ containerd not configured for systemd cgroups" -ForegroundColor Yellow
                    
                    if ($AutoFix) {
                        Write-Host "    🔧 Fixing containerd cgroup configuration..." -ForegroundColor Yellow
                        
                        # Generate default containerd config and enable SystemdCgroup
                        Invoke-RemoteCommand -VmIP $ip -Command "sudo containerd config default | sudo tee /etc/containerd/config.toml" -Description "Generating default containerd config"
                        Invoke-RemoteCommand -VmIP $ip -Command "sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml" -Description "Enabling SystemdCgroup in containerd"
                        
                        # Restart containerd
                        Invoke-RemoteCommand -VmIP $ip -Command "sudo systemctl restart containerd" -Description "Restarting containerd"
                        Write-Host "    ✅ containerd cgroup configuration fixed" -ForegroundColor Green
                    }
                }
                
                # Check kubelet configuration for systemd cgroups
                $kubeletConfig = Invoke-RemoteCommand -VmIP $ip -Command "sudo grep -i cgroupdriver /var/lib/kubelet/kubelet-config.yaml 2>/dev/null || echo 'cgroupDriver not found'" -Description "Checking kubelet cgroup configuration"
                
                if ($kubeletConfig -match "cgroupDriver.*systemd") {
                    Write-Host "    ✅ kubelet configured for systemd cgroups" -ForegroundColor Green
                } else {
                    Write-Host "    ⚠️ kubelet not configured for systemd cgroups" -ForegroundColor Yellow
                    
                    if ($AutoFix) {
                        Write-Host "    🔧 Fixing kubelet cgroup configuration..." -ForegroundColor Yellow
                        Invoke-RemoteCommand -VmIP $ip -Command "echo 'cgroupDriver: systemd' | sudo tee -a /var/lib/kubelet/kubelet-config.yaml" -Description "Adding systemd cgroup driver to kubelet config"
                        Invoke-RemoteCommand -VmIP $ip -Command "sudo systemctl restart kubelet" -Description "Restarting kubelet"
                        Write-Host "    ✅ kubelet cgroup configuration fixed" -ForegroundColor Green
                    }
                }
            } else {
                Write-Host "    📋 System is using cgroups v1" -ForegroundColor Cyan
            }
            
        }
        catch {
            Write-Host "    ❌ Failed to diagnose cgroups on $worker: $_" -ForegroundColor Red
        }
    }
}

#endregion

#region Networking Troubleshooting

function Repair-NetworkingConfiguration {
    Write-Host "Diagnosing networking configuration..." -ForegroundColor Yellow
    
    try {
        # Check Azure networking resources
        Write-Host "  Checking Azure networking resources..." -ForegroundColor Cyan
        
        $vnet = az network vnet show -g kubernetes -n kubernetes-vnet --query "name" -o tsv 2>$null
        if ($vnet -eq "kubernetes-vnet") {
            Write-Host "    ✅ Virtual network exists" -ForegroundColor Green
        } else {
            Write-Host "    ❌ Virtual network not found" -ForegroundColor Red
        }
        
        $routes = az network route-table show -g kubernetes -n kubernetes-routes --query "name" -o tsv 2>$null
        if ($routes -eq "kubernetes-routes") {
            Write-Host "    ✅ Route table exists" -ForegroundColor Green
            
            # Check route entries
            $routeEntries = az network route-table route list -g kubernetes --route-table-name kubernetes-routes --query "length([*])" -o tsv 2>$null
            Write-Host "    📋 Route entries: $routeEntries" -ForegroundColor Cyan
        } else {
            Write-Host "    ❌ Route table not found" -ForegroundColor Red
        }
        
        # Check pod networking on workers
        $workers = @("worker-0", "worker-1")
        foreach ($worker in $workers) {
            try {
                $ip = Get-VmPublicIP -ResourceGroup "kubernetes" -VmName $worker
                Write-Host "  Checking pod networking on $worker ($ip)..." -ForegroundColor Cyan
                
                # Check CNI configuration
                $cniConfig = Invoke-RemoteCommand -VmIP $ip -Command "sudo ls -la /etc/cni/net.d/ 2>/dev/null || echo 'No CNI config'" -Description "Checking CNI configuration"
                if ($cniConfig -match ".conf") {
                    Write-Host "    ✅ CNI configuration exists" -ForegroundColor Green
                } else {
                    Write-Host "    ⚠️ CNI configuration missing or incomplete" -ForegroundColor Yellow
                }
                
                # Check network interfaces
                $interfaces = Invoke-RemoteCommand -VmIP $ip -Command "ip link show | grep -E 'cni|bridge'" -Description "Checking network interfaces"
                if (![string]::IsNullOrEmpty($interfaces)) {
                    Write-Host "    📋 Network interfaces: $interfaces" -ForegroundColor Cyan
                } else {
                    Write-Host "    ⚠️ No CNI network interfaces found" -ForegroundColor Yellow
                }
                
            }
            catch {
                Write-Host "    ❌ Failed to check networking on $worker: $_" -ForegroundColor Red
            }
        }
        
    }
    catch {
        Write-Host "  ❌ Failed to diagnose networking: $_" -ForegroundColor Red
    }
}

#endregion

#region DNS Troubleshooting

function Repair-DNSConfiguration {
    Write-Host "Diagnosing DNS configuration..." -ForegroundColor Yellow
    
    try {
        # Check CoreDNS pods
        $corednsPods = kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>$null
        if ($LASTEXITCODE -eq 0) {
            $runningPods = ($corednsPods -split "`n" | Where-Object { $_ -match "Running" }).Count
            $totalPods = ($corednsPods -split "`n" | Where-Object { $_ -ne "" }).Count
            
            Write-Host "  📋 CoreDNS pods: $runningPods/$totalPods running" -ForegroundColor Cyan
            
            if ($runningPods -eq 0 -and $AutoFix) {
                Write-Host "  🔧 Attempting to restart CoreDNS pods..." -ForegroundColor Yellow
                kubectl delete pods -n kube-system -l k8s-app=kube-dns 2>$null
                Start-Sleep -Seconds 30
                
                $newPods = kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>$null
                $newRunning = ($newPods -split "`n" | Where-Object { $_ -match "Running" }).Count
                if ($newRunning -gt 0) {
                    Write-Host "  ✅ CoreDNS pods restarted successfully" -ForegroundColor Green
                }
            }
        } else {
            Write-Host "  ❌ Cannot check CoreDNS pods (cluster may not be accessible)" -ForegroundColor Red
        }
        
        # Test DNS resolution
        $testPod = kubectl run dns-test --image=busybox --restart=Never --rm -it --command -- nslookup kubernetes.default 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ DNS resolution test passed" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️ DNS resolution test failed" -ForegroundColor Yellow
        }
        
    }
    catch {
        Write-Host "  ❌ Failed to diagnose DNS: $_" -ForegroundColor Red
    }
}

#endregion

#region Main Execution

Write-Host "Component to diagnose: $Component" -ForegroundColor Cyan
if ($AutoFix) {
    Write-Host "Auto-fix mode: ENABLED" -ForegroundColor Yellow
    Write-Host "⚠️ This will attempt to automatically repair issues" -ForegroundColor Yellow
} else {
    Write-Host "Auto-fix mode: DISABLED (diagnostic only)" -ForegroundColor Cyan
    Write-Host "💡 Use -AutoFix parameter to enable automatic repairs" -ForegroundColor Yellow
}
Write-Host ""

switch ($Component.ToLower()) {
    "etcd" { Repair-EtcdCluster }
    "containerd" { Repair-ContainerdServices }
    "cgroups" { Repair-CgroupsConfiguration }
    "networking" { Repair-NetworkingConfiguration }
    "dns" { Repair-DNSConfiguration }
    "all" {
        Repair-EtcdCluster
        Write-Host ""
        Repair-ContainerdServices
        Write-Host ""
        Repair-CgroupsConfiguration
        Write-Host ""
        Repair-NetworkingConfiguration
        Write-Host ""
        Repair-DNSConfiguration
    }
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Troubleshooting Complete" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

if (-not $AutoFix) {
    Write-Host ""
    Write-Host "💡 To attempt automatic repairs, run:" -ForegroundColor Yellow
    Write-Host "   .\Repair-Cluster.ps1 -Component $Component -AutoFix" -ForegroundColor White
}

#endregion
