# Change to the certs directory first
Set-Location "C:\repos\kthw\certs"

# Use relative paths
cfssl gencert `
  -ca="ca.pem" `
  -ca-key="ca-key.pem" `
  -config="ca-config.json" `
  -profile=kubernetes `
  "admin-csr.json" | cfssljson -bare "admin"