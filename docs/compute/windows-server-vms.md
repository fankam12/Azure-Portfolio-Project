# Windows Server 2022 VMs — Private Administration & Terraform

[← Compute Overview](./README.md) · [Azure Portfolio Home](../../README.md)

## Overview

This project extends an Azure HomeLab with two Windows Server 2022 Datacenter VMs across peered management and development VNets. The development Windows VM was deployed using Terraform, reusing existing networking resources. Administrative access was validated from a macOS workstation through an SSH tunnel via a Linux management VM, without assigning a public IP to the Windows VM.

**Validated outcomes:** Azure VM and NIC configurations; effective NSG rules; private TCP/3389 connectivity; SSH local port forwarding; successful authenticated Windows RDP desktop session; and post-test VM deallocation.

## Architecture

| Component | Management Windows VM | Development Windows VM |
|---|---|---|
| VM | `Prod-win01` | `Dev-win01` |
| Resource group | `HomeLab_RG` | `DevLab_RG` |
| Region | East US | East US |
| OS image | Windows Server 2022 Datacenter Gen2 (`2022-datacenter-g2`) | Windows Server 2022 Datacenter Gen2 (`2022-datacenter-g2`) |
| Size | `Standard_D2as_v7` | `Standard_D2as_v7` |
| VNet | `HomeLab_VNet` (`10.10.0.0/16`) | `Devlab_VNet` (`10.20.0.0/16`) |
| Subnet | `ManagementSubnet` (`10.10.0.0/24`) | `AppSubnet` (`10.20.1.0/24`) |
| Private IP | `10.10.0.5` | `10.20.1.5` (static) |
| NIC | `Prod-win01VMNic` | `Dev-win01-nic` |
| Public IP | None | None |
| Deployment evidence | Existing Azure deployment | Terraform configuration in `terraform/dev-windows-vm/` |

`Prod-mgmt01` is an Ubuntu Linux management VM at `10.10.0.4`, with a public SSH entry point restricted by the management subnet's NSG. The two VNets are peered. The existing `Dev-app01` and `Dev-data01` Linux VMs occupy the development network, with additional data-tier security restrictions documented separately.

### Validated administration path

```text
macOS workstation
  └── SSH to Prod-mgmt01 (public SSH endpoint)
        └── Prod-mgmt01 (10.10.0.4)
              └── Peered private Azure networks
                    └── Dev-win01 (10.20.1.5:3389)
                          └── Windows Server 2022 RDP desktop
```

## Terraform deployment — Dev-win01

The implementation in [`terraform/dev-windows-vm/`](../../terraform/dev-windows-vm/README.md) provisions:

- An `azurerm_windows_virtual_machine` using Windows Server 2022 Datacenter Gen2, `Standard_D2as_v7`, and `StandardSSD_LRS` OS disk.
- An `azurerm_network_interface` with static private IP `10.20.1.5` on the existing `AppSubnet`.
- An `azurerm_network_security_rule` allowing TCP/3389 from `10.10.0.4/32` to `10.20.1.5` at priority 110.

Terraform data sources reference the existing `DevLab_RG`, `Devlab_VNet`, and `AppSubnet` instead of recreating them. The Windows administrator password is supplied through a sensitive variable, not hardcoded into the published configuration.

**State management:** Active Terraform state is stored separately from the repository. Do **not** run `terraform apply` from a fresh checkout without first reconciling the existing state or configuring the correct backend; this can cause duplicate-resource errors or unintended changes.

## Network security and connectivity

The effective NSG inspection on the running `Dev-win01-nic` confirmed that `AppSubnet_NSG` applied the following inbound rules:

| Priority | Rule | Source | Destination / Port | Action |
|---|---|---|---|---|
| 100 | `Allow-SSH-ManagementSubnet` | `10.10.0.0/24` | TCP/22 | Allow |
| 110 | `Allow-RDP-ManagementSubnet` | `10.10.0.4/32` | `10.20.1.5:3389` | Allow |
| 65000 | `AllowVnetInBound` | `VirtualNetwork` | `VirtualNetwork`, all ports | Allow |
| 65001 | `AllowAzureLoadBalancerInBound` | `AzureLoadBalancer` | All ports | Allow |
| 65500 | `DenyAllInBound` | All | All | Deny |

The effective `VirtualNetwork` service tag included `10.10.0.0/16` and `10.20.0.0/16`. This supports the HomeLab's intended private VM-to-VM connectivity across the peered networks. **It also means the custom RDP rule does not exclusively restrict all internal RDP sources to `Prod-mgmt01`: other internal traffic may match the default `AllowVnetInBound` rule.** The SSH tunnel is the tested administrative access method from macOS, not an enforced requirement for every internal source. Windows Firewall, host permissions, and other subnet NSGs can impose additional restrictions.

Neither Windows VM has a public IP address. This reduces direct exposure but does not replace NSG review, guest OS controls, and authentication hardening.

### Read-only inspection commands

```bash
az network nsg rule list -g DevLab_RG --nsg-name AppSubnet_NSG --include-default --query "[?direction=='Inbound'].{Priority:priority,Rule:name,Access:access,Source:sourceAddressPrefix,Destination:destinationAddressPrefix,Port:destinationPortRange}" -o table
az network nic list-effective-nsg -g DevLab_RG -n Dev-win01-nic -o json
az network nic show -g DevLab_RG -n Dev-win01-nic --query "{Name:name,PrivateIP:ipConfigurations[0].privateIPAddress,Subnet:ipConfigurations[0].subnet.id,PublicIP:ipConfigurations[0].publicIPAddress.id}" -o json
```

**Operational note:** Azure returns `NicMustBeAttachedToRunningVmToGetEffectiveSecurityGroups` when the NIC is attached to a deallocated VM. Start the VM only when effective-rule inspection is needed, and deallocate it afterward.

## Validation — October 27, 2026

The following tests were completed using the existing Azure deployment:

| Test | Evidence | Result |
|---|---|---|
| VM inventory | `az vm list -d` returned `Prod-mgmt01` at `10.10.0.4` and `Dev-win01` at `10.20.1.5` | Passed |
| VM startup | Both VMs reported `VM running` | Passed |
| Effective NSG | Azure returned applied rules for `Dev-win01-nic`, including priority 110 RDP allow and default VNet rules | Passed |
| MacBook → Linux | SSH login to `Prod-mgmt01` succeeded | Passed |
| Linux → Windows RDP port | `nc -vz -w 5 10.20.1.5 3389` returned a successful connection | Passed |
| Local tunnel listener | `nc -vz 127.0.0.1 13389` returned a successful connection | Passed |
| Authenticated RDP | Windows App connected to the Windows Server desktop through the SSH tunnel; user confirmed active login | Passed |
| Post-test shutdown | `az vm list -d` showed both VMs `VM deallocated` | Passed |

### Reproduce the SSH tunnel

**Prerequisites:** Both VMs must be running; the management VM's SSH endpoint must be reachable from the authorized workstation; the Windows guest must accept RDP; and the administrator must have valid Windows credentials.

1. From macOS, connect to the Linux management VM (substitute the *current* public IP):

   ```bash
   ssh azureadmin@<PROD-MGMT01-PUBLIC-IP>
   ```

2. On `Prod-mgmt01`, verify the Windows RDP TCP port:

   ```bash
   nc -vz -w 5 10.20.1.5 3389
   ```

   Observed result: `Connection to 10.20.1.5 3389 port [tcp/ms-wbt-server] succeeded!`

3. In a **separate macOS terminal**, establish local SSH port forwarding:

   ```bash
   ssh -N -L 13389:10.20.1.5:3389 azureadmin@<PROD-MGMT01-PUBLIC-IP>
   ```

   The terminal remains occupied while the tunnel is active; this is expected.

4. In another macOS terminal, test the local listener:

   ```bash
   nc -vz 127.0.0.1 13389
   ```

   Observed result: `Connection to 127.0.0.1 port 13389 [tcp/*] succeeded!`

5. In **Windows App** on macOS, create an RDP connection to `127.0.0.1:13389`, with no separate RDP gateway, using the Windows VM's administrator credentials. An authenticated Windows Server desktop session was successfully established.

The `nc` checks prove TCP reachability; the successful Windows App session additionally confirms RDP authentication and interactive access. This test does not establish that every Linux VM can reach every Windows VM, or that `Prod-win01` RDP access has been validated.

## VM lifecycle and cost controls

After testing, the SSH and RDP sessions were closed and both VMs were deallocated:

```bash
az vm deallocate -g DevLab_RG -n Dev-win01
az vm deallocate -g HomeLab_RG -n Prod-mgmt01
az vm list -d --query "[?name=='Prod-mgmt01' || name=='Dev-win01'].{Name:name,PowerState:powerState}" -o table
```

Observed final state:

```text
Name         PowerState
-----------  --------------
Dev-win01    VM deallocated
Prod-mgmt01  VM deallocated
```

Deallocation stops VM compute billing, but managed disks and some networking resources may continue to incur costs.

## Troubleshooting and engineering lessons

- **Deallocated VM and effective NSGs:** Effective NIC security rules could not be retrieved until `Dev-win01` was running. This is expected Azure behavior, not an NSG misconfiguration.
- **Rule intent versus effective behavior:** A source-specific RDP allow rule coexists with Azure's default VNet allowance. Reviewing the effective NSG is necessary to understand the actual network policy.
- **Private administration:** SSH local port forwarding allowed an authenticated Windows RDP session without a public IP on the Windows VM.
- **Layered validation:** Confirm VM state, NSGs, TCP connectivity, local tunnel forwarding, and finally the RDP desktop. Each step tests a different layer.
- **Cost awareness:** Deallocate test VMs when the session is complete; do not confuse a stopped guest OS with Azure's deallocated compute state.
- **IaC safety:** Terraform configuration and Terraform state are distinct. Keep credentials and state out of public source control.

## Future exercises (not yet validated)

- RDP access and Windows administration for `Prod-win01`.
- Windows PowerShell administration, service management, event logs, and guest network diagnostics.
- Windows patch management through Azure Update Manager.
- Azure Monitor, Log Analytics, and alerting for Windows workloads.
- Azure Backup and restore validation.
- Additional cross-VM SSH and RDP access paths, with explicit security validation.

## Related documentation

- [Compute overview](./README.md)
- [Private Linux VMs](./private-linux-vms.md)
- [Windows VM Terraform project](../../terraform/dev-windows-vm/README.md)
- [Portfolio home](../../README.md)

## Security and responsible testing

This documentation describes a personal Azure HomeLab. It omits administrator passwords, SSH private keys, Terraform state, and subscription identifiers. It records only validated actions and distinguishes planned exercises from completed tests.
