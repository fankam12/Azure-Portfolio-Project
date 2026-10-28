# Windows Server 2022 Deployment with Terraform

## Project Overview

This project demonstrates Infrastructure-as-Code (IaC) deployment of a Windows Server 2022 virtual machine into an existing Microsoft Azure environment using Terraform.

The deployment integrates with existing Azure networking resources while maintaining private connectivity and controlled administrative access.

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
| Public IP | None |
| Deployment Method | Terraform |
| Administrative Access | SSH-tunneled RDP through `Prod-mgmt01` |

### Administrative Connectivity

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

This architecture enables remote administration of a private Windows Server without assigning a public IP address to the Windows VM.

## Terraform Resources

Terraform provisions and manages:

- Azure Windows virtual machine.
- Azure network interface with a static private IP address.
- Custom Network Security Group rule permitting RDP from the designated management VM.

Existing resource groups, virtual networks, and subnets are referenced using Terraform data sources rather than recreated.

### Infrastructure Design Decisions

- Reuse existing Azure infrastructure to avoid unnecessary resource duplication.
- Assign a static private IP address for predictable administrative connectivity.
- Deploy the Windows Server without a public IP address.
- Configure a source-specific RDP allow rule.
- Use SSH local port forwarding for administration from macOS.
- Supply the Windows administrator password through a sensitive Terraform variable.
- Keep active Terraform state and credentials outside the public GitHub repository.

## Network Security

The Windows VM does not have a public IP address.

The Terraform configuration creates a custom inbound rule in `AppSubnet_NSG` with the following configuration:

| Setting | Value |
|---|---|
| Rule Name | `Allow-RDP-ManagementSubnet` |
| Priority | `110` |
| Direction | Inbound |
| Protocol | TCP |
| Source | `10.10.0.4/32` |
| Destination | `10.20.1.5` |
| Destination Port | `3389` |
| Action | Allow |

### Effective NSG Behavior

The custom rule explicitly permits RDP traffic from the management VM.

However, the effective NSG also contains Azure's default `AllowVnetInBound` rule, which permits traffic matching the `VirtualNetwork` service tag.

During validation, the effective `VirtualNetwork` tag included both peered VNet address spaces:

- `10.10.0.0/16` — Management network.
- `10.20.0.0/16` — Development network.

Consequently, the custom RDP rule does not exclusively restrict all internal RDP traffic to `10.10.0.4/32`. Other internal sources may also match the default allow rule.

This behavior is important when evaluating effective security controls. Network Security Group permissions are determined by rule priority, matching criteria, and the complete effective rule set—not solely by an individual custom rule.

The validated administration method uses SSH tunneling through the management VM rather than exposing RDP directly to the internet.

## Project Files

| File | Purpose |
|---|---|
| `main.tf` | Windows Server VM deployment |
| `network.tf` | Network interface and static IP configuration |
| `security.tf` | Custom RDP NSG rule |
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

## Infrastructure Validation — October 27, 2026

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
- Avoided assigning a public IP to the Windows Server.
- Created a source-specific RDP NSG rule while documenting the broader effective NSG behavior.
- Validated administrative access through an SSH tunnel.
- Used a sensitive Terraform variable instead of hardcoding the administrator password.
- Removed the Azure subscription ID from version-controlled configuration.
- Preserved active Terraform state outside the public repository.
- Verified VM deallocation after completing the lab.

## Future Improvements

- Introduce Azure Storage remote Terraform state with appropriate access controls.
- Replace environment-specific values with reusable Terraform variables.
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

Administrator credentials, SSH private keys, Azure subscription identifiers, and active Terraform state are excluded from the published documentation.

The repository distinguishes validated deployment outcomes from future planned improvements.
