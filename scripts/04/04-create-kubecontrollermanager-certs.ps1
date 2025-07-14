# Change to the certs directory first
Set-Location "C:\repos\kthw\certs"

# Create CSR JSON content for kube-controller-manager
$csrContent = @"
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "IT",
      "L": "Milan",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Italy"
    }
  ]
}
"@

# Write CSR file
$csrContent | Out-File -FilePath "kube-controller-manager-csr.json" -Encoding UTF8

Write-Host "Generating kube-controller-manager certificate..."

# Generate certificate using cfssl
cfssl gencert `
    -ca="ca.pem" `
    -ca-key="ca-key.pem" `
    -config="ca-config.json" `
    -profile=kubernetes `
    "kube-controller-manager-csr.json" | cfssljson -bare "kube-controller-manager"

Write-Host "kube-controller-manager certificate generated successfully."