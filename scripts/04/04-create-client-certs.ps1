# Change to the certs directory first
Set-Location "C:\repos\kthw\certs"

# Array of worker instances
$instances = @("worker-0", "worker-1")

foreach ($instance in $instances) {
    # Create CSR JSON content
    $csrContent = @"
{
  "CN": "system:node:$instance",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "IT",
      "L": "Milan",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Italy"
    }
  ]
}
"@

    # Write CSR file
    $csrContent | Out-File -FilePath "$instance-csr.json" -Encoding UTF8

    # Get external IP using Azure CLI
    $externalIp = az network public-ip show -g kubernetes -n "$instance-pip" --query ipAddress -o tsv

    # Get internal IP using Azure CLI
    $internalIp = az vm show -d -n $instance -g kubernetes --query privateIps -o tsv

    # Generate certificate using cfssl
    $hostname = "$instance,$externalIp,$internalIp"
    
    Write-Host "Generating certificate for $instance with hostname: $hostname"
    
    cfssl gencert `
        -ca="ca.pem" `
        -ca-key="ca-key.pem" `
        -config="ca-config.json" `
        -hostname="$hostname" `
        -profile=kubernetes `
        "$instance-csr.json" | cfssljson -bare "$instance"
}