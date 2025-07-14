# The Kubernetes Controller Manager leverages a key pair to generate and sign service account tokens as described in the managing service accounts documentation.

# Change to the certs directory first
Set-Location "C:\repos\kthw\certs"

# Generate the service-account certificate and private key:
# Expected Results: service-account-key.pem, service-account.pem

# Create CSR JSON content for service accounts
$csrContent = @"
{
  "CN": "service-accounts",
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
$csrContent | Out-File -FilePath "service-account-csr.json" -Encoding UTF8

Write-Host "Generating service account certificate..."

# Generate certificate using cfssl
cfssl gencert `
    -ca="ca.pem" `
    -ca-key="ca-key.pem" `
    -config="ca-config.json" `
    -profile=kubernetes `
    "service-account-csr.json" | cfssljson -bare "service-account"

Write-Host "Service account certificate generated successfully."