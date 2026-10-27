# Compute

This section documents the Azure compute infrastructure implemented as part of the Azure Portfolio Project.

The environment builds on the existing peered virtual network architecture by deploying Linux virtual machines across the management, application, and data tiers and validating secure private communication between workloads.

## Implementations

### [Private Linux VMs](./private-linux-vms.md)

Deployed Azure Linux virtual machines across the existing `HomeLab_VNet` and development network environments.

The implementation includes:

* Azure Linux virtual machines
* Network Interface Cards (NICs)
* private and public IP addressing
* SSH public/private key authentication
* private-only application and data workloads
* Network Security Group rules
* subnet-level workload segmentation
* private SSH administration
* SSH agent forwarding
* VNet peering connectivity
* application-to-data traffic controls
* effective route validation
* effective NSG validation
* DNS and outbound connectivity testing
* VM lifecycle management
* deployment troubleshooting and resource cleanup

## Architecture

```text
Azure Subscription
│
├── HomeLab_RG
│   │
│   └── HomeLab_VNet
│       │
│       └── ManagementSubnet
│           │
│           └── Prod-mgmt01
│               │
│               ├── Private IP: 10.10.0.4
│               └── Public administrative endpoint
│
│                         ⇅
│                    VNet Peering
│                         ⇅
│
└── DevLab_RG
    │
    └── Development VNet
        │
        ├── AppSubnet
        │   │
        │   └── Dev-app01
        │       ├── Private IP: 10.20.1.4
        │       └── No Public IP
        │
        └── DataSubnet
            │
            └── Dev-data01
                ├── Private IP: 10.20.2.4
                └── No Public IP
```

Administrative access to the private development workloads follows:

```text
Administrator
     │
     │ SSH
     ▼
Prod-mgmt01
     │
     │ Private SSH
     │ VNet Peering
     ├───────────────────────┐
     ▼                       ▼
Dev-app01                Dev-data01
10.20.1.4                10.20.2.4
```

`Dev-app01` and `Dev-data01` do not require direct public administrative access.

Instead, `Prod-mgmt01` provides the controlled administrative path into the private development environment.

Application-to-data communication is further restricted through `DataSubnet_NSG`.

```text
Dev-app01
10.20.1.4
     │
     │ TCP/5432
     │ Allowed
     ▼
Dev-data01
10.20.2.4
```

Other direct application-tier traffic to the data tier, including SSH and ICMP, is explicitly blocked.

The detailed implementation, validation steps, troubleshooting, and lessons learned are documented in [Private Linux VMs](./private-linux-vms.md).
