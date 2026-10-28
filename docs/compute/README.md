# Azure Compute Infrastructure

## Overview

This section documents the deployment, configuration, administration, and troubleshooting of Linux and Windows Server virtual machines within my Microsoft Azure HomeLab.

Building on my professional experience in enterprise infrastructure and systems administration, I use this environment to independently test Azure compute configurations, validate networking and security controls, and practice infrastructure troubleshooting scenarios.

The environment consists of five Azure virtual machines distributed across management, application, and data tiers within two peered Azure virtual networks.

The implementation emphasizes private connectivity, controlled administrative access, infrastructure lifecycle management, and repeatable deployment practices.

## Compute Implementations

| Implementation | Description | Documentation |
|---|---|---|
| Private Linux Virtual Machines | Linux VM deployment, SSH authentication, subnet segmentation, private connectivity, and troubleshooting | [View Linux VM Documentation](./private-linux-vms.md) |
| Windows Server 2022 Virtual Machines | Windows Server infrastructure across management and development environments, including private networking and VM administration | Documentation to be published |
| Windows Server Deployment with Terraform | Infrastructure-as-Code deployment of a private Windows Server 2022 VM using existing Azure networking resources | [View Terraform Project](../../terraform/dev-windows-vm/README.md) |

## Virtual Machine Inventory

The Azure HomeLab currently includes three Ubuntu Linux virtual machines and two Windows Server 2022 Datacenter virtual machines.

| Virtual Machine | Operating System | Resource Group | Private IP | Public IP Address | Purpose |
|---|---|---|---|---|---|
| `Prod-mgmt01` | Ubuntu 22.04 LTS | `HomeLab_RG` | `10.10.0.4` | Yes | Management and private administrative access |
| `Prod-win01` | Windows Server 2022 Datacenter | `HomeLab_RG` | `10.10.0.5` | No | Windows Server administration and configuration testing |
| `Dev-app01` | Ubuntu 22.04 LTS | `DevLab_RG` | `10.20.1.4` | No | Private application-tier workload |
| `Dev-win01` | Windows Server 2022 Datacenter | `DevLab_RG` | `10.20.1.5` | No | Private Windows Server workload deployed using Terraform |
| `Dev-data01` | Ubuntu 22.04 LTS | `DevLab_RG` | `10.20.2.4` | No | Private data-tier workload |

`Prod-mgmt01` is the only virtual machine configured with a public administrative endpoint. All other virtual machines use private IP addressing without directly assigned public IP addresses.

Both Windows Server virtual machines use the `Standard_D2as_v7` VM size and the `2022-datacenter-g2` Azure Marketplace image.

## Azure Compute Architecture

The compute environment uses two resource groups and two peered Azure virtual networks to separate management and development workloads.

```text
Azure HomeLab Subscription
│
├── HomeLab_RG
│   │
│   └── HomeLab_VNet (10.10.0.0/16)
│       │
│       └── ManagementSubnet (10.10.0.0/24)
│           │
│           ├── ManagementSubnet_NSG
│           │
│           ├── Prod-mgmt01 [Ubuntu 22.04 LTS]
│           │   ├── Private IP: 10.10.0.4
│           │   └── Public administrative endpoint
│           │
│           └── Prod-win01 [Windows Server 2022]
│               ├── Private IP: 10.10.0.5
│               └── No Public IP
│
│                   ⇅
│              VNet Peering
│                   ⇅
│
└── DevLab_RG
    │
    └── Devlab_VNet (10.20.0.0/16)
        │
        ├── AppSubnet (10.20.1.0/24)
        │   │
        │   ├── AppSubnet_NSG
        │   │
        │   ├── Dev-app01 [Ubuntu 22.04 LTS]
│       │   ├── Private IP: 10.20.1.4
│       │   └── No Public IP
        │   │
        │   └── Dev-win01 [Windows Server 2022]
        │       ├── Private IP: 10.20.1.5
        │       ├── No Public IP
        │       └── Terraform Deployment
        │
        └── DataSubnet (10.20.2.0/24)
            │
            ├── DataSubnet_NSG
            │
            └── Dev-data01 [Ubuntu 22.04 LTS]
                ├── Private IP: 10.20.2.4
                └── No Public IP
```

Bidirectional VNet peering enables private communication between the management and development environments.

Subnet-level Network Security Groups enforce traffic restrictions between infrastructure tiers.

## Linux Virtual Machine Infrastructure

The Linux implementation consists of three Ubuntu 22.04 LTS virtual machines.

### Management Tier

`Prod-mgmt01` provides the administrative entry point for private development workloads.

The management VM supports SSH-based administration and access to resources across the peered Azure virtual networks.

### Application Tier

`Dev-app01` is deployed into `AppSubnet` without a public IP address.

Administrative SSH access is permitted from the management environment, while subnet-level security controls restrict unnecessary inbound communication.

### Data Tier

`Dev-data01` is deployed into `DataSubnet` without a public IP address.

The data-tier network configuration permits controlled application-to-data communication on TCP port 5432 while restricting other direct application-tier traffic.

The Linux implementation includes validation of SSH authentication, effective NSG rules, effective routes, DNS resolution, private connectivity, and VM lifecycle operations.

**Detailed documentation:** [Private Linux VMs](./private-linux-vms.md)

## Windows Server 2022 Infrastructure

Two Windows Server 2022 Datacenter virtual machines extend the existing compute environment with Windows workloads.

These VMs provide a controlled environment for Windows Server administration, Azure networking validation, operating system configuration, and troubleshooting exercises.

### Production-Style Windows Server — Prod-win01

| Configuration | Value |
|---|---|
| Virtual Machine | `Prod-win01` |
| Resource Group | `HomeLab_RG` |
| Region | East US |
| Operating System | Windows Server 2022 Datacenter |
| Image SKU | `2022-datacenter-g2` |
| VM Size | `Standard_D2as_v7` |
| Virtual Network | `HomeLab_VNet` |
| Subnet | `ManagementSubnet` |
| Private IP | `10.10.0.5` |
| Public IP Address | No |
| Network Interface | `Prod-win01VMNic` |

`Prod-win01` resides within the management network alongside `Prod-mgmt01`.

The VM supports independent testing of Windows Server configurations and Azure compute administration without requiring a directly assigned public IP address.

### Development Windows Server — Dev-win01

| Configuration | Value |
|---|---|
| Virtual Machine | `Dev-win01` |
| Resource Group | `DevLab_RG` |
| Region | East US |
| Operating System | Windows Server 2022 Datacenter |
| Image SKU | `2022-datacenter-g2` |
| VM Size | `Standard_D2as_v7` |
| Virtual Network | `Devlab_VNet` |
| Subnet | `AppSubnet` |
| Private IP | `10.20.1.5` |
| Public IP Address | No |
| Network Interface | `Dev-win01-nic` |
| Deployment Method | Terraform |

`Dev-win01` was deployed using Terraform and integrated with existing Azure networking resources.

Terraform provisions the Windows Server VM, network interface, static private IP configuration, and a restricted RDP network security rule.

RDP access on TCP port 3389 is restricted to the management VM's private IP address (`10.10.0.4/32`) through `AppSubnet_NSG`.

The deployment design uses the management VM and an SSH tunnel for private RDP administration rather than exposing RDP directly to the internet.

**Terraform documentation:** [Windows Server 2022 Deployment with Terraform](../../terraform/dev-windows-vm/README.md)

## Administrative Access & Network Security

The compute architecture separates administrative connectivity from application-to-data communication.

### Linux Administration

Linux workloads use SSH authentication and private network connectivity.

`Prod-mgmt01` provides the administrative path to `Dev-app01` and `Dev-data01` across the peered virtual networks.

### Windows Administration

Both Windows Server VMs are configured without public IP addresses.

The `Dev-win01` Terraform configuration restricts inbound RDP access to the designated management VM.

Windows administrative connectivity, including RDP tunneling and operating system-level access, is documented separately from the infrastructure deployment configuration.

### Network Security Controls

The environment uses:

- Subnet-level Network Security Groups.
- Private IP addressing for development workloads.
- Bidirectional VNet peering.
- Restricted administrative access.
- Application-to-data traffic controls.
- Separation between management, application, and data tiers.

## Infrastructure Validation & Troubleshooting

The compute environment supports practical exercises in Azure infrastructure operations.

| Area | Engineering Activities |
|---|---|
| Compute | VM provisioning, configuration inspection, power-state verification, lifecycle management |
| Networking | Private IP validation, subnet placement, VNet peering connectivity |
| Security | NSG rule inspection, effective security rule analysis, restricted administrative access |
| Linux Administration | SSH authentication, agent forwarding, private SSH connectivity |
| Windows Administration | Windows Server configuration, private RDP connectivity testing, OS administration |
| Infrastructure as Code | Terraform initialization, validation, planning, and controlled deployment |
| Troubleshooting | Network connectivity investigation, deployment errors, configuration issues |
| Cost Management | VM deallocation, resource utilization review, cost-conscious lab operations |

Validation procedures and troubleshooting findings are recorded within the relevant implementation documents.

## VM Lifecycle & Cost Management

The HomeLab uses Azure VM lifecycle operations to manage compute resource utilization and operating costs.

At the time of the latest configuration review, both Windows Server VMs were in the `VM deallocated` state.

Deallocating virtual machines releases their allocated compute capacity and stops VM compute billing while retaining associated resources such as managed disks.

The environment also uses Azure budgets, tagging, and cost alerts to support responsible resource management.

## Engineering Approach

Compute implementations follow a structured workflow:

1. **Plan** — Define compute requirements, networking dependencies, security controls, and expected behavior.
2. **Deploy** — Provision infrastructure using Azure CLI, Terraform, or other appropriate tools.
3. **Validate** — Inspect deployed resources and verify network and security configurations.
4. **Troubleshoot** — Investigate deployment failures, connectivity issues, and unexpected infrastructure behavior.
5. **Document** — Record configuration decisions, validation results, troubleshooting steps, and lessons learned.
6. **Improve** — Identify opportunities to strengthen security, operational consistency, automation, and cost efficiency.

## Related Documentation

- [Private Linux Virtual Machines](./private-linux-vms.md)
- [Windows Server 2022 Terraform Deployment](../../terraform/dev-windows-vm/README.md)

## Security & Responsible Testing

This compute environment is maintained as an independent personal Azure HomeLab.

Infrastructure configurations and operational scenarios are tested using personal lab resources and representative configurations. Employer credentials, confidential information, proprietary infrastructure configurations, and production data are not used.

Sensitive configuration values, administrator credentials, and Terraform state files are excluded from version control where appropriate.
