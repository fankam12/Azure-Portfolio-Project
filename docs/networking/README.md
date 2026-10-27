# Azure Networking

## Overview

This section documents the design, deployment, and validation of Azure networking solutions implemented throughout this portfolio.

The networking environment is designed around segmentation, private connectivity, controlled traffic flow, and scalable IP address planning. Azure CLI is used to provision and validate the infrastructure, with Infrastructure as Code implementations introduced as the environment evolves.

The current architecture separates management and development workloads across dedicated Azure Virtual Networks while maintaining private connectivity through VNet peering.

---

## Current Architecture

```text
                         Azure Subscription
                                │
              ┌─────────────────┴─────────────────┐
              │                                   │
         HomeLab_RG                          DevLab_RG
              │                                   │
       HomeLab-VNet                         DevLab-VNet
       10.10.0.0/16                         10.20.0.0/16
              │                                   │
     ManagementSubnet                  ┌──────────┴──────────┐
      10.10.0.0/24                     │                     │
              │                    AppSubnet             DataSubnet
    ManagementSubnet-NSG            10.20.1.0/24         10.20.2.0/24
              │                         │                     │
              │                   AppSubnet-NSG         DataSubnet-NSG
              │                         │                     │
              └────────────── VNet Peering ──────────────────┘
```

The architecture establishes separate network boundaries for management and development resources while allowing authorized private communication between the environments.

---

## Network Architecture

| Environment | Virtual Network | Address Space  | Subnet             | Subnet Range   |
| ----------- | --------------- | -------------- | ------------------ | -------------- |
| HomeLab     | `HomeLab-VNet`  | `10.10.0.0/16` | `ManagementSubnet` | `10.10.0.0/24` |
| DevLab      | `DevLab-VNet`   | `10.20.0.0/16` | `AppSubnet`        | `10.20.1.0/24` |
| DevLab      | `DevLab-VNet`   | `10.20.0.0/16` | `DataSubnet`       | `10.20.2.0/24` |

Network Security Groups are associated with each subnet to provide workload-specific traffic controls.

Bidirectional VNet peering connects `HomeLab-VNet` and `DevLab-VNet`, allowing resources in the separate networks to communicate privately while preserving independent network boundaries.

---

## Implementations

### Secure Azure Network Architecture with VNet Peering

Designed and deployed a segmented Azure network architecture using Azure Virtual Networks, subnets, Network Security Groups, and bidirectional VNet peering.

The implementation demonstrates:

* Non-overlapping CIDR address-space planning
* Management, application, and data network segmentation
* Subnet-level Network Security Group associations
* Private connectivity between separate Azure VNets
* Bidirectional VNet peering
* Azure CLI-based infrastructure deployment
* Network configuration and peering validation

**Documentation:** [Secure VNet Peering](./secure-vnet-peering.md)

---

## Design Principles

### Segmentation

Workloads are separated based on function and security requirements rather than placing all resources within a single subnet.

### Private Connectivity

Private Azure networking is preferred for communication between workloads whenever possible.

### Controlled Traffic Flow

Network Security Groups provide traffic filtering at subnet boundaries and can be expanded with workload-specific rules as compute resources are introduced.

### Scalable Address Planning

VNet address spaces are allocated with sufficient capacity for additional subnets and future workloads without requiring immediate network redesign.

### Automation

Azure CLI is used to deploy and validate network resources. Future implementations will extend the architecture through Infrastructure as Code using Bicep and Terraform.

---

## Technologies

| Technology              | Purpose                                  |
| ----------------------- | ---------------------------------------- |
| Azure Virtual Network   | Private network boundaries               |
| Azure Subnets           | Workload segmentation                    |
| Network Security Groups | Network traffic filtering                |
| VNet Peering            | Private cross-VNet connectivity          |
| Azure CLI               | Infrastructure deployment and validation |
| CIDR / RFC1918          | Private IP address planning              |

---

## Architecture Evolution

The networking environment is designed to evolve alongside the portfolio.

```text
Network Segmentation
        │
        ▼
    VNet Peering
        │
        ▼
 Compute Integration
        │
        ▼
Application Traffic Controls
        │
        ▼
Infrastructure as Code
        │
        ▼
Monitoring & Security
        │
        ▼
Advanced Azure Architecture
```

Future implementations will build on the existing network foundation rather than treating each deployment as an isolated environment.

This allows routing, security controls, private connectivity, application communication, infrastructure automation, and platform architecture to be demonstrated progressively as the environment becomes more complex.
