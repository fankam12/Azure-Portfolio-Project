
# Windows Server 2022 Virtual Machines — Azure Deployment & Administration

## Overview

This project documents the deployment and infrastructure configuration of two Windows Server 2022 Datacenter virtual machines within my Microsoft Azure HomeLab.

The implementation extends an existing environment of Linux virtual machines, segmented subnets, Network Security Groups (NSGs), and bidirectional virtual network peering.

The Windows Server VMs are deployed across management and development environments to support Windows infrastructure administration, private connectivity, and cloud operations testing.

The development VM, `Dev-win01`, was deployed using Terraform, demonstrating Infrastructure-as-Code (IaC) integration with existing Azure resources.

**Implementation outcomes**

- Two Windows Server 2022 Datacenter virtual machines deployed in East US.
- Windows workloads integrated into existing Azure virtual networks and subnets.
- Private IP addressing without directly assigned public IP addresses.
- Terraform-based deployment of `Dev-win01`.
- Restricted RDP network security rule for the development Windows VM.
- Azure CLI validation of VM configurations, network interfaces, subnet placement, and power states.
- VM deallocation to control compute costs.

[← Compute Overview](./README.md)

## Architecture

### Virtual Machine Inventory

| Configuration | Prod-win01 | Dev-win01 |
|---|---|---|
| Operating System | Windows Server 2022 Datacenter | Windows Server 2022 Datacenter |
| Image SKU | `2022-datacenter-g2` | `2022-datacenter-g2` |
| Resource Group | `HomeLab_RG` | `DevLab_RG` |
| Azure Region | East US | East US |
| VM Size | `Standard_D2as_v7` | `Standard_D2as_v7` |
| Virtual Network | `HomeLab_VNet` | `Devlab_VNet` |
| Subnet | `ManagementSubnet` | `AppSubnet` |
| Private IP | `10.10.0.5` | `10.20.1.5` |
| Public IP | No | No |
| Network Interface | `Prod-win01VMNic` | `Dev-win01-nic` |
| Deployment Method | Not documented here | Terraform |
| Last Verified Power State | Deallocated | Deallocated |

### Network Architecture

```text
Azure HomeLab Subscription
│
├── HomeLab_RG
│   └── HomeLab_VNet (10.10.0.0/16)
│       └── ManagementSubnet (10.10.0.0/24)
│           ├── ManagementSubnet_NSG
│           │
│           ├── Prod-mgmt01 [Ubuntu Linux]
│           │   ├── Private IP: 10.10.0.4
│           │   └── Public administrative endpoint
│           │
│           └── Prod-win01 [Windows Server 2022]
│               ├── Private IP: 10.10.0.5
│               └── No Public IP
│
│                  ⇅
│             VNet Peering
│                  ⇅
│
└── DevLab_RG
    └── Devlab_VNet (10.20.0.0/16)
        └── AppSubnet (10.20.1.0/24)
            ├── AppSubnet_NSG
            │
            ├── Dev-app01 [Ubuntu Linux]
            │   └── Private IP: 10.20.1.4
            │
            └── Dev-win01 [Windows Server 2022]
                ├── Private IP: 10.20.1.5
                ├── No Public IP
                └── Terraform-managed deployment
```

Both Windows Server VMs use existing Azure networking infrastructure.

The management and development networks communicate through bidirectional VNet peering, allowing private routing between their address spaces.

Network Security Groups provide traffic filtering at the subnet level.

## Deployment & Configuration

### Prod-win01 — Management Environment

`Prod-win01` is deployed in `HomeLab_RG` alongside the existing Linux management VM.

Its network interface, `Prod-win01VMNic`, is attached to `ManagementSubnet` within `HomeLab_VNet`.

The VM has private IP address `10.10.0.5` and no public IP address.

The configuration supports Windows Server administration and Azure infrastructure testing within the management environment.

#### Azure CLI Configuration Verification

```bash
az vm show -g HomeLab_RG -n Prod-win01 -d -o table
```

The VM's network interface can be inspected using:

```bash
az network nic show -g HomeLab_RG -n Prod-win01VMNic --query "{Name:name,PrivateIP:ipConfigurations[0].privateIPAddress,Subnet:ipConfigurations[0].subnet.id,PublicIP:ipConfigurations[0].publicIPAddress.id}" -o json
```

The verified network configuration returned:

```json
{
  "Name": "Prod-win01VMNic",
  "PrivateIP": "10.10.0.5",
  "PublicIP": null,
  "Subnet": "/subscriptions/<SUBSCRIPTION-ID>/resourceGroups/HomeLab_RG/providers/Microsoft.Network/virtualNetworks/HomeLab_VNet/subnets/ManagementSubnet"
}
```

This confirms that the VM is attached to the intended management subnet without a directly assigned public IP address.

### Dev-win01 — Development Environment

`Dev-win01` is deployed in `DevLab_RG` using Terraform.

The VM uses Windows Server 2022 Datacenter, a `Standard_D2as_v7` VM size, and a Standard SSD operating system disk.

Its network interface is configured with a static private IP address of `10.20.1.5`.

The deployment reuses existing Azure resources instead of creating a separate resource group, virtual network, or subnet.

#### Azure CLI Configuration Verification

```bash
az vm show -g DevLab_RG -n Dev-win01 -d -o table
```

Verify the network interface:

```bash
az network nic show -g DevLab_RG -n Dev-win01-nic --query "{Name:name,PrivateIP:ipConfigurations[0].privateIPAddress,Subnet:ipConfigurations[0].subnet.id,PublicIP:ipConfigurations[0].publicIPAddress.id}" -o json
```

The verified network configuration returned:

```json
{
  "Name": "Dev-win01-nic",
  "PrivateIP": "10.20.1.5",
  "PublicIP": null,
  "Subnet": "/subscriptions/<SUBSCRIPTION-ID>/resourceGroups/DevLab_RG/providers/Microsoft.Network/virtualNetworks/Devlab_VNet/subnets/AppSubnet"
}
```

This confirms that the VM resides in the intended application subnet and does not have a directly assigned public IP address.

## Infrastructure as Code — Terraform

The development Windows Server VM was provisioned using Terraform with the AzureRM provider.

Terraform manages the Windows VM, network interface, static private IP configuration, and a restricted RDP NSG rule.

The implementation references existing Azure infrastructure through Terraform data sources.

### Terraform Resource Configuration

| Terraform Component | Purpose |
|---|---|
| `azurerm_windows_virtual_machine` | Deploys and manages `Dev-win01` |
| `azurerm_network_interface` | Creates `Dev-win01-nic` with a static private IP |
| `azurerm_network_security_rule` | Defines restricted RDP access |
| `data.azurerm_resource_group` | References `DevLab_RG` |
| `data.azurerm_virtual_network` | References `Devlab_VNet` |
| `data.azurerm_subnet` | References `AppSubnet` |

### VM Configuration

The Windows Server resource uses the following image:

```hcl
source_image_reference {
  publisher = "MicrosoftWindowsServer"
  offer     = "WindowsServer"
  sku       = "2022-datacenter-g2"
  version   = "latest"
}
```

The VM size and OS disk configuration are:

```hcl
size = "Standard_D2as_v7"

os_disk {
  caching              = "ReadWrite"
  storage_account_type = "StandardSSD_LRS"
}
```

### Static Private IP Configuration

The network interface uses a static private IP address:

```hcl
ip_configuration {
  name                          = "internal"
  subnet_id                     = data.azurerm_subnet.app_subnet.id
  private_ip_address_allocation = "Static"
  private_ip_address            = "10.20.1.5"
}
```

This provides a predictable destination address for administrative connectivity and security rule configuration.

### Terraform Deployment Workflow

The documented deployment workflow consists of:

1. Authenticate to Azure and select the intended subscription.
2. Supply the Azure subscription ID through `ARM_SUBSCRIPTION_ID`.
3. Provide the Windows administrator password through a sensitive Terraform variable or approved secret-management mechanism.
4. Initialize the Terraform working directory.
5. Validate the Terraform configuration.
6. Review the proposed infrastructure changes.
7. Apply the reviewed configuration.

```bash
terraform init
terraform validate
terraform plan
```

```bash
terraform apply
```

**Important:** These commands are shown for reference, not as instructions to redeploy the existing VM.

The active deployment uses local Terraform state stored separately from the published GitHub repository. Running `terraform apply` from a fresh clone without reconciling state could attempt to recreate existing resources.

Terraform state and administrator credentials must not be committed to GitHub.

**Detailed implementation:** [Windows Server 2022 Terraform Deployment](../../terraform/dev-windows-vm/README.md)

## Network Security & Private Administration

### Public IP Configuration

Neither Windows Server VM has a directly assigned public IP address.

This reduces direct internet exposure and supports the private administration model used throughout the HomeLab.

However, the absence of a public IP address does not automatically guarantee that every network path is secure. Effective NSG rules, routing, and guest operating system controls must also be considered.

### Dev-win01 RDP Security Rule

The Terraform deployment defines a restricted inbound RDP rule in `AppSubnet_NSG`.

| Setting | Configuration |
|---|---|
| NSG | `AppSubnet_NSG` |
| Rule Name | `Allow-RDP-ManagementSubnet` |
| Priority | `110` |
| Direction | Inbound |
| Protocol | TCP |
| Destination Port | `3389` |
| Source IP | `10.10.0.4/32` |
| Destination IP | `10.20.1.5` |
| Action | Allow |

The source restriction limits this custom allow rule to the management Linux VM, `Prod-mgmt01`.

The Terraform configuration is:

```hcl
resource "azurerm_network_security_rule" "allow_rdp_management" {
  name      = "Allow-RDP-ManagementSubnet"
  priority  = 110
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_port_range      = "*"
  destination_port_range = "3389"

  source_address_prefix      = "10.10.0.4/32"
  destination_address_prefix = azurerm_network_interface.dev_win01_nic.private_ip_address

  resource_group_name         = data.azurerm_resource_group.devlab.name
  network_security_group_name = "AppSubnet_NSG"
}
```

This documents the intended RDP access path.

Because Azure NSGs include default rules, the custom source-restricted allow rule alone does not prove that every other source is denied. Full RDP isolation requires reviewing the effective NSG policy and testing unauthorized paths.

### Private RDP Administration Design

The intended administrative connection uses the Linux management VM as an intermediary.

```text
Administrator Workstation
          │
          │ SSH
          ▼
Prod-mgmt01
10.10.0.4
          │
          │ VNet Peering
          │
          │ TCP/3389
          ▼
Dev-win01
10.20.1.5
```

The documented design uses SSH tunneling through `Prod-mgmt01` to reach the private Windows Server VM.

Successful RDP authentication, Windows Firewall behavior, and end-to-end tunnel connectivity require separate operational validation.

### Network Security Inspection

Review the configured rules:

```bash
az network nsg rule list -g DevLab_RG --nsg-name AppSubnet_NSG -o table
```

Inspect the effective security rules applied to the Windows VM's NIC:

```bash
az network nic list-effective-nsg -g DevLab_RG -n Dev-win01-nic -o json
```

Effective security rule inspection helps distinguish an NSG rule that exists in the resource configuration from one that is actually applied to the VM's network interface.

## Infrastructure Validation

### Virtual Machine Inventory

The Azure CLI was used to inspect the deployed Windows Server virtual machines.

```bash
az vm list -d --query "[].{Name:name,ResourceGroup:resourceGroup,Location:location,Size:hardwareProfile.vmSize,PowerState:powerState,PrivateIP:privateIps,PublicIP:publicIps}" -o table
```

The verified Windows VM results were:

```text
Name        ResourceGroup    Location    Size              PowerState      PrivateIP
----------  ---------------  ----------  ----------------  --------------  ----------
Dev-win01   DEVLAB_RG        eastus      Standard_D2as_v7  VM deallocated  10.20.1.5
Prod-win01  HOMELAB_RG       eastus      Standard_D2as_v7  VM deallocated  10.10.0.5
```

Neither VM reported a public IP address.

### Operating System Image Validation

The VM image references were inspected through Azure CLI.

```bash
az vm list --query "[?name=='Prod-win01' || name=='Dev-win01'].{Name:name,Publisher:storageProfile.imageReference.publisher,Offer:storageProfile.imageReference.offer,SKU:storageProfile.imageReference.sku}" -o table
```

Both VMs were configured with:

```text
Publisher: MicrosoftWindowsServer
Offer:     WindowsServer
SKU:       2022-datacenter-g2
```

This confirms the configured Azure Marketplace image reference. It does not independently verify the current guest OS health or patch level.

### Network Interface Validation

Both NIC configurations were inspected using Azure CLI.

| VM | NIC | Private IP | Subnet | Public IP |
|---|---|---|---|---|
| `Prod-win01` | `Prod-win01VMNic` | `10.10.0.5` | `ManagementSubnet` | No |
| `Dev-win01` | `Dev-win01-nic` | `10.20.1.5` | `AppSubnet` | No |

The returned subnet resource IDs confirmed that both network interfaces were associated with their intended virtual networks and subnets.

### Validation Summary

| Validation | Prod-win01 | Dev-win01 |
|---|---|---|
| VM exists in Azure | Verified | Verified |
| Windows Server 2022 image reference | Verified | Verified |
| VM size | Verified | Verified |
| Resource group placement | Verified | Verified |
| VNet and subnet placement | Verified | Verified |
| Private IP configuration | Verified | Verified |
| No directly assigned public IP | Verified | Verified |
| Deallocated power state at last check | Verified | Verified |
| Terraform source configuration | Not established | Verified |
| RDP end-to-end connectivity | Not yet documented | Not yet documented |
| Windows guest administration | Not yet documented | Not yet documented |
| Windows patching | Not yet documented | Not yet documented |

## VM Lifecycle & Cost Management

Both Windows Server VMs were deallocated during the latest Azure CLI configuration review.

Deallocation releases the VM's allocated compute resources and stops compute billing while retaining associated resources such as managed disks.

### Verify VM Power State

```bash
az vm get-instance-view -g HomeLab_RG -n Prod-win01 --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" -o tsv
```

```bash
az vm get-instance-view -g DevLab_RG -n Dev-win01 --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" -o tsv
```

### Start a VM for Administration

```bash
az vm start -g HomeLab_RG -n Prod-win01
```

```bash
az vm start -g DevLab_RG -n Dev-win01
```

### Deallocate a VM After Testing

```bash
az vm deallocate -g HomeLab_RG -n Prod-win01
```

```bash
az vm deallocate -g DevLab_RG -n Dev-win01
```

These commands change Azure resource state and should be executed only when the corresponding action is intended.

The HomeLab uses cost controls and VM lifecycle management to limit unnecessary compute charges.

## Troubleshooting Approach

Windows Server troubleshooting in Azure requires distinguishing between infrastructure configuration, network connectivity, and guest operating system behavior.

| Layer | Example Investigation | Azure Tool or Method |
|---|---|---|
| Compute | VM stopped, deallocated, or failed to start | Azure CLI instance view |
| Image | Incorrect operating system image reference | Azure VM resource inspection |
| Networking | Incorrect NIC, private IP, VNet, or subnet | Azure NIC inspection |
| Security | Missing or overly permissive RDP rules | NSG and effective NSG inspection |
| Routing | Missing private connectivity across VNets | Effective routes and peering inspection |
| Guest OS | Windows Firewall, RDP service, authentication | Windows administration tools |
| IaC | Terraform drift, unexpected changes, or state mismatch | Terraform plan and state inspection |

These are diagnostic procedures and investigation areas, not claims that every scenario has already been executed.

### Example: Investigating an Unreachable Private Windows VM

A structured investigation would include:

1. Verify the VM is running.
2. Confirm the NIC's private IP address and subnet association.
3. Check VNet peering and effective routes.
4. Inspect effective NSG rules for TCP/3389.
5. Verify the management VM can reach the destination network.
6. Inspect the Windows Firewall and RDP service from an authorized guest administration session.
7. Confirm administrator credentials and authentication requirements.
8. Record the root cause, resolution, and validation results.

This workflow separates Azure control-plane configuration from guest operating system troubleshooting.

## Engineering Lessons Learned

1. **Reuse existing infrastructure when appropriate.** Terraform data sources allow a VM deployment to integrate with established resource groups and networks rather than recreating shared infrastructure.
2. **Use private addressing for administrative workloads.** Windows Server VMs can be deployed without directly exposing RDP to the internet.
3. **Validate actual resource placement.** NIC subnet IDs provide stronger evidence of network placement than naming conventions alone.
4. **Distinguish security intent from effective enforcement.** An RDP allow rule must be evaluated alongside default NSG rules and other applicable controls.
5. **Protect Terraform state and credentials.** Sensitive values and active state require appropriate handling outside public source control.
6. **Verify resource state before making changes.** VM lifecycle operations affect availability and costs.
7. **Separate infrastructure validation from guest OS validation.** A successfully deployed Windows Server image does not automatically prove RDP functionality, patch compliance, or operating system health.

## Related Documentation

- [Azure Compute Overview](./README.md)
- [Private Linux Virtual Machines](./private-linux-vms.md)
- [Windows Server 2022 Terraform Deployment](../../terraform/dev-windows-vm/README.md)
- [Azure Infrastructure Portfolio](../../README.md)

## Security & Responsible Testing

This project documents an independent personal Microsoft Azure HomeLab used for infrastructure engineering and technical validation.

Employer credentials, confidential information, proprietary infrastructure configurations, and production data are not used.

The documentation excludes administrator passwords, SSH private keys, Terraform state contents, and the full Azure subscription identifier.

All administrative access and testing should use authorized resources and follow least-privilege security practices.
