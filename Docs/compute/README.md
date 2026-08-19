# Compute

This section documents the Azure compute infrastructure implemented as part of the Azure Portfolio Project.

The environment builds on the existing peered virtual network architecture by deploying Linux virtual machines into the management and development networks and validating secure private communication between workloads.

## Implementations

### [Private Linux VMs](./private-linux-vms.md)

Deployed Azure Linux virtual machines across the existing `HomeLab_VNet` and `Devlab_VNet` environments.

The implementation includes:

* Azure Linux virtual machines
* Network Interface Cards (NICs)
* private and public IP addressing
* SSH public/private key authentication
* Network Security Group rules
* private SSH administration
* SSH agent forwarding
* VNet peering connectivity
* effective route validation
* DNS and outbound connectivity testing
* VM lifecycle management
* troubleshooting and validation

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
│
│                    ⇅
│               VNet Peering
│                    ⇅
│
└── DevLab_RG
    │
    └── Devlab_VNet
        │
        ├── AppSubnet
        │   │
        │   └── Dev-app01
        │
        └── DataSubnet
```

Administrative access to the private development workload follows:

```text
Administrator
     │
     │ SSH
     ▼
Prod-mgmt01
     │
     │ Private SSH
     │ VNet Peering
     ▼
Dev-app01
```

`Dev-app01` does not require direct public administrative access. Instead, the management VM provides the administrative path into the private development environment.

The detailed implementation, validation steps, troubleshooting, and lessons learned are documented in [Private Linux VMs](./private-linux-vms.md).
