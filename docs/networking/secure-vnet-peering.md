# Secure Azure Network Architecture with VNet Peering

## Overview

This implementation establishes a segmented Azure network architecture across separate management and development environments.

Two Azure Virtual Networks are deployed into separate resource groups and connected through bidirectional VNet peering. Network Security Groups are associated with individual subnets to establish traffic-control boundaries based on workload function.

The environment was provisioned and validated using Azure CLI and provides the network foundation for future compute and application workloads.

---

## Architecture

```text
                         Azure Subscription
                                │
              ┌─────────────────┴─────────────────┐
              │                                   │
         HomeLab_RG                          DevLab_RG
              │                                   │
       HomeLab-VNet                         DevLab-VNet
       10.10.0.0/16                         10.20.0.0/16
              │                                   │
              │                         ┌─────────┴─────────┐
              │                         │                   │
    ManagementSubnet               AppSubnet           DataSubnet
      10.10.0.0/24                10.20.1.0/24        10.20.2.0/24
              │                         │                   │
    ManagementSubnet-NSG           AppSubnet-NSG       DataSubnet-NSG
              │                         │                   │
              └────────────── VNet Peering ────────────────┘
```

---

## Addressing Plan

| Resource Group | Virtual Network | Address Space  | Subnet             | CIDR           |
| -------------- | --------------- | -------------- | ------------------ | -------------- |
| `HomeLab_RG`   | `HomeLab-VNet`  | `10.10.0.0/16` | `ManagementSubnet` | `10.10.0.0/24` |
| `DevLab_RG`    | `DevLab-VNet`   | `10.20.0.0/16` | `AppSubnet`        | `10.20.1.0/24` |
| `DevLab_RG`    | `DevLab-VNet`   | `10.20.0.0/16` | `DataSubnet`       | `10.20.2.0/24` |

The VNet address spaces are intentionally non-overlapping to support VNet peering and provide sufficient address capacity for future subnet expansion.

---

## Design Decisions

### Separate Network Boundaries

Management and development workloads are placed in separate virtual networks.

```text
HomeLab-VNet
      │
      └── Management workloads

DevLab-VNet
      │
      ├── Application workloads
      └── Data workloads
```

This provides logical isolation between management and development resources while allowing controlled private communication through VNet peering.

---

### Workload-Based Segmentation

`DevLab-VNet` is segmented into application and data subnets:

```text
DevLab-VNet
│
├── AppSubnet
│      └── Application-tier resources
│
└── DataSubnet
       └── Data-tier resources
```

Separating workload functions allows different network security policies to be applied to each tier.

Future application compute resources can be deployed into `AppSubnet`, while databases or other data-tier services can use `DataSubnet`.

---

## Network Security

Each subnet is associated with a dedicated Network Security Group.

| Network Security Group | Association        | Purpose                           |
| ---------------------- | ------------------ | --------------------------------- |
| `ManagementSubnet-NSG` | `ManagementSubnet` | Management traffic controls       |
| `AppSubnet-NSG`        | `AppSubnet`        | Application-tier traffic controls |
| `DataSubnet-NSG`       | `DataSubnet`       | Data-tier traffic controls        |

This establishes independent security boundaries for each workload segment.

```text
ManagementSubnet ──► ManagementSubnet-NSG

AppSubnet ─────────► AppSubnet-NSG

DataSubnet ────────► DataSubnet-NSG
```

As workloads are introduced, additional NSG rules can restrict communication to required protocols, ports, and network sources.

---

## VNet Peering

Bidirectional VNet peering connects the two network environments.

```text
HomeLab-VNet
     │
     │ HomeLab-to-DevLab
     ▼
DevLab-VNet

DevLab-VNet
     │
     │ DevLab-to-HomeLab
     ▼
HomeLab-VNet
```

The following peerings are configured:

* `HomeLab-to-DevLab`
* `DevLab-to-HomeLab`

VNet access is enabled in both directions.

Peering establishes private network reachability between the VNets while Network Security Groups remain responsible for controlling permitted traffic between workload segments.

---

# Deployment

## HomeLab Network

### Create HomeLab-VNet and ManagementSubnet

```bash
az network vnet create --resource-group "HomeLab_RG" --name "HomeLab-VNet" --address-prefixes "10.10.0.0/16" --subnet-name "ManagementSubnet" --subnet-prefixes "10.10.0.0/24"
```

### Create ManagementSubnet-NSG

```bash
az network nsg create --resource-group "HomeLab_RG" --name "ManagementSubnet-NSG"
```

### Associate the NSG

```bash
az network vnet subnet update --resource-group "HomeLab_RG" --vnet-name "HomeLab-VNet" --name "ManagementSubnet" --network-security-group "ManagementSubnet-NSG"
```

---

## DevLab Network

### Create DevLab-VNet and AppSubnet

```bash
az network vnet create --resource-group "DevLab_RG" --name "DevLab-VNet" --address-prefixes "10.20.0.0/16" --subnet-name "AppSubnet" --subnet-prefixes "10.20.1.0/24"
```

### Create DataSubnet

```bash
az network vnet subnet create --resource-group "DevLab_RG" --vnet-name "DevLab-VNet" --name "DataSubnet" --address-prefixes "10.20.2.0/24"
```

### Create AppSubnet-NSG

```bash
az network nsg create --resource-group "DevLab_RG" --name "AppSubnet-NSG"
```

### Create DataSubnet-NSG

```bash
az network nsg create --resource-group "DevLab_RG" --name "DataSubnet-NSG"
```

### Associate AppSubnet-NSG

```bash
az network vnet subnet update --resource-group "DevLab_RG" --vnet-name "DevLab-VNet" --name "AppSubnet" --network-security-group "AppSubnet-NSG"
```

### Associate DataSubnet-NSG

```bash
az network vnet subnet update --resource-group "DevLab_RG" --vnet-name "DevLab-VNet" --name "DataSubnet" --network-security-group "DataSubnet-NSG"
```

---

# Peering Configuration

## Retrieve VNet Resource IDs

```bash
az network vnet show --resource-group "HomeLab_RG" --name "HomeLab-VNet" --query id -o tsv
```

```bash
az network vnet show --resource-group "DevLab_RG" --name "DevLab-VNet" --query id -o tsv
```

## Create HomeLab-to-DevLab Peering

```bash
az network vnet peering create --resource-group "HomeLab_RG" --vnet-name "HomeLab-VNet" --name "HomeLab-to-DevLab" --remote-vnet "/subscriptions/<subscription-id>/resourceGroups/DevLab_RG/providers/Microsoft.Network/virtualNetworks/DevLab-VNet" --allow-vnet-access
```

## Create DevLab-to-HomeLab Peering

```bash
az network vnet peering create --resource-group "DevLab_RG" --vnet-name "DevLab-VNet" --name "DevLab-to-HomeLab" --remote-vnet "/subscriptions/<subscription-id>/resourceGroups/HomeLab_RG/providers/Microsoft.Network/virtualNetworks/HomeLab-VNet" --allow-vnet-access
```

---

# Validation

## Virtual Networks

```bash
az network vnet list -o table
```

## HomeLab Subnets

```bash
az network vnet subnet list --resource-group "HomeLab_RG" --vnet-name "HomeLab_VNet" -o table
```

## DevLab Subnets

```bash
az network vnet subnet list --resource-group "DevLab_RG" --vnet-name "DevLab_VNet" -o table
```

## Network Security Groups

```bash
az network nsg list -o table
```

## HomeLab Peering

```bash
az network vnet peering list --resource-group "HomeLab_RG" --vnet-name "HomeLab_VNet" -o table
```

## DevLab Peering

```bash
az network vnet peering list --resource-group "DevLab_RG" --vnet-name "DevLab_VNet" -o table
```

Successful peering should report a `Connected` peering state.

---

# Troubleshooting & Lessons Learned

## Resource Resolution During NSG Association

During network configuration, an issue occurred while associating the `ManagementSubnet-NSG` with `ManagementSubnet`.

The initial subnet update returned an Azure Resource Manager `ResourceNotFound` error indicating that the specified virtual network could not be located within `HomeLab_RG`.

```text id="err01"
(ResourceNotFound) The Resource 'Microsoft.Network/virtualNetworks/HomeLab-VNet'
under resource group 'HomeLab_RG' was not found.
```

### Investigation

Rather than immediately recreating the resource, I first verified the existing Azure configuration to determine whether the issue was related to resource deployment, resource group placement, or naming.

The available virtual networks were queried:

```bash id="cmd01"
az network vnet list -o table
```

The resources within the target resource group were also reviewed:

```bash id="cmd02"
az resource list --resource-group "HomeLab_RG" -o table
```

Once the VNet was identified, its configuration could be inspected directly:

```bash id="cmd03"
az network vnet show --resource-group "HomeLab_RG" --name "HomeLab_VNet" -o table
```

The subnet configuration was then verified:

```bash id="cmd04"
az network vnet subnet list --resource-group "HomeLab_RG" --vnet-name "<HomeLab_VNet" -o table
```

### Root Cause

The troubleshooting process identified an inconsistency between the VNet name referenced by the Azure CLI command and the actual resource name deployed in Azure.

Azure CLI commands must reference the exact Azure resource name. Small naming differences—such as using a hyphen instead of an underscore or referencing a planned name rather than the deployed name—can cause Azure Resource Manager to search for a resource that does not exist.

For example:

```text id="name01"
HomeLab-VNet
HomeLab_VNet
```

These represent different resource names.

The issue was therefore not caused by VNet connectivity, NSG functionality, or subnet configuration. It was a resource identification issue.

### Resolution

After confirming the deployed resource names, the subnet update command was corrected to reference the actual VNet and NSG.

```bash id="cmd05"
az network vnet subnet update --resource-group "HomeLab_RG" --vnet-name "HomeLab_VNet" --name "ManagementSubnet" --network-security-group "ManagementSubnet-NSG"
```

### Validation

Following the correction, the subnet configuration was queried again to verify the NSG association:

```bash id="cmd06"
az network vnet subnet show --resource-group "HomeLab_RG" --vnet-name "HomeLab_VNet" --name "ManagementSubnet" --query "{Subnet:name,AddressPrefix:addressPrefix,NetworkSecurityGroup:networkSecurityGroup.id}" -o json
```

This provided confirmation that the subnet existed under the expected VNet and that the intended Network Security Group was associated with it.

---

## Key Takeaways

This issue reinforced several practices that are important when managing Azure infrastructure through the CLI:

### Verify Before Recreating

A `ResourceNotFound` response does not automatically mean the infrastructure needs to be redeployed.

Before making changes, verify:

```text id="flow01"
Resource Group
     ↓
Resource
     ↓
Resource Name
     ↓
Resource Configuration
     ↓
Command Parameters
```

This reduces the risk of creating duplicate or unnecessary infrastructure while troubleshooting.

### Treat Resource Names as Configuration

Consistent naming becomes increasingly important as environments grow.

A difference such as:

```text id="name02"
DevLab-VNet
vs.
DevLab_VNet
```

may appear minor to a person but represents a different resource identifier to automation tooling.

Consistent naming conventions reduce errors across Azure CLI, Infrastructure as Code, deployment pipelines, and operational scripts.

### Use Azure CLI for Discovery, Not Only Deployment

The Azure CLI is useful not only for creating resources but also for investigating the current state of an environment.

Commands such as:

```bash id="cmd07"
az resource list --resource-group "HomeLab_RG" -o table
```

and:

```bash id="cmd08"
az network vnet list -o table
```

can be used to establish what actually exists before executing configuration changes.

This creates a more reliable troubleshooting workflow:

```text id="flow02"
Observe the Error
       ↓
Inspect Current State
       ↓
Verify Resource Scope
       ↓
Verify Resource Names
       ↓
Identify Root Cause
       ↓
Apply Correction
       ↓
Validate Final State
```

## Engineering Lesson

The most valuable takeaway was not the corrected command itself, but the troubleshooting approach.

When infrastructure automation fails, I want to distinguish between:

* A resource that does not exist
* A resource deployed into the wrong scope
* An incorrect resource name
* A configuration issue
* A permissions issue
* A networking issue
* Incorrect CLI syntax

By querying Azure's current state before making additional changes, the problem can be narrowed down systematically rather than troubleshooting through trial and error.


# Security Model

VNet peering and Network Security Groups serve different responsibilities within the architecture.

```text
VNet Peering
     │
     └── Establishes network connectivity
                    │
                    ▼
                   NSGs
                    │
                    └── Control permitted traffic
```

Peering provides a private network path between the VNets. It does not mean every workload should be permitted to communicate with every other workload.

As compute and application resources are deployed, NSG rules can enforce more restrictive traffic patterns such as:

```text
ManagementSubnet
        │
        │ Administrative Traffic
        ▼
    AppSubnet
        │
        │ Required Application Traffic
        ▼
    DataSubnet
```

This provides a foundation for applying least-privilege principles to east-west network traffic.

---

# Future Expansion

The architecture provides the network foundation for additional Azure workloads.

Future implementations can introduce compute resources into the existing network segments:

```text
ManagementSubnet
        │
        └── Management / administrative resources

AppSubnet
        │
        └── Application compute resources

DataSubnet
        │
        └── Data-tier resources
```

This will allow private connectivity, NSG enforcement, routing behavior, and VNet peering to be validated using actual workloads.

The architecture can later evolve as additional requirements introduce Infrastructure as Code, application delivery, monitoring, centralized networking, and other Azure platform services.

---

## Skills Demonstrated

* Azure Virtual Network architecture
* CIDR and private IP address planning
* Workload-based subnet segmentation
* Network Security Groups
* Subnet-level security boundaries
* Non-overlapping VNet address spaces
* Azure VNet peering
* Private cross-VNet connectivity
* Azure CLI infrastructure deployment
* Azure CLI infrastructure validation
* Network architecture documentation

