#requires -Version 5.1
<#
.SYNOPSIS
    Tutorial Step 04: Provisioning a CA and Generating TLS Certificates

.DESCRIPTION
    In this lab you will provision a PKI Infrastructure using CloudFlare's PKI toolkit, cfssl,
    then use it to bootstrap a Certificate Authority, and generate TLS certificates for the 
    following components: etcd, kube-apiserver, kubelet, and kube-proxy.

.NOTES
    Tutorial Step: 04
    Tutorial Name: Provisioning a CA and Generating TLS Certificates
    Original URL: https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/04-certificate-authority.md
    
    Prerequisites:
    - cfssl and cfssljson tools installed (Tutorial Step 02)
    - Azure CLI authenticated
    - Azure infrastructure deployed (Tutorial Step 03)
#>

# Set working directory to certs folder
$certsPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\certs"
if (-not (Test-Path $certsPath)) {
    New-Item -ItemType Directory -Path $certsPath -Force | Out-Null
}
Set-Location $certsPath

# Set path to cfssl tools (local installation)
$cfsslPath = Join-Path -Path $PSScriptRoot -ChildPath "..\02\cfssl"
$cfssl = Join-Path -Path $cfsslPath -ChildPath "cfssl.exe"
$cfssljson = Join-Path -Path $cfsslPath -ChildPath "cfssljson.exe"

Write-Host "Working in: $(Get-Location)" -ForegroundColor Green

# Create the CA configuration file
Write-Host "Creating CA configuration file..." -ForegroundColor Yellow
@"
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
"@ | Out-File -FilePath "ca-config.json" -Encoding UTF8

# Create the CA certificate signing request
Write-Host "Creating CA certificate signing request..." -ForegroundColor Yellow
@"
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
"@ | Out-File -FilePath "ca-csr.json" -Encoding UTF8

# Generate the CA certificate and private key
Write-Host "Generating CA certificate and private key..." -ForegroundColor Yellow
& $cfssl gencert -initca ca-csr.json | & $cfssljson -bare ca

# Create the admin client certificate signing request
Write-Host "Creating admin client certificate..." -ForegroundColor Yellow
@"
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
"@ | Out-File -FilePath "admin-csr.json" -Encoding UTF8

# Generate the admin client certificate and private key
& $cfssl gencert -ca="ca.pem" -ca-key="ca-key.pem" -config="ca-config.json" -profile="kubernetes" "admin-csr.json" | & $cfssljson -bare admin

# Generate worker node certificates
Write-Host "Creating worker node certificates..." -ForegroundColor Yellow
$workers = @("worker-0", "worker-1")

foreach ($instance in $workers) {
    Write-Host "Processing $instance..." -ForegroundColor Cyan
    
    # Create worker CSR
    @"
{
  "CN": "system:node:$instance",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
"@ | Out-File -FilePath "$instance-csr.json" -Encoding UTF8

    # Get worker IP addresses
    $externalIP = az network public-ip show -g kubernetes -n "$instance-pip" --query ipAddress -o tsv
    $internalIP = az vm show -d -n $instance -g kubernetes --query privateIps -o tsv
    
    # Generate worker certificate
    $hostname = "$instance,$externalIP,$internalIP"
    & $cfssl gencert -ca="ca.pem" -ca-key="ca-key.pem" -config="ca-config.json" -hostname="$hostname" -profile="kubernetes" "$instance-csr.json" | & $cfssljson -bare $instance
}

# Generate the kube-controller-manager client certificate
Write-Host "Creating kube-controller-manager certificate..." -ForegroundColor Yellow
@"
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
"@ | Out-File -FilePath "kube-controller-manager-csr.json" -Encoding UTF8

& $cfssl gencert -ca="ca.pem" -ca-key="ca-key.pem" -config="ca-config.json" -profile="kubernetes" "kube-controller-manager-csr.json" | & $cfssljson -bare kube-controller-manager

# Generate the kube-proxy client certificate
Write-Host "Creating kube-proxy certificate..." -ForegroundColor Yellow
@"
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
"@ | Out-File -FilePath "kube-proxy-csr.json" -Encoding UTF8

& $cfssl gencert -ca="ca.pem" -ca-key="ca-key.pem" -config="ca-config.json" -profile="kubernetes" "kube-proxy-csr.json" | & $cfssljson -bare kube-proxy

# Generate the kube-scheduler client certificate
Write-Host "Creating kube-scheduler certificate..." -ForegroundColor Yellow
@"
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
"@ | Out-File -FilePath "kube-scheduler-csr.json" -Encoding UTF8

& $cfssl gencert -ca="ca.pem" -ca-key="ca-key.pem" -config="ca-config.json" -profile="kubernetes" "kube-scheduler-csr.json" | & $cfssljson -bare kube-scheduler

# Generate the Kubernetes API Server certificate
Write-Host "Creating Kubernetes API Server certificate..." -ForegroundColor Yellow

# Get the kubernetes public IP address
$kubernetesPublicAddress = az network public-ip show -g kubernetes -n kubernetes-pip --query "ipAddress" -o tsv

@"
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
"@ | Out-File -FilePath "kubernetes-csr.json" -Encoding UTF8

$kubernetesHostnames = "kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local"
$hostname = "10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,$kubernetesPublicAddress,127.0.0.1,$kubernetesHostnames"

& $cfssl gencert -ca="ca.pem" -ca-key="ca-key.pem" -config="ca-config.json" -hostname="$hostname" -profile="kubernetes" "kubernetes-csr.json" | & $cfssljson -bare kubernetes

# Generate the service account key pair
Write-Host "Creating service account certificate..." -ForegroundColor Yellow
@"
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
"@ | Out-File -FilePath "service-account-csr.json" -Encoding UTF8

& $cfssl gencert -ca="ca.pem" -ca-key="ca-key.pem" -config="ca-config.json" -profile="kubernetes" "service-account-csr.json" | & $cfssljson -bare service-account

# Distribute certificates to worker instances
Write-Host "Copying certificates to worker instances..." -ForegroundColor Yellow
foreach ($instance in $workers) {
    $publicIP = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    Write-Host "Copying to $instance ($publicIP)..." -ForegroundColor Cyan
    & scp -o StrictHostKeyChecking=no "ca.pem" "$instance-key.pem" "$instance.pem" "kuberoot@$publicIP`:~/"
}

# Distribute certificates to controller instances
Write-Host "Copying certificates to controller instances..." -ForegroundColor Yellow
$controllers = @("controller-0", "controller-1", "controller-2")
foreach ($instance in $controllers) {
    $publicIP = az network public-ip show -g kubernetes -n "$instance-pip" --query "ipAddress" -o tsv
    Write-Host "Copying to $instance ($publicIP)..." -ForegroundColor Cyan
    & scp -o StrictHostKeyChecking=no "ca.pem" "ca-key.pem" "kubernetes-key.pem" "kubernetes.pem" "service-account-key.pem" "service-account.pem" "kuberoot@$publicIP`:~/"
}

Write-Host "Certificate generation and distribution complete!" -ForegroundColor Green
Write-Host "Generated files:" -ForegroundColor Yellow
Get-ChildItem -Path "." -Filter "*.pem" | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor White }