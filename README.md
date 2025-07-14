# Kubernetes the Hard Way - PowerShell Edition

A complete PowerShell implementation of the **Kubernetes the Hard Way** tutorial, providing hands-on experience with setting up a Kubernetes cluster from scratch using PowerShell automation.

## 🎯 Project Overview

This repository contains a comprehensive PowerShell conversion of Kelsey Hightower's famous "Kubernetes the Hard Way" tutorial, specifically adapted for Azure infrastructure. The tutorial teaches you to bootstrap a Kubernetes cluster manually, giving you deep insight into how Kubernetes works internally.

### What You'll Learn

- **Kubernetes Architecture**: Understanding core components like etcd, API server, scheduler, and kubelet
- **Certificate Management**: Creating and managing PKI infrastructure for secure communication
- **Networking**: Configuring pod networks, service discovery, and network policies
- **PowerShell Automation**: Advanced scripting techniques for infrastructure management
- **Azure Integration**: Working with Azure CLI and cloud resources
- **Troubleshooting**: Diagnosing and resolving common Kubernetes issues

## 🚀 Getting Started

### Prerequisites

Before starting this tutorial, ensure you have:

- **Azure Subscription**: Active Azure subscription with appropriate permissions
- **PowerShell 7.0+**: Latest version of PowerShell
- **Azure CLI**: Installed and configured
- **kubectl**: Kubernetes command-line tool
- **Git**: For cloning and managing the repository
- **Administrator Access**: Required for some operations

### Quick Start

1. **Clone the repository**:
   ```powershell
   git clone https://github.com/terronhyde/KTHW-PowerShell.git
   cd KTHW-PowerShell
   ```

2. **Follow the tutorial steps** in order (01 through 15)

3. **Each step includes**:
   - PowerShell script for automation
   - Detailed execution documentation
   - Validation commands
   - Troubleshooting guides

## 📚 Tutorial Steps

| Step | Title | Description | Status |
|------|-------|-------------|---------|
| [01](scripts/01/) | [Prerequisites](scripts/01/01-execution-output.md) | Install and configure required tools | ✅ Ready |
| [02](scripts/02/) | [Client Tools](scripts/02/02-execution-output.md) | Install kubectl, cfssl, and cfssljson | ✅ Ready |
| [03](scripts/03/) | [Compute Resources](scripts/03/03-execution-output.md) | Provision Azure virtual machines and networking | ✅ Ready |
| [04](scripts/04/) | [Certificate Authority](scripts/04/04-execution-output.md) | Generate CA and TLS certificates | ✅ Ready |
| [05](scripts/05/) | [Kubernetes Configuration](scripts/05/05-execution-output.md) | Generate kubeconfig files | ✅ Ready |
| [06](scripts/06/) | [Data Encryption](scripts/06/06-execution-output.md) | Generate encryption key for etcd | ✅ Ready |
| [07](scripts/07/) | [etcd Cluster](scripts/07/07-execution-output.md) | Bootstrap etcd cluster | ✅ Ready |
| [08](scripts/08/) | [Control Plane](scripts/08/08-execution-output.md) | Bootstrap Kubernetes control plane | ✅ Ready |
| [09](scripts/09/) | [Worker Nodes](scripts/09/09-execution-output.md) | Bootstrap Kubernetes worker nodes | ✅ Ready |
| [10](scripts/10/) | [kubectl Configuration](scripts/10/10-execution-output.md) | Configure kubectl for remote access | ✅ Ready |
| [11](scripts/11/) | [Pod Network Routes](scripts/11/11-execution-output.md) | Provision pod network routes | ✅ Ready |
| [12](scripts/12/) | [DNS Add-on](scripts/12/12-execution-output.md) | Deploy DNS cluster add-on | ✅ Ready |
| [13](scripts/13/) | [Smoke Tests](scripts/13/13-execution-output.md) | Verify cluster functionality | ✅ Ready |
| [14](scripts/14/) | [Dashboard](scripts/14/14-execution-output.md) | Configure Kubernetes dashboard | ✅ Ready |
| [15](scripts/15/) | [Cleanup](scripts/15/15-execution-output.md) | Clean up all resources | ✅ Ready |

## 🛠️ Usage Instructions

### Standard Workflow

1. **Start with Prerequisites** (Step 01):
   ```powershell
   cd scripts/01
   .\01-prerequisites.ps1
   ```

2. **Follow each step sequentially**:
   ```powershell
   cd ../02
   .\02-client-tools.ps1
   # Continue through all steps...
   ```

3. **Validate each step** using the provided validation commands in the documentation

4. **Clean up resources** when complete:
   ```powershell
   cd scripts/15
   .\15-cleanup.ps1
   ```

### Advanced Usage

**Dry Run Mode** (where available):
```powershell
.\script-name.ps1 -DryRun
```

**Force Mode** (skip confirmations):
```powershell
.\script-name.ps1 -Force
```

**Quiet Mode** (minimal output):
```powershell
.\script-name.ps1 -Quiet
```

## 📖 Documentation Structure

Each step includes comprehensive documentation:

- **🎯 Overview**: What the step accomplishes
- **⚙️ Execution Instructions**: How to run the script
- **📋 Expected Output**: What you should see when successful
- **✅ Validation Steps**: Commands to verify success
- **🔧 Troubleshooting**: Common issues and solutions
- **📚 Additional Resources**: Links and references

## 🎨 Enhanced Features

This PowerShell implementation includes several enhancements over the original tutorial:

### ✨ **PowerShell Enhancements**
- **Robust Error Handling**: Comprehensive error checking and recovery
- **Progress Reporting**: Clear status updates throughout execution
- **Parameter Support**: Flexible script execution options
- **Validation Commands**: Built-in verification steps
- **Colored Output**: Enhanced readability with color-coded messages

### 🔧 **Automation Features**
- **Batch Processing**: Run multiple operations efficiently
- **Retry Logic**: Automatic retry for transient failures
- **Resource Tagging**: Consistent resource organization
- **State Management**: Track progress across script executions

### 📊 **Monitoring & Debugging**
- **Detailed Logging**: Comprehensive execution logs
- **Diagnostic Commands**: Built-in troubleshooting tools
- **Performance Metrics**: Execution time tracking
- **Resource Validation**: Automated health checks

## 🚨 Important Notes

### ⚠️ **Cost Considerations**
- This tutorial creates Azure resources that incur costs
- Run the cleanup script (Step 15) when finished
- Monitor your Azure spending during the tutorial

### 🔐 **Security Best Practices**
- Use least-privilege Azure credentials
- Rotate certificates and keys regularly
- Clean up test resources promptly
- Follow your organization's security policies

### 🌐 **Network Requirements**
- Outbound internet access required for downloading tools
- Azure CLI authentication needed
- Proper firewall configurations for cluster communication

## 🤝 Contributing

We welcome contributions to improve this tutorial! Please:

1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request with detailed description

## 📞 Support

If you encounter issues:

1. **Check the troubleshooting section** in the relevant step documentation
2. **Review Azure CLI authentication** and permissions
3. **Verify prerequisites** are properly installed
4. **Create an issue** in this repository with detailed error information

## 🙏 Acknowledgments

- **Kelsey Hightower**: Original "Kubernetes the Hard Way" tutorial
- **Ivan Fioravanti**: Azure adaptation of the tutorial
- **PowerShell Community**: Inspiration for scripting best practices

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Ready to learn Kubernetes the hard way?** Start with [Step 01: Prerequisites](scripts/01/01-execution-output.md) and begin your journey! 🚀
