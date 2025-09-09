# Kubernetes the Hard Way - PowerShell Edition

[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.26.3-326ce5.svg)](https://kubernetes.io)
[![PowerShell](https://img.shields.io/badge/PowerShell-7.0+-012456.svg)](https://github.com/PowerShell/PowerShell)
[![Azure](https://img.shields.io/badge/Azure-CLI-0078d4.svg)](https://docs.microsoft.com/en-us/cli/azure/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **Learn Kubernetes by building a production cluster from scratch using PowerShell and Azure**

## 🤔 What is "Kubernetes the Hard Way"?

**Kubernetes the Hard Way** is a hands-on tutorial created by [Kelsey Hightower](https://github.com/kelseyhightower/kubernetes-the-hard-way) that teaches you to bootstrap a Kubernetes cluster **manually** instead of using automated tools. This approach helps you understand:

- **How Kubernetes really works** under the hood
- **What each component does** and how they interact
- **Where problems can occur** and how to fix them
- **Why certain design decisions** were made

## � Why Use This PowerShell Version?

This repository provides a **complete PowerShell automation** of the tutorial, specifically designed for:

- **Windows/PowerShell users** who want to learn Kubernetes
- **Azure infrastructure** deployment and management
- **Reliable execution** with comprehensive error handling and fixes
- **Step-by-step learning** with detailed documentation

### ✨ **Enhanced Features**
Built upon the original work by [terronhyde](https://github.com/terronhyde/KTHW-PowerShell) and enhanced with:
- **Fixed critical issues**: CNI encoding, RBAC permissions, service timeouts
- **Production reliability**: Comprehensive error handling and retry logic
- **Complete validation**: All 15 steps verified and working
- **Better documentation**: Step-by-step guides with troubleshooting

## � What You'll Learn

By completing this tutorial, you'll gain deep understanding of:

### **Kubernetes Architecture**
- **etcd**: Distributed key-value store that holds cluster state
- **API Server**: The front-end for the Kubernetes control plane
- **Scheduler**: Assigns pods to nodes based on resource requirements
- **Controller Manager**: Runs controllers that regulate cluster state
- **kubelet**: Agent that runs on each node and manages containers
- **kube-proxy**: Network proxy that maintains network rules

### **Security & Networking**
- **PKI Infrastructure**: Certificate authorities and mutual TLS
- **Network Policies**: How pods communicate across nodes
- **RBAC**: Role-based access control for API operations
- **Encryption**: Data protection at rest and in transit

### **Cloud Infrastructure**
- **Azure Resource Management**: VMs, networking, security groups
- **Infrastructure as Code**: Automated resource provisioning
- **Troubleshooting**: Diagnosing and fixing real-world issues

## 📁 **What's Included**

```
KTHW-PowerShell/
├── scripts/01-15/              # 15 tutorial steps with PowerShell automation  
├── certs/                      # PKI certificates (auto-generated)
├── configs/                    # Kubernetes configuration files
├── EXECUTION-SUMMARY.md        # Complete execution results
└── README.md                   # This guide
```

## 📋 **Tutorial Steps**

The tutorial is organized into 15 sequential steps that build a complete Kubernetes cluster:

| Step | What You'll Build | Time | Description |
|------|-------------------|------|-------------|
| **01** | [Prerequisites](scripts/01/) | 5 min | Install PowerShell, Azure CLI, and other required tools |
| **02** | [Client Tools](scripts/02/) | 10 min | Install kubectl and certificate generation tools |
| **03** | [Azure Infrastructure](scripts/03/) | 15 min | Create virtual machines and networking in Azure |
| **04** | [Certificates](scripts/04/) | 5 min | Generate SSL certificates for secure communication |
| **05** | [Authentication](scripts/05/) | 5 min | Create kubeconfig files for cluster access |
| **06** | [Data Encryption](scripts/06/) | 2 min | Configure encryption for data stored in etcd |
| **07** | [etcd Database](scripts/07/) | 10 min | Set up the distributed database that stores cluster state |
| **08** | [Control Plane](scripts/08/) | 15 min | Install Kubernetes API server, scheduler, and controllers |
| **09** | [Worker Nodes](scripts/09/) | 20 min | Set up nodes that will run your application containers |
| **10** | [kubectl](scripts/10/) | 5 min | Configure command-line access to your cluster |
| **11** | [Pod Networking](scripts/11/) | 10 min | Enable communication between containers across nodes |
| **12** | [DNS](scripts/12/) | 10 min | Install DNS for service discovery within the cluster |
| **13** | [Validation](scripts/13/) | 15 min | Test that everything works with comprehensive smoke tests |
| **14** | [Web Dashboard](scripts/14/) | 10 min | Install a web UI for cluster management |
| **15** | [Cleanup](scripts/15/) | 5 min | Remove all resources to avoid ongoing costs |

**⏱️ Total Time: ~2.5 hours** | **💰 Estimated Cost: $10-20**

## 🚀 **Getting Started**

### **What You Need**
- **Windows Computer** with PowerShell 7.0+ 
- **Azure Account** with an active subscription ([free account works](https://azure.microsoft.com/free/))
- **Basic PowerShell Knowledge** (ability to run scripts and read output)
- **2-3 hours** of time to complete the tutorial

### **Quick Start**

1. **Clone this repository**
   ```powershell
   git clone https://github.com/YXShang97/KTHW-PowerShell.git
   cd KTHW-PowerShell
   ```

2. **Start with Step 01**
   ```powershell
   cd scripts\01
   .\01-prerequisites.ps1
   ```

3. **Follow each step in order**
   - Each step includes detailed instructions
   - Run the PowerShell script for that step
   - Verify the results as described in the documentation
   - Move to the next step

4. **Complete with validation**
   ```powershell
   # After step 13, test your cluster
   cd scripts\13
   .\13-smoke-test.ps1
   ```

### **Cost Management**
- The tutorial creates Azure resources that cost money
- **Estimated cost: $10-20** for the complete tutorial
- **Always run the cleanup script** (Step 15) when finished to avoid ongoing charges

## � **What You'll Learn**

### **Core Kubernetes Concepts**
- **Distributed Systems**: etcd clustering, leader election, consensus
- **PKI Infrastructure**: Certificate authorities, mutual TLS, certificate rotation
- **Container Runtime**: containerd, CRI, OCI specifications
- **Network Architecture**: CNI plugins, pod networking, service mesh fundamentals
- **Control Plane Components**: API server, scheduler, controller patterns

### **DevOps & Infrastructure Skills**
- **Infrastructure as Code**: Azure resource provisioning with CLI
- **Configuration Management**: Template-based configuration deployment
- **Service Orchestration**: Multi-service startup sequencing and health checks
- **Monitoring & Debugging**: Log aggregation, troubleshooting methodologies
- **Security Best Practices**: Certificate management, RBAC, network policies

### **PowerShell Automation**
- **Advanced Scripting**: Error handling, retry logic, timeout management
- **Cross-Platform Operations**: Windows→Linux file handling, SSH automation
- **Azure Integration**: Resource management, networking, identity and access
- **Enterprise Patterns**: Logging, validation, modular architecture

## �️ **Production-Ready Features**

### **Reliability & Resilience**
```powershell
# Automatic retry with exponential backoff
Invoke-WithRetry -ScriptBlock { 
    kubectl get nodes 
} -MaxRetries 5 -DelaySeconds 10

# Comprehensive health checking
Test-ClusterHealth -IncludeNodes -IncludePods -IncludeServices
```

### **Enhanced Error Handling**
```powershell
# Graceful failure recovery
try {
    Start-EtcdCluster
    Write-Host "✅ etcd cluster started successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ etcd startup failed: $($_.Exception.Message)" -ForegroundColor Red
    Invoke-TroubleshootEtcd -AutoFix
}
```

### **Intelligent Validation**
```powershell
# Multi-layer validation suite
Test-CertificateChain -Verbose
Test-NetworkConnectivity -SourceNode "worker-0" -DestinationNode "worker-1"
Test-ServiceDiscovery -ServiceName "kubernetes"
```

## 🎯 **Real-World Scenarios Covered**

- **� Security Hardening**: RBAC configuration, certificate management, network policies
- **🚀 Scalability Planning**: Multi-node architecture, load balancing, resource allocation
- **🔧 Operational Excellence**: Monitoring, logging, troubleshooting, disaster recovery
- **☁️ Cloud Integration**: Azure-native networking, storage classes, load balancers
- **📊 Performance Optimization**: Resource tuning, scheduling policies, cluster autoscaling

## � **Cost Management**

```powershell
# Built-in cost tracking
Get-AzureResourceCost -ResourceGroup "kubernetes"

# Automatic cleanup options
.\15-cleanup.ps1                    # Interactive cleanup
.\15-cleanup.ps1 -Force            # Immediate cleanup  
.\15-cleanup.ps1 -DryRun           # See what would be deleted
.\15-cleanup.ps1 -SkipAzure        # Keep Azure resources, clean local files
```

**💰 Estimated Costs:**
- **Development**: $10-20 for complete tutorial
- **Extended Learning**: $50-100/week if left running
- **Production Planning**: Use cleanup script to avoid unexpected charges

## 🤝 **Contributing**

This project welcomes contributions! Areas for enhancement:

- **🔄 CI/CD Integration**: GitHub Actions workflows for automated testing
- **🌍 Multi-Cloud Support**: AWS and GCP adaptations
- **📊 Monitoring Stack**: Prometheus, Grafana integration
- **🔒 Advanced Security**: Service mesh, policy engines, compliance scanning

## ❓ **Frequently Asked Questions**

### **"I'm new to Kubernetes. Is this the right place to start?"**
**Yes!** This tutorial is specifically designed to teach Kubernetes fundamentals. While it's called "the hard way," the PowerShell automation makes it much more approachable than manual setup.

### **"What if I don't know PowerShell well?"**
**No problem!** The scripts are designed to be run as-is. Each step has clear instructions, and you don't need to modify the code. Basic familiarity with running commands is sufficient.

### **"How much will this cost in Azure?"**
**$10-20 total** for the complete tutorial. The resources are small and only needed for a few hours. Step 15 provides automatic cleanup to prevent ongoing charges.

### **"What if something goes wrong?"**
**You're covered!** This version includes comprehensive error handling and troubleshooting guides. Each step documents common issues and solutions.

### **"How is this different from other Kubernetes tutorials?"**
Most tutorials use automated tools (like kubeadm) that hide the details. This tutorial builds everything manually, so you understand exactly how Kubernetes works internally.

## 🔧 **What Makes This Version Special**

This PowerShell implementation builds upon excellent work by [terronhyde](https://github.com/terronhyde/KTHW-PowerShell) with additional enhancements:

### **Reliability Improvements**
- ✅ Fixed CNI configuration encoding issues that prevented worker nodes from starting
- ✅ Resolved RBAC permission problems with kubectl operations
- ✅ Enhanced timeout handling for reliable service startup
- ✅ Comprehensive error handling and automatic retry logic

### **User Experience**
- ✅ All 15 steps verified and working end-to-end  
- ✅ Clear documentation with step-by-step troubleshooting
- ✅ Automated validation and comprehensive smoke tests
- ✅ Cost-effective cleanup to prevent unexpected Azure charges

## 📞 **Need Help?**

- **📖 Step-by-Step Guides**: Each step includes detailed documentation
- **🔍 Troubleshooting**: Common issues and solutions are documented
- **📋 GitHub Issues**: Report bugs or ask questions
- **💬 Community**: Share experiences with other learners

## � **License & Acknowledgments**

**License**: MIT License - see [LICENSE](LICENSE) file for details

**Credits**:
- **Kelsey Hightower** - Original "Kubernetes the Hard Way" tutorial concept
- **Ivan Fioravanti** - Azure adaptation and infrastructure patterns  
- **PowerShell Community** - Scripting best practices and automation patterns

---

## 🎉 **Ready to Learn Kubernetes?**

**🚀 [Start with Step 01: Prerequisites](scripts/01/01-execution-output.md)**

By the end of this tutorial, you'll have:
- Built a complete Kubernetes cluster from scratch
- Understood how every component works together
- Gained practical experience with cloud infrastructure
- Developed troubleshooting skills for real-world scenarios

**⭐ Star this repository if it helps you learn Kubernetes!**

## 📄 **Credits**

- **Kelsey Hightower** - Original "Kubernetes the Hard Way" tutorial concept
- **Ivan Fioravanti** - Azure adaptation and infrastructure patterns
- **terronhyde** - Initial PowerShell implementation and automation
- **Community Contributors** - Improvements and bug fixes

---

*Tutorial for Kubernetes v1.26.3 | Requires PowerShell 7.0+ and Azure CLI*
