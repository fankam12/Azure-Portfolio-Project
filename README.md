# Azure Portfolio Project — Cloud Infrastructure Automation with Azure CLI & Bicep

## About This Project

This repository documents a production-aligned Azure infrastructure project focused on cloud engineering practices, Infrastructure-as-Code automation, governance, networking, security, and operational management.

The environment demonstrates how Azure resources can be designed, deployed, secured, and managed using:

- Azure CLI for infrastructure operations and automation
- Azure Bicep for repeatable Infrastructure-as-Code deployments
- Azure Resource Manager for deployment orchestration
- Azure Portal for validation, monitoring, troubleshooting, and operational visibility

The goal of this project is to showcase enterprise-style Azure implementation patterns used by Cloud Engineers, Platform Engineers, and Azure Solutions Architects.

---

# ☁️ Cloud Engineering Focus

This project focuses on building hands-on experience with:

- Azure Infrastructure-as-Code using Bicep
- Azure CLI automation workflows
- Azure networking architecture
- Cloud security best practices
- Azure governance and policy enforcement
- Identity and access management
- Windows and Linux workload deployment
- Monitoring and operational management
- Cost optimization strategies
- Production deployment workflows

The architecture follows Microsoft Azure best practices with an emphasis on secure, scalable, and repeatable deployments.

---

# 🔍 Project Overview

The objective of this project is to build and evolve a realistic Azure environment that reflects how organizations deploy and operate cloud infrastructure.

All infrastructure deployments are performed using:

- Azure CLI commands
- Azure Bicep templates
- Git-based version control

Azure Portal is used only for:

- Deployment verification
- Resource validation
- Monitoring dashboards
- Reviewing metrics and logs
- Troubleshooting configuration issues


The environment follows a Dev/Test → Production deployment model.

Infrastructure changes are developed and validated in the testing environment before being promoted into production.

---

# 🏗️ Azure Environment Architecture

## Azure Subscription

**Subscription Name:** HomeLab

---

# Resource Groups

## HomeLab_RG

**Environment Tag:** `prod`

Purpose:

Primary production-style Azure environment used to host validated infrastructure configurations and production workloads.

Infrastructure changes are promoted into `HomeLab_RG` only after successful validation in `DevLab_RG`.

Production deployment workflow:

```
Develop Configuration
        |
        |
Deploy & Validate in DevLab_RG
        |
        |
Review Changes & Troubleshoot
        |
        |
Promote Approved Configuration
        |
        |
Deploy to HomeLab_RG
```

Planned and implemented resources:

- Production Virtual Network
- Production subnet
- Network Security Groups (NSGs)
- Windows Server virtual machine
- Linux virtual machine
- Monitoring services
- Production workloads

---

## DevLab_RG

**Environment Tag:** `testing`

Purpose:

Development and testing environment used for validating Azure CLI commands, Bicep templates, networking configurations, and infrastructure changes before production deployment.

This isolated environment prevents failed deployments or configuration changes from impacting production resources.

Planned and implemented resources:

- Development Virtual Network
- Development subnet
- Network Security Groups (NSGs)
- Windows Server virtual machine
- Linux virtual machine
- Testing workloads
- Bicep deployment validation

---

# 🌎 Azure Regions

Primary deployment region:

- East US

Secondary region (future expansion):

- East US 2

Regional governance is enforced through Azure Policy and deployment standards.

---

# 🧱 Infrastructure Architecture

The environment follows a simplified enterprise architecture model designed to demonstrate production-aligned Azure deployment practices while maintaining cost efficiency.

The architecture uses separate Azure Virtual Networks for development and production environments.

```
Azure Subscription: HomeLab

|
|
|-- DevLab_RG
|     Environment: testing
|
|     DevLab-VNet
|
|     |-- DevSubnet
|          |
|          |-- Windows Server VM
|          |-- Linux Server VM
|
|     |
|     VNet Peering
|
|
|-- HomeLab_RG
      Environment: prod

      HomeLab-VNet

      |-- ProdSubnet
           |
           |-- Windows Server VM
           |-- Linux Server VM
```

---

# 🌐 Networking Architecture

The environment uses network segmentation to separate development and production workloads.

## Virtual Networks

### Development Network

```
VNet Name:
DevLab-VNet

Address Space:
10.10.0.0/16
```

Purpose:

- Testing infrastructure deployments
- Validating Bicep templates
- Testing application workloads


### Production Network

```
VNet Name:
HomeLab-VNet

Address Space:
10.20.0.0/16
```

Purpose:

- Hosting validated workloads
- Simulating production infrastructure


---

# Subnet Design

## Development Subnet

```
Subnet Name:
DevSubnet

Address Range:
10.10.1.0/24
```

Hosts:

- Windows Server VM
- Linux Server VM


---

## Production Subnet

```
Subnet Name:
ProdSubnet

Address Range:
10.20.1.0/24
```

Hosts:

- Windows Server VM
- Linux Server VM


---

# 🔗 Network Connectivity

The development and production environments communicate using:

- Azure VNet Peering
- Private IP communication
- Network Security Group rules
- Internal DNS resolution

The goal is to simulate how enterprise environments securely connect isolated workloads.

---

# 🔐 Network Security Design

Each subnet is protected using Network Security Groups.

Security principles:

- No unrestricted inbound internet access
- Least privilege network rules
- Controlled administrative access
- Private communication between workloads


Example:

```
DevSubnet NSG

Allow:
- Administrator access
- Required internal communication

Deny:
- Unnecessary inbound traffic


ProdSubnet NSG

Allow:
- Approved application communication
- Administrative access

Deny:
- Direct public exposure
```

---

# 🖥️ Compute Architecture

The environment includes both Windows and Linux servers to simulate a mixed enterprise infrastructure environment.

Target deployment:

```
Maximum Virtual Machines: 4

Development:

- Windows Server VM
- Linux Server VM


Production:

- Windows Server VM
- Linux Server VM
```

Compute design principles:

- Cost-optimized VM sizing
- B-series virtual machines where appropriate
- VM auto-shutdown schedules
- Manual deallocation after testing
- Minimal public exposure

---

# 🧩 Identity & Domain Integration

Future enhancements include:

- Active Directory Domain Services
- Windows domain joining
- Centralized authentication
- DNS integration
- Role-based access control improvements

Domain-joined workloads will communicate using:

- Internal DNS
- Active Directory authentication
- Secure service-based access

---

# 📦 Infrastructure-as-Code Automation

## Azure CLI

Azure CLI is used for:

- Resource group creation
- Resource deployment
- Network configuration
- VM provisioning
- Resource queries
- Operational automation


Example commands:

```bash
az group create

az network vnet create

az network vnet peering create

az vm create

az deployment group create
```

---

# Azure Bicep

Bicep is used for:

- Declarative infrastructure deployment
- Modular architecture
- Repeatable environments
- Version-controlled infrastructure


Project structure:

```
bicep/

├── main.bicep

├── modules/

│   ├── networking.bicep

│   ├── compute.bicep

│   ├── security.bicep

│   └── monitoring.bicep

└── parameters/

    ├── dev.parameters.json

    └── prod.parameters.json
```
---

# 📊 Monitoring & Operations

Azure Portal provides operational visibility for:

- Azure Monitor
- Log Analytics Workspace
- Activity Logs
- Alerts
- Resource Health
- Metrics

Operational processes:

- Validate deployments
- Review resource health
- Analyze logs
- Monitor performance
- Troubleshoot issues

---

# 💰 Cost Management & FinOps

Cost governance is implemented at the Azure subscription level to provide visibility into spending across development, testing, and production-style resources.

### Current Controls

- $200 monthly subscription-level Azure Budget
- Forecasted cost alert at 50%
- Actual cost alert at 65%
- VM auto-shutdown schedules
- Manual VM deallocation when workloads are not required
- Cost-conscious VM SKU selection
- Removal of unused resources

Budget monitoring provides early visibility into unexpected cloud spending while allowing the environment to continue supporting infrastructure testing and development.

📖 [View Cost Management & Budget Alerting Documentation](https://github.com/fankam12/Azure-Portfolio-Project/blob/main/Docs/cost-management/budget-alerting.md) 


Controls implemented:

- Azure Budgets
- Cost alerts
- VM auto-shutdown schedules
- Manual VM deallocation
- Right-sized VM SKUs
- Removal of unused resources
