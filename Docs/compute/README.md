# Azure Virtual Machines & Private Connectivity

This section documents the deployment of Azure Linux virtual machines into the existing `HomeLab_VNet` and `Devlab_VNet` network architecture.

The implementation builds on the existing VNet peering and subnet segmentation by introducing compute resources and validating secure private communication between the management and development environments.

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
│               ├── Ubuntu 22.04 LTS
│               ├── Private IP: 10.10.0.4
│               └── Public IP
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
        │       ├── Ubuntu 22.04 LTS
        │       ├── Private IP: 10.20.1.4
        │       └── No Public IP
        │
        └── DataSubnet
```

## Administrative Access

`Prod-mgmt01` provides the administrative path to the private development workload.

```text
Administrator Mac
        │
        │ SSH
        ▼
   Prod-mgmt01
    10.10.0.4
        │
        │ SSH over VNet Peering
        ▼
    Dev-app01
     10.20.1.4
```

`Dev-app01` does not have a public IP address. Administrative access is performed through `Prod-mgmt01` using private connectivity across the existing VNet peering.

SSH agent forwarding allows the SSH identity stored on the local workstation to be used for authentication to `Dev-app01` without storing the private SSH key on the management VM.

## Documentation

### [Azure Linux VM Deployment & Private Connectivity](./azure-linux-vm-private-connectivity.md)

Detailed implementation documentation covering:

* Azure Linux VM deployment
* Network Interface Card configuration
* public and private IP addressing
* Network Security Group configuration
* SSH public/private key authentication
* SSH agent forwarding
* private VM administration
* VNet peering connectivity
* effective route validation
* Azure DNS validation
* outbound connectivity testing
* VM lifecycle operations
* troubleshooting and lessons learned

## Next Steps

The next phase will extend the development environment by deploying `Dev-data01` into `DataSubnet` and validating controlled application-to-data communication.

The infrastructure will later be rebuilt using Bicep as the environment progresses toward Infrastructure as Code.
