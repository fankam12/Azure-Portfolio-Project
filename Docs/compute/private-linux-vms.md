# Private Linux VMs

## Overview

This implementation extends the existing Azure networking environment by deploying Linux virtual machines into the management and development networks.

The existing infrastructure already separated management and development resources using `HomeLab_VNet` and `Devlab_VNet`, with private communication provided through VNet peering.

The next step was to introduce compute resources and validate how virtual machines communicate across those network boundaries.

Two Ubuntu Linux virtual machines were deployed:

* `Prod-mgmt01` — management VM in `HomeLab_VNet`
* `Dev-app01` — private application VM in `Devlab_VNet`

The implementation also introduced SSH public-key authentication, Network Interface Cards, private administrative access, SSH agent forwarding, routing validation, DNS testing, outbound connectivity testing, and VM lifecycle management.

---

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
│           ├── ManagementSubnet_NSG
│           │
│           └── Prod-mgmt01
│               │
│               ├── Ubuntu Linux
│               ├── NIC
│               ├── Private IP: 10.10.0.4
│               └── Public IP
│
│                         ⇅
│                    VNet Peering
│                         ⇅
│
└── DevLab_RG
    │
    └── Devlab_VNet
        │
        ├── AppSubnet
        │   │
        │   ├── AppSubnet_NSG
        │   │
        │   └── Dev-app01
        │       │
        │       ├── Ubuntu Linux
        │       ├── NIC
        │       ├── Private IP: 10.20.1.4
        │       └── No Public IP
        │
        └── DataSubnet
            │
            └── DataSubnet_NSG
```

---

## Design

### Management VM

`Prod-mgmt01` was deployed into `ManagementSubnet` within `HomeLab_VNet`.

The VM provides an administrative entry point for resources that should not require direct public access.

```text
Administrator
     │
     │ SSH
     ▼
Prod-mgmt01
```

This management path also provides access to private workloads located within the peered development network.

---

### Private Application VM

`Dev-app01` was deployed into `AppSubnet` within `Devlab_VNet`.

Unlike the management VM, `Dev-app01` was intentionally deployed without a public IP address.

Administrative access therefore follows:

```text
Administrator
     │
     ▼
Prod-mgmt01
     │
     │ VNet Peering
     ▼
Dev-app01
```

This allows the application workload to remain private while still being administratively reachable from the management environment.

---

## SSH Key Configuration

SSH public-key authentication was used instead of password authentication.

Before generating the key, the existing SSH configuration was checked:

```bash
ls -la ~/.ssh
```

The workstation returned:

```text
ls: /Users/ev/.ssh: No such file or directory
```

No SSH directory or existing key pair was present.

An Ed25519 key pair was generated:

```bash
ssh-keygen -t ed25519 -C "azure-homelab"
```

The default location was accepted:

```text
/Users/ev/.ssh/id_ed25519
```

This generated:

```text
~/.ssh/id_ed25519
~/.ssh/id_ed25519.pub
```

The private key:

```text
id_ed25519
```

remains on the administrator workstation.

The public key:

```text
id_ed25519.pub
```

is used by the Azure Linux virtual machines to authenticate SSH connections.

The public key can be displayed with:

```bash
cat ~/.ssh/id_ed25519.pub
```

> The private SSH key is not stored in this repository and should never be committed to source control.

---

## Virtual Machine Deployment

### Prod-mgmt01

The management VM was deployed into the existing production management network.

| Configuration    | Value              |
| ---------------- | ------------------ |
| VM               | `Prod-mgmt01`      |
| Resource Group   | `HomeLab_RG`       |
| VNet             | `HomeLab_VNet`     |
| Subnet           | `ManagementSubnet` |
| Operating System | Ubuntu Linux       |
| Private IP       | `10.10.0.4`        |
| Authentication   | SSH Public Key     |

The deployment reused the existing networking resources rather than creating a new VNet or subnet.

VM configuration can be reviewed with:

```bash
az vm show --resource-group "HomeLab_RG" --name "Prod-mgmt01" -d -o table
```

---

### Dev-app01

The application VM was deployed into the existing development network.

| Configuration    | Value          |
| ---------------- | -------------- |
| VM               | `Dev-app01`    |
| Resource Group   | `DevLab_RG`    |
| VNet             | `Devlab_VNet`  |
| Subnet           | `AppSubnet`    |
| Operating System | Ubuntu Linux   |
| Private IP       | `10.20.1.4`    |
| Public IP        | None           |
| Authentication   | SSH Public Key |

VM configuration can be reviewed with:

```bash
az vm show --resource-group "DevLab_RG" --name "Dev-app01" -d -o table
```

Because the VM has no public IP, administrative access must originate from a system with private network connectivity to `Devlab_VNet`.

---

## Network Interface Cards

Each virtual machine is connected to its Azure virtual network through a Network Interface Card.

```text
Virtual Machine
      │
      ▼
     NIC
      │
      ▼
    Subnet
      │
      ▼
Virtual Network
```

The NIC provides the connection between the virtual machine and Azure's software-defined network.

NIC configuration includes:

* private IP address
* subnet association
* public IP association when applicable
* effective NSG rules
* effective routes

NICs can be listed with:

```bash
az network nic list -o table
```

The NIC attached to `Prod-mgmt01` can be identified with:

```bash
az vm show --resource-group "HomeLab_RG" --name "Prod-mgmt01" --query "networkProfile.networkInterfaces[].id" -o tsv
```

The NIC attached to `Dev-app01` can be identified with:

```bash
az vm show --resource-group "DevLab_RG" --name "Dev-app01" --query "networkProfile.networkInterfaces[].id" -o tsv
```

---

## Network Security

The existing subnet-level Network Security Groups continue to provide traffic filtering for the virtual machines.

```text
ManagementSubnet
      │
      └── ManagementSubnet_NSG

AppSubnet
      │
      └── AppSubnet_NSG
```

SSH access to `Dev-app01` is restricted to the management subnet.

The relevant traffic path is:

```text
Prod-mgmt01
10.10.0.4
     │
     │ TCP/22
     ▼
AppSubnet_NSG
     │
     ▼
Dev-app01
10.20.1.4
```

The SSH rule uses the management subnet as the trusted source rather than permitting SSH from any Internet address.

```text
Source:      10.10.0.0/24
Protocol:    TCP
Port:        22
Action:      Allow
```

The configured NSG rules can be inspected with:

```bash
az network nsg rule list --resource-group "DevLab_RG" --nsg-name "AppSubnet_NSG" -o table
```

---

# Validation

## VM Deployment

The deployed virtual machines were validated using Azure CLI.

```bash
az vm list -d -o table
```

This confirmed that the expected VMs existed and allowed their network information and power state to be reviewed.

---

## Private IP Addressing

`Prod-mgmt01` received:

```text
10.10.0.4
```

`Dev-app01` received:

```text
10.20.1.4
```

The addresses confirmed that both VMs were connected to their intended network environments.

---

## Private TCP Connectivity

From `Prod-mgmt01`, TCP/22 connectivity to the private application VM was tested:

```bash
nc -zv 10.20.1.4 22
```

Successful TCP connectivity confirmed that the SSH service was reachable across the peered virtual networks.

The network path was:

```text
Prod-mgmt01
      │
      ▼
HomeLab_VNet
      │
      ▼
VNet Peering
      │
      ▼
Devlab_VNet
      │
      ▼
AppSubnet_NSG
      │
      ▼
Dev-app01
```

---

## Private SSH Connectivity

SSH was then tested using the private IP address:

```bash
ssh <USERNAME>@10.20.1.4
```

Successful SSH access validated the combined operation of:

* VM networking
* NIC configuration
* subnet placement
* NSG rules
* VNet peering
* Azure routing
* TCP/22
* SSH authentication

---

## Effective Routes

Effective routes were inspected on the development VM NIC.

```bash
az network nic show-effective-route-table --resource-group "DevLab_RG" --name "<DEV-APP01-NIC>" -o table
```

The route table showed the management VNet address space as reachable through VNet peering:

```text
10.10.0.0/16 → VNetPeering
```

This verified that Azure had a valid network path from the development environment back to `HomeLab_VNet`.

---

## Outbound Connectivity

Outbound HTTPS connectivity was tested from `Dev-app01`:

```bash
curl -I https://www.microsoft.com
```

The successful response confirmed that the private workload could establish outbound HTTPS connections.

`Dev-app01` therefore remained private from an inbound administrative perspective while retaining required outbound connectivity.

---

## DNS Resolution

DNS resolution was also tested from the private VM.

```bash
nslookup microsoft.com
```

Successful name resolution validated DNS functionality from the development workload.

Azure's platform virtual IP:

```text
168.63.129.16
```

provides several Azure platform services, including DNS functionality when Azure-provided DNS is being used.

---

## VM Lifecycle

The management VM was deallocated to validate VM lifecycle operations and reduce unnecessary lab compute usage.

```bash
az vm deallocate --resource-group "HomeLab_RG" --name "Prod-mgmt01"
```

The VM was later started again:

```bash
az vm start --resource-group "HomeLab_RG" --name "Prod-mgmt01"
```

Its power state was verified using:

```bash
az vm get-instance-view --resource-group "HomeLab_RG" --name "Prod-mgmt01" --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" -o tsv
```

SSH connectivity was revalidated after the VM returned to a running state.

---

# Troubleshooting

Only troubleshooting events that materially affected the implementation or demonstrated useful diagnostic reasoning are included here.

---

## VM Deployment Failed Due to Unsupported VM Size

### Issue

During the initial VM deployment, the requested VM size was not available for the selected configuration/region.

The VM creation operation failed rather than completing successfully.

### Investigation

Instead of changing the network configuration, the deployment failure was reviewed to determine whether the problem originated from:

```text
VNet/Subnet
Authentication
VM Image
VM Size / Regional Availability
```

The existing VNet and subnet resources were already present and had previously been validated.

The deployment error pointed to the selected VM SKU rather than the network configuration.

Available VM sizes were reviewed before retrying the deployment.

### Root Cause

The originally selected VM size was not available for the deployment in the target Azure region/environment.

The problem was therefore a compute SKU availability issue rather than a VNet, subnet, NIC, NSG, or SSH configuration problem.

### Resolution

A supported low-cost VM size was selected and the deployment was retried.

The resulting VMs were successfully provisioned using:

```text
Standard_D2als_v7
```

After deployment, the VM configuration was verified with Azure CLI.

```bash
az vm show --resource-group "HomeLab_RG" --name "Prod-mgmt01" -d -o table
```

### Lesson Learned

Azure VM SKU availability can vary by region, subscription, capacity, and deployment constraints.

When a VM deployment fails, the deployment error should be evaluated before modifying unrelated infrastructure.

The troubleshooting process helped distinguish a **compute provisioning problem** from a **network configuration problem**.

---

## SSH Key Directory Did Not Exist

### Issue

Before generating the SSH key, the local SSH directory was checked:

```bash
ls -la ~/.ssh
```

The command returned:

```text
ls: /Users/ev/.ssh: No such file or directory
```

### Investigation

The error occurred locally before Azure resources or network connectivity were involved.

The workstation had not previously generated an SSH key pair.

### Resolution

An Ed25519 SSH key pair was generated:

```bash
ssh-keygen -t ed25519 -C "azure-homelab"
```

`ssh-keygen` created the required `.ssh` directory and generated the public/private key pair.

### Lesson Learned

The location of an error is an important troubleshooting clue.

This failure belonged to the local SSH configuration layer and did not require any changes to Azure infrastructure.

---

## SSH Authentication Failed Between VMs

### Issue

SSH access from the Mac to `Prod-mgmt01` succeeded.

The second SSH connection from `Prod-mgmt01` to `Dev-app01` failed with:

```text
Permission denied (publickey)
```

The path was:

```text
Mac
 │
 ▼
Prod-mgmt01
 │
 X
 ▼
Dev-app01
```

### Investigation

Before modifying the NSGs or VNet peering, TCP connectivity was evaluated.

`Prod-mgmt01` could reach `Dev-app01`, and TCP/22 was available.

This established that:

```text
Network Path       → Working
VNet Peering       → Working
Routing            → Working
NSG                → Allowing SSH
TCP/22             → Reachable
SSH Authentication → Failing
```

Because the SSH server returned:

```text
Permission denied (publickey)
```

the connection had reached the remote SSH service.

The problem was therefore investigated as an authentication failure.

The local SSH agent was checked:

```bash
ssh-add -l
```

The required SSH identity was not loaded.

### Root Cause

The Ed25519 private key existed on the Mac but was not loaded into the local SSH agent.

SSH agent forwarding therefore had no identity available to forward to `Prod-mgmt01`.

```text
Mac
│
│ SSH key exists
│ but is not loaded
│
▼
SSH Agent
│
│ No usable identity
│
▼
Prod-mgmt01
│
X
Dev-app01
```

### Resolution

The private key was loaded into the SSH agent:

```bash
ssh-add ~/.ssh/id_ed25519
```

The identity was verified:

```bash
ssh-add -l
```

The management VM was then accessed with agent forwarding enabled:

```bash
ssh -A <USERNAME>@<PROD-MGMT01-PUBLIC-IP>
```

From `Prod-mgmt01`, the forwarded identity was verified:

```bash
ssh-add -l
```

SSH to the private application VM was retried:

```bash
ssh <USERNAME>@10.20.1.4
```

The connection succeeded.

The working authentication path became:

```text
Mac
│
│ id_ed25519
│ loaded into SSH agent
│
│ ssh -A
▼
Prod-mgmt01
│
│ Forwarded SSH identity
│
│ TCP/22
▼
Dev-app01
```

### Lesson Learned

The error message helped identify the correct troubleshooting layer.

```text
Connection timed out
```

would suggest investigating networking, routing, or filtering.

```text
Permission denied (publickey)
```

indicates that the SSH service was reached but authentication failed.

Recognizing this distinction prevented unnecessary changes to working NSGs, routes, and VNet peering.

---

# Lessons Learned

## Validate Each Infrastructure Layer Independently

The environment was validated progressively rather than assuming that successful VM deployment meant the complete architecture was working.

```text
VM
 ↓
NIC
 ↓
Subnet
 ↓
NSG
 ↓
VNet
 ↓
VNet Peering
 ↓
Effective Routes
 ↓
TCP
 ↓
SSH
 ↓
Authentication
 ↓
DNS
 ↓
Outbound Connectivity
```

Breaking the environment into layers made it easier to determine where failures occurred.

---

## Deployment Errors Do Not Always Indicate Network Problems

The VM deployment issue originated from compute SKU availability rather than the existing Azure network.

Reviewing the actual deployment failure before modifying resources prevented unnecessary changes to previously validated infrastructure.

---

## Network Connectivity and Authentication Are Different Problems

The `Permission denied (publickey)` failure occurred after the network connection had already reached `Dev-app01`.

Separating transport connectivity from authentication made the root cause significantly easier to identify.

---

## Keep Private SSH Keys Off Remote Servers

SSH agent forwarding allowed the private key to remain on the administrator workstation.

The key did not need to be copied onto `Prod-mgmt01` simply to access `Dev-app01`.

---

## Private Workloads Do Not Require Public Administrative Access

The final administrative path:

```text
Mac → Prod-mgmt01 → Dev-app01
```

allowed `Dev-app01` to remain without a public IP address while still supporting administrative access.

---

## Effective Routes Are Valuable During Azure Network Troubleshooting

The effective route:

```text
10.10.0.0/16 → VNetPeering
```

provided direct evidence that Azure recognized `HomeLab_VNet` as reachable through the VNet peering connection.

This provides a useful validation point before investigating higher-layer connectivity problems.

---

## Next Steps

The next phase will introduce the data-tier workload by deploying `Dev-data01` into `DataSubnet`.

The architecture will expand to:

```text
Administrator
     │
     ▼
Prod-mgmt01
     │
     │ VNet Peering
     ▼
Dev-app01
     │
     │ Controlled
     │ Application-to-Data
     │ Communication
     ▼
Dev-data01
```

Network Security Group rules will be used to control communication between the application and data tiers.

After the compute and network architecture has been fully validated, the core infrastructure will be rebuilt using Bicep to transition the environment from Azure CLI deployment toward declarative Infrastructure as Code.
