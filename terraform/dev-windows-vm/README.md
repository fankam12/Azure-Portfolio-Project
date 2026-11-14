# Windows Server 2022 Deployment with Terraform

## Project Overview

This project demonstrates Infrastructure-as-Code (IaC) deployment of a Windows Server 2022 virtual machine into an existing Microsoft Azure environment using Terraform.

The deployment integrates with existing Azure networking resources while maintaining private connectivity and controlled administrative access. The original October 27, 2026 deployment used private-only RDP through an SSH tunnel; the November 14, 2026 update added direct RDP through a tightly source-restricted public IP while retaining the private management path.

The implementation demonstrates practical Azure infrastructure engineering, including VM provisioning, static private IP configuration, Network Security Group management, Terraform state considerations, and private Windows Server administration.

On October 27, 2026, SSH-tunneled RDP connectivity to the deployed Windows Server was successfully validated.

## Architecture

| Component | Configuration |
|---|---|
| Resource Group | `DevLab_RG` |
| Azure Region | East US |
| Virtual Network | `Devlab_VNet` |
| Subnet | `AppSubnet` (`10.20.1.0/24`) |
| Virtual Machine | `Dev-win01` |
| Operating System | Windows Server 2022 Datacenter |
| Image SKU | `2022-datacenter-g2` |
| VM Size | `Standard_D2as_v7` |
| Private IP | `10.20.1.5` (Static) |
| OS Disk | Standard SSD |
| Network Security Group | `AppSubnet_NSG` |
| Public IP | `Dev-win01-PublicIP` (`138.91.123.223`, static Standard SKU; added November 14) |
| Deployment Method | Terraform |
| Administrative Access | Direct Windows App RDP from approved home public IP; private management RDP through `Prod-mgmt01` retained |

### Original Administrative Connectivity — October 27, 2026 (Historical)

```text
macOS Workstation
       |
       | SSH local port forwarding
       | localhost:13389
       |
       v
Prod-mgmt01
Ubuntu Linux Management VM
Private IP: 10.10.0.4
       |
       | Azure VNet Peering
       | TCP/3389
       |
       v
Dev-win01
Windows Server 2022
Private IP: 10.20.1.5
       |
       v
Authenticated RDP Desktop
```

This was the original, successfully tested private-only architecture. It is retained for comparison; it is **not** the current public-IP configuration.

### Current Administrative Connectivity — November 14, 2026

```text
macOS Windows App
Home public IPv4: 69.250.140.202 (approved /32)
        |
        | Direct TCP/3389 to 138.91.123.223
        v
Dev-win01-PublicIP (Standard, static)
        |
        v
AppSubnet_NSG: allow approved /32 at priority 105
                 deny other RDP at priority 120
        |
        v
Dev-win01 NIC: 10.20.1.5 (static private IP)
        |
        v
Windows Firewall: Remote Desktop inbound scoped to
69.250.140.202 and 10.10.0.4; NLA required
        |
        v
Authenticated Windows Server 2022 desktop

Alternate private path: Prod-mgmt01 (10.10.0.4)
  -- VNet peering / TCP 3389 --> Dev-win01 (10.20.1.5)
```

The home address is the public IPv4 of the home network (NAT), **not** a unique identifier for a specific Mac. If the ISP changes that address, both the NSG allow rule and Windows Firewall scope must be updated. Direct public RDP increases exposure compared with private-only SSH tunneling, even with source restrictions; this lab setup is not a recommendation to expose RDP broadly.

## Terraform Resources

Terraform provisions and manages:

- Azure Windows virtual machine.
- Azure network interface with a static private IP address.
- Three custom Network Security Group rules permitting direct RDP from the approved home IP and private management RDP, while denying other inbound RDP to the VM.
- NIC association to the existing static public IP through a Terraform data source. Terraform references the public IP but does not manage its lifecycle.

Existing resource groups, virtual networks, and subnets are referenced using Terraform data sources rather than recreated.

### Infrastructure Design Decisions

- Reuse existing Azure infrastructure to avoid unnecessary resource duplication.
- Assign a static private IP address for predictable administrative connectivity.
- Originally deploy the Windows Server without a public IP address and use SSH local port forwarding from macOS (October 27).
- Later attach a static Standard SKU public IP to test more convenient direct Windows App RDP, restricted to an approved home public IPv4 (November 14).
- Retain private RDP from `Prod-mgmt01` and enforce source restrictions in both the Azure NSG and Windows Firewall.
- Supply the Windows administrator password through a sensitive Terraform variable.
- Keep active Terraform state and credentials outside the public GitHub repository.

## Network Security — Current Configuration

The Windows VM has a static public IP, but inbound RDP is restricted by both the subnet NSG and the Windows Firewall. The `AppSubnet_NSG` includes these custom TCP/3389 rules for `Dev-win01`:

| Priority | Rule | Source | Destination | Action |
|---|---|---|---|---|
| 105 | `Allow-RDP-MacBook` | `69.250.140.202/32` | `10.20.1.5/32` | Allow |
| 110 | `Allow-RDP-ManagementSubnet` | `10.10.0.4/32` | `10.20.1.5` | Allow |
| 120 | `Deny-RDP-NonManagement` | `*` | `10.20.1.5/32` | Deny |

Azure evaluates lower priority numbers first. The explicit deny at priority 120 prevents other TCP/3389 sources from relying on the default `AllowVnetInBound` rule for this destination. The management rule's destination format (`10.20.1.5` without `/32`) is deliberately preserved from the existing Terraform configuration; the final plan reported no drift.

Windows Remote Desktop requires Network Level Authentication (NLA). Enabled inbound Remote Desktop Windows Firewall rules were scoped to `69.250.140.202` and `10.10.0.4`. This is defense in depth; NSG rules alone are not the complete effective access policy.

### Original Network Security — October 27, 2026 (Historical)

The initial Windows VM had **no public IP** and was administered by SSH local port forwarding through `Prod-mgmt01`. The original priority-110 management allow rule was present, but Azure's default `AllowVnetInBound` rule could also match traffic from peered VNet address spaces (`10.10.0.0/16` and `10.20.0.0/16`). This observation motivated testing more explicit RDP controls rather than assuming a single source-specific allow rule excluded all other sources.

## Project Files

| File | Purpose |
|---|---|
| `main.tf` | Windows Server VM deployment |
| `network.tf` | Network interface, static private IP, and data-source reference to existing public IP |
| `security.tf` | Three source-specific RDP allow/deny NSG rules |
| `providers.tf` | AzureRM provider configuration |
| `variables.tf` | Sensitive administrator password input |
| `versions.tf` | Terraform and provider version requirements |
| `.terraform.lock.hcl` | Provider dependency lock file |

## Deployment Workflow

1. Authenticate to Azure and select the intended subscription.
2. Provide the Azure subscription ID through `ARM_SUBSCRIPTION_ID`.
3. Supply the administrator password securely through `TF_VAR_admin_password` or an approved secret-management solution.
4. Initialize Terraform using `terraform init`.
5. Validate the configuration using `terraform validate`.
6. Review proposed infrastructure changes using `terraform plan`.
7. Apply the configuration only after reviewing the execution plan and confirming the correct Terraform state is available.

### Terraform Commands

```bash
terraform init
```

```bash
terraform fmt -check
```

```bash
terraform validate
```

```bash
terraform plan
```

**Important:** These commands describe the deployment workflow. Do not apply the configuration from a new checkout without reconciling the existing Terraform state.

## State Management

Terraform state files are excluded from Git using `.gitignore`.

The existing deployment is managed using local Terraform state in a separate working directory. This GitHub repository contains the source configuration, not the active deployment state.

Running Terraform from a new directory without the existing state or an appropriately configured backend may result in duplicate-resource creation attempts or unintended infrastructure changes.

### Future State Management Improvements

A future improvement is to configure an Azure Storage remote backend with appropriate access controls and state locking.

This would support more consistent state management and reduce dependency on a single local working directory.

Remote state migration has not yet been implemented.

## Original Infrastructure Validation — October 27, 2026 (Historical)

The deployed Windows Server was validated using Azure CLI, Linux network diagnostics, SSH local port forwarding, and Windows App on macOS.

| Validation | Result |
|---|---|
| Windows VM provisioning | Passed |
| Static private IP assignment | Passed |
| Effective NSG inspection | Passed |
| SSH access to management VM | Passed |
| Private TCP/3389 connectivity | Passed |
| Local SSH tunnel connectivity | Passed |
| Authenticated Windows Server RDP desktop access | Passed |
| VM deallocation after testing | Passed |

### Step 1 — Verify VM Power State

```bash
az vm list -d --query "[?name=='Prod-mgmt01' || name=='Dev-win01'].{Name:name,PowerState:powerState}" -o table
```

### Step 2 — Validate Private RDP Connectivity

From the Linux management VM:

```bash
nc -vz -w 5 10.20.1.5 3389
```

Observed result:

```text
Connection to 10.20.1.5 3389 port [tcp/ms-wbt-server] succeeded!
```

### Step 3 — Establish SSH Port Forwarding

From a separate macOS terminal:

```bash
ssh -N -L 13389:10.20.1.5:3389 azureadmin@<PROD-MGMT01-PUBLIC-IP>
```

This forwards the local workstation's TCP port `13389` through the Linux management VM to the Windows Server's private RDP endpoint.

### Step 4 — Validate the Local Tunnel

```bash
nc -vz 127.0.0.1 13389
```

Observed result:

```text
Connection to 127.0.0.1 port 13389 [tcp/*] succeeded!
```

### Step 5 — Authenticate to Windows Server

Using Microsoft Windows App on macOS:

| Setting | Value |
|---|---|
| PC Name | `127.0.0.1:13389` |
| User Account | Windows Server administrator |
| Gateway | None |

The RDP connection successfully authenticated and displayed the Windows Server 2022 desktop.

This confirmed the complete administrative path from macOS through the Linux management VM to the private Windows Server.

### Step 6 — Deallocate Resources

Following validation, both virtual machines were deallocated.

```bash
az vm deallocate -g DevLab_RG -n Dev-win01
```

```bash
az vm deallocate -g HomeLab_RG -n Prod-mgmt01
```

The final Azure CLI verification confirmed:

```text
Name         PowerState
-----------  --------------
Dev-win01    VM deallocated
Prod-mgmt01  VM deallocated
```

Deallocation stops VM compute billing, although managed disks and certain other resources may continue to incur costs.

## Troubleshooting & Lessons Learned

### Effective NSG Inspection Requires a Running VM

Azure effective NSG inspection could not be completed while the Windows VM was deallocated.

The VM was started, effective rules were inspected, and the VM was deallocated again after testing.

### Custom Rules Do Not Tell the Entire Security Story

The source-specific RDP rule was validated alongside Azure's default NSG rules.

This demonstrated the importance of evaluating effective permissions rather than assuming a custom rule exclusively defines allowed traffic.

### Private Windows Administration Without a Public IP

SSH local port forwarding enabled an authenticated RDP session to a Windows Server with private-only addressing.

This provided a practical administrative workflow using existing Azure networking resources.

### Validate Connectivity in Layers

Connectivity was tested progressively:

1. Azure VM power state.
2. Network Security Group configuration.
3. Private TCP connectivity.
4. SSH tunnel availability.
5. Authenticated RDP desktop access.

This approach helps isolate network, transport, authentication, and guest OS issues.

### Cost-Conscious Infrastructure Operations

Virtual machines were deallocated after testing to minimize unnecessary compute charges.

## Key Engineering Decisions

- Reused existing Azure networking resources.
- Used a static private IP for predictable administrative connectivity.
- Originally avoided assigning a public IP and validated SSH-tunneled RDP (October 27).
- Later attached a source-restricted public IP for direct RDP while retaining the private management path (November 14).
- Evaluated effective NSG behavior and added an explicit deny rule for other RDP sources.
- Used a sensitive Terraform variable instead of hardcoding the administrator password.
- Removed the Azure subscription ID from version-controlled configuration.
- Preserved active Terraform state outside the public repository.
- Verified VM deallocation after completing the lab.

## Updated Changes — Secure Direct RDP & Terraform Reconciliation (November 14, 2026)

### Why the Change Was Made

The original SSH-tunnel approach kept RDP private but required maintaining a separate SSH forwarding session before opening Windows App on macOS. The November 14 exercise compared that approach with a more convenient direct RDP workflow while retaining narrowly scoped network access and the existing private management option.

### Azure CLI Configuration Changes

1. Created the existing Azure resource `Dev-win01-PublicIP` as a static Standard SKU IPv4 address (`138.91.123.223`).
2. Associated it with NIC `Dev-win01-nic`, IP configuration `internal`, preserving private IP `10.20.1.5`.
3. Added `Allow-RDP-MacBook` at NSG priority 105, permitting TCP/3389 only from the approved home public IPv4 `69.250.140.202/32`.
4. Preserved `Allow-RDP-ManagementSubnet` at priority 110, allowing private RDP from `Prod-mgmt01` (`10.10.0.4/32`).
5. Added `Deny-RDP-NonManagement` at priority 120, denying other inbound TCP/3389 traffic to `10.20.1.5/32`.
6. Confirmed Windows RDP was enabled with NLA required; restricted enabled inbound Remote Desktop firewall rules to the home public IPv4 and management VM.

### Validation Results

| Test | Observed result |
|---|---|
| Network Watcher IP flow, approved home source to TCP/3389 | Allowed by `Allow-RDP-MacBook` |
| Network Watcher IP flow, unapproved source `8.8.8.8` to TCP/3389 | Denied by `Deny-RDP-NonManagement` |
| Windows App from macOS directly to `138.91.123.223` | Successful authenticated RDP session, no SSH tunnel |
| `Dev-win01` to `Prod-mgmt01` TCP/22 | Successful |
| `Dev-win01` to `Dev-app01` TCP/22 | Successful |
| `Dev-win01` to `Prod-win01` TCP/3389 | Successful |
| `Dev-win01` to `Dev-data01` TCP/22 | Blocked by existing subnet segmentation, as intended |
| Mac SSH to `Prod-mgmt01` | Successful |

The connectivity checks confirm the observed paths at test time; they are not a claim that every network path or port is permitted.

### Reconcile Azure CLI Changes with Terraform

The public IP and two new NSG rules were initially created outside Terraform. To avoid drift and duplicate-rule creation:

- Updated `network.tf` to use `data "azurerm_public_ip" "dev_win01_public_ip"` and set the NIC's `public_ip_address_id`. The public IP itself remains externally managed.
- Updated `security.tf` to declare the existing home allow and other-source deny rules, preserving the existing management allow rule.
- Ran `terraform validate` successfully.
- Imported both existing NSG rules into **local Terraform state** using `terraform import` and their Azure resource IDs; importing did not create or change Azure resources.
- Reviewed the first `terraform plan`: `0 to add, 2 to change, 0 to destroy`, with only removal of two existing NSG descriptions proposed.
- Added those exact descriptions to `security.tf` and reran `terraform plan`, which reported **`No changes. Your infrastructure matches the configuration.`**
- Did **not** run `terraform apply`, because no infrastructure changes were required.
- Committed and pushed `network.tf` and `security.tf` to `main` in commit [`eb8e050`](https://github.com/fankam12/Azure-Portfolio-Project/commit/eb8e050).

**State boundary:** Terraform state, state backups, and administrator secrets remain outside the public repository. The GitHub checkout is source control, not a substitute for the existing local state. Do not run `terraform apply` from a fresh clone without first configuring the correct backend or reconciling state.

### Operational Tradeoffs & Rollback

Direct RDP removes the SSH-tunnel setup step but exposes a public RDP endpoint to the approved home network. NSG restrictions, NLA, and Windows Firewall source scoping reduce exposure; the original private SSH-tunnel workflow remains a useful alternative. The public IP may incur charges even when the VM is deallocated.

If direct RDP is no longer needed, remove the NIC public IP association through a reviewed infrastructure change and remove the home-source RDP exception. Confirm the private management path before making access-control changes. Do not delete the public IP or NSG rules blindly while they are still referenced by Terraform or operational workflows.

## Future Improvements

- Introduce Azure Storage remote Terraform state with appropriate access controls.
- Replace environment-specific values, particularly the approved home public IPv4, with reusable Terraform variables and a controlled update procedure.
- Add automated Terraform formatting, validation, and security checks.
- Integrate Azure Monitor, patch management, and backup policies.
- Expand infrastructure deployment through reusable Terraform modules.
- Perform Windows Server PowerShell administration and guest OS troubleshooting exercises.

## Related Documentation

- [Azure Compute Infrastructure](../../docs/compute/README.md)
- [Windows Server 2022 VMs — Private Administration & Terraform](../../docs/compute/windows-server-vms.md)
- [Private Linux Virtual Machines](../../docs/compute/private-linux-vms.md)
- [Azure Portfolio Home](../../README.md)

## Security & Responsible Testing

This project uses personal Azure HomeLab infrastructure for independent learning and validation.

Administrator credentials, SSH private keys, Azure subscription identifiers, and active Terraform state are excluded from the published documentation. The approved home public IPv4 is currently recorded in version-controlled configuration for this lab; it is not a per-device identity.

The repository distinguishes validated deployment outcomes from future planned improvements.
