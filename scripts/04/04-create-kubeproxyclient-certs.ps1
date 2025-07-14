# Change to the certs directory first
Set-Location "C:\repos\kthw\certs"

# Create CSR JSON content for kube-proxy
$csrContent = @"
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "IT",
      "L": "Milano",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Italy"
    }
  ]
}
"@

# Write CSR file
$csrContent | Out-File -FilePath "kube-proxy-csr.json" -Encoding UTF8

Write-Host "Generating kube-proxy client certificate..."

# Generate certificate using cfssl
cfssl gencert `
    -ca="ca.pem" `
    -ca-key="ca-key.pem" `
    -config="ca-config.json" `
    -profile=kubernetes `
    "kube-proxy-csr.json" | cfssljson -bare "kube-proxy"

Write-Host "kube-proxy client certificate generated successfully."