# Tutorial Step 06: Generating the Data Encryption Config and Key - Execution Output

## Tutorial Information
- **Tutorial Step**: 06
- **Tutorial Name**: Generating the Data Encryption Config and Key
- **Original URL**: https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/06-data-encryption-keys.md
- **Script File**: `06-generate-encryption-key.ps1`

## Description
Kubernetes stores a variety of data including cluster state, application configurations, and secrets. Kubernetes supports the ability to encrypt cluster data at rest. In this lab you will generate an encryption key and an encryption config suitable for encrypting Kubernetes Secrets.

## Prerequisites
- Azure infrastructure deployed (Tutorial Step 03) with controller VMs running
- SSH access to controller instances configured
- Azure CLI authenticated and configured

## Script Execution

### Command Run
```powershell
cd scripts\06
.\06-generate-encryption-key.ps1
```

### Execution Output
```
Working in: C:\repos\kthw\certs
Generating encryption key...
✅ Generated encryption key: OFWwdh7fSPs4ARNacjXk...
Creating encryption-config.yaml file...
✅ Created encryption-config.yaml
Encryption config file contents:
  kind: EncryptionConfig
  apiVersion: v1
  resources:
    - resources:
        - secrets
      providers:
        - aescbc:
            keys:
              - name: key1
                secret: OFWwdh7fSPs4ARNacjXkm9Pr7bR+/FsgSYJ9tLT+3Vk=
        - identity: {}
Distributing encryption-config.yaml to controller instances...
Copying to controller-0 (20.55.249.60)...
encryption-config.yaml                                                                                                                                  100%  251     3.6KB/s   00:00    
✅ Copied encryption-config.yaml to controller-0
Copying to controller-1 (172.210.248.242)...
encryption-config.yaml                                                                                                                                  100%  251     3.5KB/s   00:00    
✅ Copied encryption-config.yaml to controller-1
Copying to controller-2 (20.190.196.205)...
encryption-config.yaml                                                                                                                                  100%  251     3.6KB/s   00:00    
✅ Copied encryption-config.yaml to controller-2
Encryption configuration setup complete!
Encryption key and config file have been distributed to all controller nodes.
```

## Execution Summary

### What the Script Accomplished
1. **Generated Encryption Key**: Created a cryptographically secure 32-byte random key and encoded it in base64 format
2. **Created Encryption Config**: Generated `encryption-config.yaml` file with AES-CBC encryption configuration
3. **Distributed Configuration**: Successfully copied the encryption config file to all 3 controller instances

### Key Technical Details
- **Encryption Algorithm**: AES-CBC (Advanced Encryption Standard in Cipher Block Chaining mode)
- **Key Length**: 32 bytes (256-bit encryption key)
- **Base64 Encoding**: Required format for Kubernetes encryption configuration
- **Fallback Provider**: `identity: {}` allows unencrypted data to be read during migration

### File Distribution Results
- **controller-0 (20.55.249.60)**: ✅ encryption-config.yaml copied successfully
- **controller-1 (172.210.248.242)**: ✅ encryption-config.yaml copied successfully  
- **controller-2 (20.190.196.205)**: ✅ encryption-config.yaml copied successfully

### Generated Encryption Configuration
The script created an `encryption-config.yaml` file with the following structure:
- **Kind**: EncryptionConfig (Kubernetes resource type)
- **Resources**: Targets `secrets` for encryption
- **Primary Provider**: AES-CBC with generated key named "key1"
- **Fallback Provider**: Identity provider for backwards compatibility

## Validation Steps

### 1. Verify Local Encryption Config File
```powershell
# Check that encryption-config.yaml was created locally
Get-ChildItem -Path "..\..\certs" -Filter "encryption-config.yaml" | Format-Table Name, Length, LastWriteTime

# View the contents of the encryption config file
Get-Content "..\..\certs\encryption-config.yaml"

# Verify the file format is valid YAML
$config = Get-Content "..\..\certs\encryption-config.yaml" -Raw
$yaml = ConvertFrom-Yaml $config  # Note: Requires PowerShell-Yaml module
```

**Actual Results:**
```
PS C:\repos\kthw\certs> Get-ChildItem -Filter "encryption-config.yaml" | Format-Table Name, Length, LastWriteTime

Name                   Length LastWriteTime
----                   ------ -------------
encryption-config.yaml    251 7/14/2025 11:53:42 AM

PS C:\repos\kthw\certs> Get-Content "encryption-config.yaml"
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: OFWwdh7fSPs4ARNacjXkm9Pr7bR+/FsgSYJ9tLT+3Vk=
      - identity: {}
```
✅ **Encryption config file created successfully with proper YAML structure**

### 2. Verify File Distribution on Controller Nodes
```powershell
# Check controller-0
$controller0IP = az network public-ip show -g kubernetes -n controller-0-pip --query "ipAddress" -o tsv
ssh kuberoot@$controller0IP "ls -la encryption-config.yaml"

# Check controller-1
$controller1IP = az network public-ip show -g kubernetes -n controller-1-pip --query "ipAddress" -o tsv
ssh kuberoot@$controller1IP "ls -la encryption-config.yaml"

# Check controller-2
$controller2IP = az network public-ip show -g kubernetes -n controller-2-pip --query "ipAddress" -o tsv
ssh kuberoot@$controller2IP "ls -la encryption-config.yaml"
```

**Actual Results:**
```
PS C:\repos\kthw\certs> $controller0IP = az network public-ip show -g kubernetes -n controller-0-pip --query "ipAddress" -o tsv
PS C:\repos\kthw\certs> ssh kuberoot@$controller0IP "ls -la encryption-config.yaml"
-rw-rw-r-- 1 kuberoot kuberoot 251 Jul 14 15:53 encryption-config.yaml
```
✅ **Controller-0 has encryption-config.yaml file with correct permissions (251 bytes)**

### 3. Validate Encryption Config Content on VMs
```powershell
# Verify the content matches on controller-0
$controller0IP = az network public-ip show -g kubernetes -n controller-0-pip --query "ipAddress" -o tsv
ssh kuberoot@$controller0IP "cat encryption-config.yaml"

# Check file permissions are correct
ssh kuberoot@$controller0IP "stat encryption-config.yaml"
```

### 4. Validate Encryption Key Format
```powershell
# Extract and validate the base64 key from local file
$configContent = Get-Content "..\..\certs\encryption-config.yaml" -Raw
$keyLine = ($configContent -split "`n" | Where-Object { $_ -match "secret:" }).Trim()
$base64Key = ($keyLine -split "secret: ")[1]

# Verify key is valid base64 and correct length
try {
    $keyBytes = [Convert]::FromBase64String($base64Key)
    Write-Host "✅ Key is valid base64: $($keyBytes.Length) bytes" -ForegroundColor Green
    if ($keyBytes.Length -eq 32) {
        Write-Host "✅ Key length is correct (32 bytes for AES-256)" -ForegroundColor Green
    } else {
        Write-Host "❌ Key length is incorrect: $($keyBytes.Length) bytes (expected 32)" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Key is not valid base64: $_" -ForegroundColor Red
}
```

**Actual Results:**
```
PS C:\repos\kthw\certs> $key = "OFWwdh7fSPs4ARNacjXkm9Pr7bR+/FsgSYJ9tLT+3Vk="
PS C:\repos\kthw\certs> $keyBytes = [Convert]::FromBase64String($key)
PS C:\repos\kthw\certs> Write-Host "Key length: $($keyBytes.Length) bytes"
Key length: 32 bytes
```
✅ **Encryption key is valid base64 format with correct 32-byte length for AES-256**

### 5. Test YAML Syntax Validity
```powershell
# Verify YAML syntax is valid (requires PowerShell-Yaml module)
# Install module if needed: Install-Module PowerShell-Yaml -Scope CurrentUser

try {
    $yamlContent = Get-Content "..\..\certs\encryption-config.yaml" -Raw
    $parsedYaml = ConvertFrom-Yaml $yamlContent
    Write-Host "✅ YAML syntax is valid" -ForegroundColor Green
    Write-Host "Resources configured for encryption: $($parsedYaml.resources[0].resources -join ', ')" -ForegroundColor Cyan
} catch {
    Write-Host "❌ YAML syntax error: $_" -ForegroundColor Red
}
```

## Troubleshooting

### Common Issues and Solutions

#### 1. PowerShell Cryptography Issues
**Error**: Issues with RNGCryptoServiceProvider or base64 encoding
```powershell
# Solution: Test cryptographic functions
try {
    $testBytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
    $rng.GetBytes($testBytes)
    $testBase64 = [Convert]::ToBase64String($testBytes)
    Write-Host "✅ Cryptography functions working: $($testBase64.Substring(0,20))..." -ForegroundColor Green
    $rng.Dispose()
} catch {
    Write-Host "❌ Cryptography error: $_" -ForegroundColor Red
    # Alternative using simpler random generation
    $random = New-Object System.Random
    $altBytes = 1..32 | ForEach-Object { $random.Next(0,256) }
    $altBase64 = [Convert]::ToBase64String([byte[]]$altBytes)
    Write-Host "Alternative key generated: $($altBase64.Substring(0,20))..." -ForegroundColor Yellow
}
```

#### 2. File Creation/Permission Issues
**Error**: Cannot create or write to encryption-config.yaml
```powershell
# Solution: Check directory permissions and create manually
$certsPath = "..\..\certs"
Write-Host "Checking certs directory: $certsPath"
Test-Path $certsPath

# Check write permissions
try {
    "test" | Out-File -FilePath "$certsPath\test.txt" -Encoding UTF8
    Remove-Item "$certsPath\test.txt" -ErrorAction SilentlyContinue
    Write-Host "✅ Write permissions OK" -ForegroundColor Green
} catch {
    Write-Host "❌ Write permission error: $_" -ForegroundColor Red
    Write-Host "Try running PowerShell as Administrator" -ForegroundColor Yellow
}
```

#### 3. SSH/SCP Connection Issues
**Error**: Cannot copy files to controller instances
```powershell
# Solution: Test SSH connectivity and authentication
$controllers = @("controller-0", "controller-1", "controller-2")
foreach ($controller in $controllers) {
    $ip = az network public-ip show -g kubernetes -n "$controller-pip" --query "ipAddress" -o tsv
    Write-Host "Testing SSH to $controller ($ip)..." -ForegroundColor Yellow
    
    # Test basic SSH connection
    $result = ssh kuberoot@$ip "echo 'SSH connection successful'" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ SSH to $controller successful" -ForegroundColor Green
    } else {
        Write-Host "❌ SSH to $controller failed: $result" -ForegroundColor Red
    }
}

# Verify SSH key is loaded
ssh-add -l
```

#### 4. Azure CLI Authentication Issues
**Error**: Cannot retrieve public IP addresses
```powershell
# Solution: Re-authenticate with Azure CLI
Write-Host "Checking Azure CLI authentication..." -ForegroundColor Yellow
$account = az account show 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Azure CLI authenticated" -ForegroundColor Green
} else {
    Write-Host "❌ Azure CLI not authenticated: $account" -ForegroundColor Red
    Write-Host "Run: az login" -ForegroundColor Yellow
}

# Test IP address retrieval
try {
    $testIP = az network public-ip show -g kubernetes -n controller-0-pip --query "ipAddress" -o tsv
    Write-Host "✅ Can retrieve IP addresses: $testIP" -ForegroundColor Green
} catch {
    Write-Host "❌ Cannot retrieve IP addresses: $_" -ForegroundColor Red
}
```

#### 5. Encryption Config Format Issues
**Error**: YAML format problems or invalid configuration
```powershell
# Solution: Manually verify and fix the encryption config
$sampleConfig = @"
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: YOUR_BASE64_KEY_HERE
      - identity: {}
"@

Write-Host "Sample encryption config format:" -ForegroundColor Yellow
$sampleConfig | ForEach-Object { Write-Host "  $_" -ForegroundColor White }

# Validate against Kubernetes schema (if kubectl available)
try {
    kubectl explain EncryptionConfig 2>/dev/null
    Write-Host "✅ kubectl can validate EncryptionConfig" -ForegroundColor Green
} catch {
    Write-Host "⚠️ kubectl not available for validation" -ForegroundColor Yellow
}
```

### Validation Commands Summary
```powershell
# Quick validation script
Write-Host "=== Encryption Config Validation ===" -ForegroundColor Yellow

# Check local file
if (Test-Path "..\..\certs\encryption-config.yaml") {
    $fileInfo = Get-Item "..\..\certs\encryption-config.yaml"
    Write-Host "✅ Local file exists: $($fileInfo.Length) bytes" -ForegroundColor Green
} else {
    Write-Host "❌ Local encryption-config.yaml not found" -ForegroundColor Red
}

# Check controller nodes
$controllers = @("controller-0", "controller-1", "controller-2")
foreach ($controller in $controllers) {
    try {
        $ip = az network public-ip show -g kubernetes -n "$controller-pip" --query "ipAddress" -o tsv
        $fileCheck = ssh kuberoot@$ip "ls -la encryption-config.yaml 2>/dev/null" 2>/dev/null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ $controller ($ip): encryption-config.yaml present" -ForegroundColor Green
        } else {
            Write-Host "❌ $controller ($ip): encryption-config.yaml missing" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ $controller: Cannot verify file - $_" -ForegroundColor Red
    }
}
```

## Next Steps
- **Tutorial Step 07**: Bootstrapping the etcd Cluster
- The encryption configuration will be used by the Kubernetes API servers to encrypt Secret resources at rest
- The encryption key should be kept secure and backed up appropriately

## File Locations
- **Local encryption config**: `certs/encryption-config.yaml`
- **Controller nodes**: `/home/kuberoot/encryption-config.yaml` on all 3 controllers

## Security Considerations
- **Key Security**: The generated encryption key provides 256-bit AES encryption
- **Key Distribution**: Key is distributed to all controller nodes that will run API servers
- **Backup**: Consider backing up the encryption key securely for disaster recovery
- **Rotation**: Plan for periodic key rotation following Kubernetes best practices

## Success Criteria ✅
- [x] 32-byte encryption key generated using cryptographically secure random number generator
- [x] encryption-config.yaml file created with proper YAML format
- [x] Configuration file distributed to all 3 controller instances
- [x] File transfers completed without errors
- [x] AES-CBC encryption configured with identity fallback for compatibility

---

## 🧭 Navigation

| Previous | Current | Next |
|----------|---------|------|
| [⬅️ Step 05: Kubernetes Configuration](../05/05-execution-output.md) | **Step 06: Data Encryption** | [➡️ Step 07: etcd Bootstrap](../07/07-execution-output.md) |
