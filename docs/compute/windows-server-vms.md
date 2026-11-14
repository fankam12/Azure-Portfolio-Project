# Windows Server 2022 VMs — Secure Administration & Terraform

[← Compute Overview](./README.md) · [Azure Portfolio Home](../../README.md)

## Overview

This project extends an Azure HomeLab with two Windows Server 2022 Datacenter VMs across peered management and development VNets. The development Windows VM was deployed using Terraform, reusing existing networking resources. Initial administration was validated from macOS through an SSH tunnel via a Linux management VM, with no public IP on either Windows VM. On November 14, 2026, Dev-win01 was updated to support direct Windows App RDP from an approved home public IP, while Prod-win01 remains private.

**Validated outcomes:** Azure VM and NIC configurations; effective NSG rules; private TCP/3389 connectivity; SSH local port forwarding; successful authenticated Windows RDP desktop sessions; historical post-test VM deallocation; and, on November 14, 2026, successful IP-restricted public RDP to Dev-win01.

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
| Public IP | None | `138.91.123.223` (Standard, static; added Nov 14, 2026) |
| Deployment evidence | Existing Azure deployment | Terraform configuration in `terraform/dev-windows-vm/` |

`Prod-mgmt01` is an Ubuntu Linux management VM at `10.10.0.4`, with a public SSH entry point restricted by the management subnet's NSG. The two VNets are peered. The existing `Dev-app01` and `Dev-data01` Linux VMs occupy the development network, with additional data-tier security restrictions documented separately.

### Original administration path (October 2026)

```text
macOS workstation
  └── SSH to Prod-mgmt01 (public SSH endpoint)
        └── Prod-mgmt01 (10.10.0.4)
              └── Peered private Azure networks
                    └── Dev-win01 (10.20.1.5:3389)
                          └── Windows Server 2022 RDP desktop
```

## Updated Changes — Secure RDP Access & Ease of Administration (November 14, 2026)

### Why the architecture changed

The original macOS-to-Windows workflow required an SSH tunnel through `Prod-mgmt01` and a local Windows App endpoint (`127.0.0.1:13389`). This avoided a public IP on the Windows VM, but required keeping a separate SSH session open for routine RDP. To evaluate a more convenient workflow, I tested **direct Windows App RDP** to `Dev-win01` while preserving source-IP restrictions, Network Level Authentication (NLA), and existing private networking. This is a **security/usability tradeoff**, not a claim that public RDP is as safe as private-only access.

### Changes made and engineering rationale

| Change | Why |
|---|---|
| Created `Dev-win01-PublicIP` (`138.91.123.223`), Standard SKU, static, in `DevLab_RG` | Provide a stable Windows App endpoint without an SSH tunnel; a public IPv4 address incurs charges |
| Associated the public IP with `Dev-win01-nic` IP configuration `internal` | Keep existing static private IP `10.20.1.5`, subnet, and VNet peering |
| Added `Allow-RDP-MacBook` to `AppSubnet_NSG` (priority 105) | Permit inbound TCP/3389 only from the approved home public IPv4 `69.250.140.202/32` to `10.20.1.5/32` |
| Retained `Allow-RDP-ManagementSubnet` (priority 110) | Preserve RDP access from `Prod-mgmt01` (`10.10.0.4/32`) |
| Added `Deny-RDP-NonManagement` (priority 120) | Deny other inbound TCP/3389 sources to `10.20.1.5/32`, including sources otherwise covered by Azure's default `AllowVnetInBound` |
| Scoped enabled Windows Remote Desktop inbound firewall rules to `69.250.140.202` and `10.10.0.4` | Add guest-OS filtering alongside Azure NSG controls |
| Verified RDP enabled and NLA required | Confirm remote desktop authentication prerequisites |
| Retained public SSH to `Prod-mgmt01` | Keep existing Linux management access; SSH login from the Mac was tested |

**Important:** The home public IP represents the network's internet-facing address, **not the identity of a specific MacBook**. Other devices behind the same public IP are not distinguished by the NSG source filter. If the home IP changes, both the NSG and Windows Firewall allow-lists must be updated. A public RDP endpoint remains more exposed than a private-only endpoint, even with these controls. This experiment does not yet extend public RDP to `Prod-win01`.

### Current RDP architecture

```text
MacBook (Windows App) / home public IPv4 69.250.140.202
    |
    | Internet -> TCP/3389; AppSubnet_NSG source /32 allow
    v
Dev-win01 public IP 138.91.123.223
    |
    v
Dev-win01 private IP 10.20.1.5 (AppSubnet, DevLab_VNet)
    | Windows Firewall: approved public IP + Prod-mgmt01 private IP
    | NLA required
    +--- private VNet/subnet communication subject to NSGs and host firewalls
    |
    +--- Dev-app01 10.20.1.4 (SSH/22 tested)
    +--- Prod-mgmt01 10.10.0.4 (SSH/22 tested across peering)
    +--- Prod-win01 10.10.0.5 (RDP/3389 port tested across peering)
    +--- Dev-data01 10.20.2.4 (SSH/22 intentionally denied)

MacBook -- public SSH/22 --> Prod-mgmt01 public IP 172.190.145.230
Prod-win01 remains private-only.
```

### Commands used (macOS Azure CLI; one command per line)

```bash
az network public-ip create --resource-group DevLab_RG --name Dev-win01-PublicIP --location eastus --sku Standard --allocation-method Static --version IPv4
az network nsg rule create --resource-group DevLab_RG --nsg-name AppSubnet_NSG --name Allow-RDP-MacBook --priority 105 --direction Inbound --access Allow --protocol Tcp --source-address-prefixes 69.250.140.202/32 --source-port-ranges '*' --destination-address-prefixes 10.20.1.5/32 --destination-port-ranges 3389
az network nic ip-config update --resource-group DevLab_RG --nic-name Dev-win01-nic --name internal --public-ip-address Dev-win01-PublicIP
az network watcher test-ip-flow --resource-group DevLab_RG --vm Dev-win01 --direction Inbound --protocol TCP --local 10.20.1.5:3389 --remote 69.250.140.202:50000 --output json
az network watcher test-ip-flow --resource-group DevLab_RG --vm Dev-win01 --direction Inbound --protocol TCP --local 10.20.1.5:3389 --remote 8.8.8.8:50000 --output json
az vm run-command invoke --resource-group DevLab_RG --name Dev-win01 --command-id RunPowerShellScript --scripts 'Get-NetFirewallRule -DisplayGroup "Remote Desktop" | Where-Object { $_.Enabled -eq "True" -and $_.Direction -eq "Inbound" } | Set-NetFirewallRule -RemoteAddress "69.250.140.202","10.10.0.4"' --output json
```

### Validation results

| Test | Observed result |
|---|---|
| Approved public IP `69.250.140.202` to `10.20.1.5:3389` | Network Watcher **Allow**, rule `Allow-RDP-MacBook` |
| Unapproved public IP `8.8.8.8` to `10.20.1.5:3389` | Network Watcher **Deny**, rule `Deny-RDP-NonManagement` |
| RDP and NLA | Both enabled (`True`) |
| Windows Firewall enabled Remote Desktop rules | TCP User Mode, TCP Shadow, and UDP User Mode restricted to `69.250.140.202` and `10.10.0.4` |
| Other enabled inbound TCP allow rules covering 3389 | Audit showed only scoped RDP TCP rules |
| MacBook Windows App to `138.91.123.223` | **Successful authenticated desktop connection**, without SSH tunnel |
| `Dev-win01` to `Prod-mgmt01` `10.10.0.4:22` | `TcpTestSucceeded: True` |
| `Dev-win01` to `Dev-app01` `10.20.1.4:22` | `TcpTestSucceeded: True` |
| `Dev-win01` to `Prod-win01` `10.10.0.5:3389` | `TcpTestSucceeded: True` (port reachability, not authenticated RDP) |
| `Dev-win01` to `Dev-data01` `10.20.2.4:22` | `TcpTestSucceeded: False`; Network Watcher **Deny** via `Deny-AppSubnet-Other-Inbound` — intentional segmentation |
| MacBook SSH to `Prod-mgmt01` | Successful Ubuntu shell login |

Network Watcher validates **NSG policy**, not a real end-to-end connection. `Test-NetConnection` validates TCP reachability, not service authentication. The successful Windows App and SSH sessions separately establish authenticated access.

### Operational maintenance, rollback and lessons learned

- **When the home public IPv4 changes:** update `Allow-RDP-MacBook` source address in `AppSubnet_NSG` and the enabled Windows Remote Desktop firewall rules. Verify the new source before removing the old one; keep a recovery path through Azure Run Command. Never temporarily broaden the RDP source to `*` or `0.0.0.0/0`.
- **Rollback Windows Firewall RDP source scope via Azure Run Command (if necessary):**

  ```bash
  az vm run-command invoke --resource-group DevLab_RG --name Dev-win01 --command-id RunPowerShellScript --scripts 'Get-NetFirewallRule -DisplayGroup "Remote Desktop" | Where-Object { $_.Enabled -eq "True" -and $_.Direction -eq "Inbound" } | Set-NetFirewallRule -RemoteAddress Any' --output json
  ```

  This restores the original broad **guest** RDP allow scope and should only be used temporarily for recovery; Azure NSG restrictions remain independently enforced. Reapply a narrow scope immediately.
- **Security tradeoff:** Direct public RDP removes SSH tunnel overhead but increases internet-facing attack surface. A private VPN, mesh network, or Azure Bastion would avoid direct public RDP exposure if the lab's security requirements increase.
- **Cost and lifecycle:** A Standard public IPv4 resource may continue to incur charges when the VM is deallocated. Review charges against the HomeLab budget.
- **Infrastructure as Code drift:** The VM and NIC were originally managed through Terraform; the CLI-created public IP association and NSG changes should be reconciled with the Terraform configuration/state before a future `terraform apply`. Do not apply Terraform blindly.
- **Change history:** The October 2026 SSH-tunnel implementation remains documented below as a validated earlier approach and potential fallback.

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

**Historical note:** Neither Windows VM had a public IP during the October tests. Since November 14, 2026, `Dev-win01` has a restricted public RDP endpoint; `Prod-win01` remains private. The original tunnel workflow below is retained as a tested alternative.

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

The `nc` checks prove TCP reachability; the successful Windows App session additionally confirms RDP authentication and interactive access. This test does not establish that every Linux VM can reach every Windows VM, or that every other private access path has been validated.

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

## Additional validation

Authenticated RDP access from macOS through `Prod-mgmt01` was successfully verified for **both** Windows VMs: `Dev-win01` using `127.0.0.1:13389` and `Prod-win01` using `127.0.0.1:13390`. The Mac-local TCP listeners and private TCP/3389 paths were tested. Windows PowerShell diagnostics, Windows Firewall review, and Device Guard/Event Log investigations were completed on `Dev-win01`. Azure Update Manager showed **No pending updates** for both Windows VMs, and **periodic assessment was enabled** on both. 

**Detailed evidence, commands, results and security caveats:** [Windows Server Administration & Patch Compliance](./windows-server-administration-and-patching.md).

## Future exercises (not yet validated)

- Deeper Windows administration and diagnostics on `Prod-win01` (authenticated RDP is complete).
- Scheduled patch installations, maintenance windows and reboot validation (assessment only completed so far).
- Azure Monitor, Log Analytics, and alerting for Windows workloads.
- Azure Backup and restore validation.
- Additional cross-VM SSH and RDP access paths, with explicit security validation.

## Related documentation

- [Windows Server Administration & Patch Compliance](./windows-server-administration-and-patching.md)
- [Compute overview](./README.md)
- [Private Linux VMs](./private-linux-vms.md)
- [Windows VM Terraform project](../../terraform/dev-windows-vm/README.md)
- [Portfolio home](../../README.md)
