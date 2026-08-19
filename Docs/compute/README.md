# Azure Compute

This section documents the design, deployment, security, validation, and operational management of Azure Virtual Machines used throughout the Azure Cloud Portfolio environment.

The compute architecture builds on the segmented virtual network foundation established in the networking implementation. Virtual machines are deployed into dedicated management and application subnets with different exposure and administrative access requirements.

The implementation focuses on secure administrative access, private connectivity, SSH key-based authentication, network interface configuration, VM lifecycle management, and practical troubleshooting.

---

## Architecture

```text
                         Internet
                            │
                            │ SSH / TCP 22
                            ▼
                    ┌─────────────────┐
                    │   Prod-mgmt01   │
                    │                 │
                    │ 10.10.0.4       │
                    │ Public + Private│
                    └────────┬────────┘
                             │
                      ManagementSubnet
                       10.10.0.0/24
                             │
                       HomeLab_VNet
                       10.10.0.0/16
                             │
                        VNet Peering
                             │
                       Devlab_VNet
                       10.20.0.0/16
                             │
                        AppSubnet
                       10.20.1.0/24
                             │
                    ┌────────▼────────┐
                    │    Dev-app01    │
                    │                 │
                    │ 10.20.1.4       │
                    │ Private Only    │
                    └─────────────────┘
