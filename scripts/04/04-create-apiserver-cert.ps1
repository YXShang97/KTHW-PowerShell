# Change to the certs directory first
Set-Location "C:\repos\kthw\certs"

# Retrieve the kubernetes-the-hard-way static IP address
Write-Host "Retrieving Kubernetes public IP address..."
$kubernetesPublicAddress = az network public-ip show -g kubernetes -n kubernetes-pip --query "ipAddress" -o tsv

Write-Host "Kubernetes public IP: $kubernetesPublicAddress"

# Create the Kubernetes API Server certificate signing request
$csrContent = @"
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "IT",
      "L": "Milan",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Italy"
    }
  ]
}
"@

# Write CSR file
$csrContent | Out-File -FilePath "kubernetes-csr.json" -Encoding UTF8

# Generate the Kubernetes API Server certificate and private key
$kubernetesHostnames = "kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local"
$hostname = "10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,$kubernetesPublicAddress,127.0.0.1,$kubernetesHostnames"

Write-Host "Generating Kubernetes API Server certificate..."
Write-Host "Hostname: $hostname"

cfssl gencert `
    -ca="ca.pem" `
    -ca-key="ca-key.pem" `
    -config="ca-config.json" `
    -hostname="$hostname" `
    -profile=kubernetes `
    "kubernetes-csr.json" | cfssljson -bare "kubernetes"

Write-Host "Kubernetes API Server certificate generated successfully."