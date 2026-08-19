# Azure Compute

This section documents the deployment, configuration, security, and operational management of Azure virtual machines within the Azure Cloud Portfolio environment.

The compute implementation builds on the segmented virtual network architecture established earlier in the portfolio. Virtual machines are deployed across dedicated management and development network boundaries to demonstrate secure administrative access, private workload connectivity, Azure network routing, and VM lifecycle management.

## Implementations

### Private Azure VM Management Across Peered Virtual Networks

Deploys Linux virtual machines across separate management and development virtual networks and establishes a controlled administrative path to a private-only application VM.

The implementation includes:

- Azure Linux VM deployment using Azure CLI
- Dedicated network interfaces
- Private and public IP design
- Network Security Group rules
- Virtual Network peering
- Private SSH connectivity
- SSH agent forwarding
- Linux network validation
- Azure effective route validation
- DNS and outbound connectivity testing
- VM compute quota troubleshooting
- VM lifecycle and cost management

[View implementation →](private-vm-management.md)

---

## Architecture

The compute environment currently uses a management VM as the administrative entry point for private workloads.

```text
Internet
   │
   │ SSH
   ▼
Prod-mgmt01
10.10.0.4
   │
   │ VNet Peering
   ▼
Dev-app01
10.20.1.4
Private Only
