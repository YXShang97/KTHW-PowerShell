# Tutorial Step 02: Installing the Client Tools - Execution Output

## Overview
**Tutorial Step:** 02  
**Tutorial Name:** Installing the Client Tools  
**Original URL:** [kubernetes-the-hard-way-on-azure/docs/02-client-tools.md](https://github.com/ivanfioravanti/kubernetes-the-hard-way-on-azure/blob/master/docs/02-client-tools.md)  
**Script File:** `02-client-tools.ps1`  
**Description:** Install command line utilities required for this tutorial: cfssl, cfssljson, and kubectl

## Prerequisites
- **PowerShell:** Version 5.1 or higher
- **Administrator Privileges:** Required for Chocolatey installation
- **Internet Connection:** Required for downloading tools
- **Windows:** 64-bit version (amd64 architecture)

## Script Execution Process

### Step 1: Tool Directory Creation
The script creates a `cfssl` directory in the current working location to organize the downloaded tools:
```powershell
$toolsPath = "$PWD\cfssl"
New-Item -ItemType Directory -Path $toolsPath -Force
```

**What this achieves:**
- Creates a dedicated directory for cfssl tools
- Keeps the workspace organized
- Prevents cluttering the main directory

### Step 2: cfssl Tools Download
Downloads the CloudFlare SSL tools required for certificate generation:

```powershell
# Download cfssl
Invoke-WebRequest -Uri "https://github.com/cloudflare/cfssl/releases/download/v1.6.3/cfssl_1.6.3_windows_amd64.exe" -OutFile "cfssl.exe"

# Download cfssljson
Invoke-WebRequest -Uri "https://github.com/cloudflare/cfssl/releases/download/v1.6.3/cfssljson_1.6.3_windows_amd64.exe" -OutFile "cfssljson.exe"
```

**What this achieves:**
- Downloads cfssl v1.6.3 for Windows AMD64
- Downloads cfssljson v1.6.3 for JSON processing
- Places executables in the cfssl directory

### Step 3: Chocolatey Installation Check
Checks if Chocolatey package manager is installed, and installs it if missing:

```powershell
$chocoInstalled = Get-Command choco -ErrorAction SilentlyContinue
if (-not $chocoInstalled) {
    # Install Chocolatey
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}
```

**What this achieves:**
- Verifies Chocolatey availability
- Automatically installs Chocolatey if missing
- Sets up package management for kubectl installation

### Step 4: kubectl Installation
Installs kubectl using Chocolatey package manager:

```powershell
choco install kubernetes-cli -y
```

**What this achieves:**
- Installs the latest stable kubectl version
- Adds kubectl to system PATH automatically
- Handles dependencies and configuration

## Manual Validation Steps

After running the script, validate the installation using these PowerShell commands:

### 1. Verify cfssl Installation
```powershell
# Navigate to the cfssl directory
cd .\cfssl

# Check cfssl version
.\cfssl.exe version
```

**Expected Output:**
```
Version: 1.6.3
Runtime: go1.19.2
```

### 2. Verify cfssljson Installation
```powershell
# Check cfssljson version
.\cfssljson.exe -version
```

**Expected Output:**
```
Version: 1.6.3
Runtime: go1.19.2
```

### 3. Verify kubectl Installation
```powershell
# Check kubectl version (client only)
kubectl version --client -o yaml
```

**Expected Output:**
```yaml
clientVersion:
  buildDate: "2023-03-15T13:33:11Z"
  compiler: gc
  gitCommit: 9e644106593f3f4aa98f8a84b23db5fa378900bd
  gitTreeState: clean
  gitVersion: v1.26.3
  goVersion: go1.19.2
  major: "1"
  minor: "26"
  platform: windows/amd64
kustomizeVersion: v4.5.7
```

### 4. Quick kubectl Version Check
```powershell
# Get just the version number
kubectl version --client --short
```

**Expected Output:**
```
Client Version: v1.26.3
```

### 5. Verify Tool Accessibility
```powershell
# Check if tools are in PATH
Get-Command kubectl
Get-Command choco

# Check cfssl tools location
Get-ChildItem .\cfssl\*.exe
```

## Troubleshooting Guide

### Issue 1: cfssl Download Fails
**Symptoms:** Download fails with network or SSL errors

**Solutions:**
```powershell
# Method 1: Use TLS 1.2 explicitly
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri "https://github.com/cloudflare/cfssl/releases/download/v1.6.3/cfssl_1.6.3_windows_amd64.exe" -OutFile "cfssl.exe"

# Method 2: Manual download
# Visit: https://github.com/cloudflare/cfssl/releases/tag/v1.6.3
# Download manually and place in cfssl directory
```

### Issue 2: Chocolatey Installation Fails
**Symptoms:** PowerShell execution policy errors or permission issues

**Solutions:**
```powershell
# Method 1: Run as Administrator
# Right-click PowerShell -> "Run as Administrator"

# Method 2: Set execution policy temporarily
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Method 3: Manual Chocolatey installation
# Visit: https://chocolatey.org/install
# Follow manual installation steps
```

### Issue 3: kubectl Not Found After Installation
**Symptoms:** "kubectl is not recognized" error

**Solutions:**
```powershell
# Method 1: Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Method 2: Restart PowerShell session
# Close and reopen PowerShell

# Method 3: Check Chocolatey installation
choco list --local-only

# Method 4: Manual kubectl installation
# Download from: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/
```

### Issue 4: Permission Denied Errors
**Symptoms:** Access denied when downloading or installing

**Solutions:**
```powershell
# Method 1: Run PowerShell as Administrator
# Right-click PowerShell icon -> "Run as Administrator"

# Method 2: Check and modify execution policy
Get-ExecutionPolicy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Method 3: Use different download location
# Download to user profile directory instead
```

### Issue 5: cfssl Tools Not Working
**Symptoms:** "cfssl is not recognized" or runtime errors

**Solutions:**
```powershell
# Method 1: Add cfssl directory to PATH temporarily
$env:Path += ";$PWD\cfssl"

# Method 2: Use full path to executables
.\cfssl\cfssl.exe version

# Method 3: Copy tools to a PATH directory
Copy-Item .\cfssl\*.exe -Destination "C:\Windows\System32"

# Method 4: Verify file integrity
Get-FileHash .\cfssl\cfssl.exe -Algorithm SHA256
```

## Alternative Installation Methods

### Alternative 1: Manual Downloads
If automated downloads fail, download manually:

1. **cfssl**: https://github.com/cloudflare/cfssl/releases/tag/v1.6.3
   - Download: `cfssl_1.6.3_windows_amd64.exe`
   - Rename to: `cfssl.exe`

2. **cfssljson**: Same release page
   - Download: `cfssljson_1.6.3_windows_amd64.exe`  
   - Rename to: `cfssljson.exe`

3. **kubectl**: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/

### Alternative 2: Using winget (Windows 11/10)
```powershell
# Install kubectl using winget
winget install -e --id Kubernetes.kubectl

# Check available versions
winget search kubectl
```

### Alternative 3: Using scoop
```powershell
# Install scoop package manager
Set-ExecutionPolicy RemoteSigned -scope CurrentUser
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')

# Install tools via scoop
scoop install kubectl
```

## Verification Checklist

Use this checklist to ensure successful installation:

- [ ] cfssl directory created successfully
- [ ] cfssl.exe downloaded and functional
- [ ] cfssljson.exe downloaded and functional  
- [ ] Chocolatey installed and accessible
- [ ] kubectl installed via Chocolatey
- [ ] kubectl responds to version commands
- [ ] All tools show expected version numbers
- [ ] No error messages during execution

## Expected File Structure

After successful execution, your directory structure should look like:

```
kthw/
├── cfssl/
│   ├── cfssl.exe           # CloudFlare SSL tool
│   └── cfssljson.exe       # JSON processing tool
└── scripts/
    └── 02/
        ├── 02-client-tools.ps1
        └── 02-execution-output.md
```

## Next Steps

Once all tools are successfully installed and verified:

1. **Proceed to Tutorial Step 03:** Provisioning Compute Resources
2. **Keep cfssl tools accessible:** You'll need them for certificate generation in later steps
3. **Verify kubectl connectivity:** Once you have a cluster, test kubectl connectivity

## Summary

This step successfully installs the three essential tools required for the Kubernetes the Hard Way tutorial:

- **cfssl**: For generating SSL certificates and certificate authorities
- **cfssljson**: For processing certificate JSON output  
- **kubectl**: For interacting with Kubernetes clusters

All tools are now ready for use in subsequent tutorial steps. The cfssl tools are available in the local `cfssl` directory, while kubectl is installed system-wide via Chocolatey.
