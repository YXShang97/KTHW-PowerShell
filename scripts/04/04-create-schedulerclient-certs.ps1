# Change to the certs directory first
Set-Location "C:\repos\kthw\certs"

# Create CSR JSON content for kube-scheduler
$csrContent = @"
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "IT",
      "L": "Milan",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Italy"
    }
  ]
}
"@

# Write CSR file
$csrContent | Out-File -FilePath "kube-scheduler-csr.json" -Encoding UTF8

Write-Host "Generating kube-scheduler client certificate..."

# Generate certificate using cfssl
cfssl gencert `
    -ca="ca.pem" `
    -ca-key="ca-key.pem" `
    -config="ca-config.json" `
    -profile=kubernetes `
    "kube-scheduler-csr.json" | cfssljson -bare "kube-scheduler"

Write-Host "kube-scheduler client certificate generated successfully."