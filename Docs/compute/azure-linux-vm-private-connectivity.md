# Azure Linux VM Deployment & Private Connectivity

## Overview

This implementation extends the existing Azure network environment by deploying Linux virtual machines into the management and development networks.

The existing architecture already provided separate `HomeLab_VNet` and `Devlab_VNet` environments connected through VNet peering. Virtual machines were introduced to validate how compute resources communicate across the network and how administrative access can be provided to private workloads without assigning every VM a public IP address.

The implementation includes:

* Azure Linux virtual machines
* Network Interface Cards (NICs)
* private and public IP addressing
* Network Security Groups (NSGs)
* SSH public/private key authentication
* SSH agent forwarding
* private communication across VNet peering
* effective route validation
* outbound HTTPS and DNS testing
* VM lifecycle operations
* troubleshooting and validation

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
│               ├── Ubuntu 22.04 LTS
│               ├── Standard_D2als_v7
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
        │   ├── AppSubnet_NSG
        │   │
        │   └── Dev-app01
        │       ├── Ubuntu 22.04 LTS
        │       ├── Standard_D2als_v7
        │       ├── Private IP: 10.20.1.4
        │       └── No Public IP
        │
        └── DataSubnet
            │
            └── DataSubnet_NSG
```

The administrative path into the private development environment is:

```text
Administrator Mac
        │
        │ SSH
        ▼
   Prod-mgmt01
    10.10.0.4
        │
        │ TCP/22
        │ VNet Peering
        ▼
    Dev-app01
     10.20.1.4
```

---

## Design Decisions

### Separate Management and Development Workloads

The existing network architecture separates management infrastructure from development workloads.

`Prod-mgmt01` is deployed in:

```text
HomeLab_RG
└── HomeLab_VNet
    └── ManagementSubnet
```

`Dev-app01` is deployed separately in:

```text
DevLab_RG
└── Devlab_VNet
    └── AppSubnet
```

VNet peering provides private communication between the two environments while maintaining separate network boundaries.

This allows security policies to be applied independently to management and application workloads.

---

### Private Application VM

`Dev-app01` was intentionally deployed without a public IP address.

Instead of exposing the application VM directly to the Internet, administrative access follows the existing private network path:

```text
Mac → Prod-mgmt01 → Dev-app01
```

The management VM therefore serves as the administrative entry point for the private development workload.

---

### SSH Key Authentication

SSH public-key authentication was selected instead of password-based authentication.

The private key remains on the administrator workstation while the corresponding public key is installed on the Linux virtual machines.

SSH agent forwarding is used for the second connection from `Prod-mgmt01` to `Dev-app01`, avoiding the need to copy the private SSH key onto the management VM.

---

## SSH Key Configuration

Before deploying the virtual machines, the local SSH configuration was inspected.

```bash
ls -la ~/.ssh
```

The initial result was:

```text
ls: /Users/ev/.ssh: No such file or directory
```

The workstation did not yet contain an SSH directory or SSH key pair.

An Ed25519 SSH key pair was created:

```bash
ssh-keygen -t ed25519 -C "azure-homelab"
```

The default key location was accepted:

```text
/Users/ev/.ssh/id_ed25519
```

This generated:

```text
~/.ssh/id_ed25519
~/.ssh/id_ed25519.pub
```

The two files have different purposes:

| File             | Purpose                                                   |
| ---------------- | --------------------------------------------------------- |
| `id_ed25519`     | Private SSH key retained on the administrator workstation |
| `id_ed25519.pub` | Public SSH key installed on authorized Linux systems      |

The public key can be displayed using:

```bash
cat ~/.ssh/id_ed25519.pub
```

The private key should never be committed to GitHub or copied into project documentation.

---

## Virtual Machine Deployment

### Prod-mgmt01

`Prod-mgmt01` was deployed as the management VM in the existing `HomeLab_VNet`.

Configuration:

| Property         | Value               |
| ---------------- | ------------------- |
| Resource Group   | `HomeLab_RG`        |
| Virtual Network  | `HomeLab_VNet`      |
| Subnet           | `ManagementSubnet`  |
| VM Name          | `Prod-mgmt01`       |
| Operating System | Ubuntu 22.04 LTS    |
| VM Size          | `Standard_D2als_v7` |
| Private IP       | `10.10.0.4`         |
| Authentication   | SSH public key      |

The management VM provides the administrative path to private resources in the peered development environment.

VM information can be inspected using:

```bash
az vm show --resource-group "HomeLab_RG" --name "Prod-mgmt01" -d -o table
```

---

### Dev-app01

`Dev-app01` was deployed into the existing application subnet in `Devlab_VNet`.

Configuration:

| Property         | Value               |
| ---------------- | ------------------- |
| Resource Group   | `DevLab_RG`         |
| Virtual Network  | `Devlab_VNet`       |
| Subnet           | `AppSubnet`         |
| VM Name          | `Dev-app01`         |
| Operating System | Ubuntu 22.04 LTS    |
| VM Size          | `Standard_D2als_v7` |
| Private IP       | `10.20.1.4`         |
| Public IP        | None                |
| Authentication   | SSH public key      |

VM information can be inspected using:

```bash
az vm show --resource-group "DevLab_RG" --name "Dev-app01" -d -o table
```

Because `Dev-app01` does not have a public IP address, it is administered through `Prod-mgmt01`.

---

## Network Interface Configuration

Each Azure virtual machine communicates with its virtual network through a Network Interface Card.

The relationship between the resources is:

```text
Virtual Machine
      │
      ▼
Network Interface
      │
      ▼
Subnet
      │
      ▼
Virtual Network
```

The NIC contains the VM's Azure network configuration, including:

* private IP configuration
* subnet association
* optional public IP association
* effective Network Security Groups
* effective routes

NICs in the environment can be inspected using:

```bash
az network nic list -o table
```

The NIC attached to a specific VM can be identified using:

```bash
az vm show --resource-group "HomeLab_RG" --name "Prod-mgmt01" --query "networkProfile.networkInterfaces[].id" -o tsv
```

For the development VM:

```bash
az vm show --resource-group "DevLab_RG" --name "Dev-app01" --query "networkProfile.networkInterfaces[].id" -o tsv
```

The NIC configuration can then be inspected using:

```bash
az network nic show --resource-group "<RESOURCE_GROUP>" --name "<NIC_NAME>" -o table
```

Private IP configuration can be queried using:

```bash
az network nic show --resource-group "<RESOURCE_GROUP>" --name "<NIC_NAME>" --query "ipConfigurations[].{PrivateIP:privateIPAddress,Allocation:privateIPAllocationMethod,Subnet:subnet.id}" -o table
```

---

## Network Security Group Configuration

The existing subnet-level Network Security Groups were retained as part of the VM deployment.

The management and application workloads are protected by their respective subnet NSGs.

```text
ManagementSubnet
      │
      └── ManagementSubnet_NSG

AppSubnet
      │
      └── AppSubnet_NSG
```

For `Dev-app01`, SSH access was restricted to traffic originating from the management subnet.

### Allow-SSH-ManagementSubnet

The custom inbound rule was configured with:

| Property         | Value                        |
| ---------------- | ---------------------------- |
| Rule             | `Allow-SSH-ManagementSubnet` |
| Priority         | `100`                        |
| Direction        | Inbound                      |
| Protocol         | TCP                          |
| Source           | `10.10.0.0/24`               |
| Destination Port | `22`                         |
| Action           | Allow                        |

The traffic flow is:

```text
Prod-mgmt01
10.10.0.4
     │
     │ TCP/22
     ▼
AppSubnet_NSG
     │
     │ Allow-SSH-ManagementSubnet
     ▼
Dev-app01
10.20.1.4
```

Rather than allowing SSH from any Internet source, the rule limits administrative access to the management subnet.

The NSG rules can be inspected using:

```bash
az network nsg rule list --resource-group "DevLab_RG" --nsg-name "AppSubnet_NSG" -o table
```

---

## Private Connectivity Validation

After both virtual machines were deployed, connectivity was tested across the existing VNet peering.

The expected path was:

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
AppSubnet
      │
      ▼
Dev-app01
```

From `Prod-mgmt01`, TCP/22 connectivity to the private IP of `Dev-app01` was validated.

```bash
nc -zv 10.20.1.4 22
```

A successful TCP connection confirmed that the SSH service was reachable across the private Azure network.

SSH was then tested:

```bash
ssh <USERNAME>@10.20.1.4
```

This validated the combined operation of:

* VM networking
* NIC configuration
* subnet placement
* NSG rules
* VNet peering
* Azure routing
* TCP/22 connectivity
* SSH

---

## SSH Agent Forwarding

Because `Dev-app01` is private, SSH access requires a second connection from the management VM.

```text
Mac
 │
 ▼
Prod-mgmt01
 │
 ▼
Dev-app01
```

Copying the private SSH key to `Prod-mgmt01` would provide a way to authenticate to `Dev-app01`, but would also create another location where the private credential must be protected.

SSH agent forwarding was used instead.

First, the local SSH agent was checked:

```bash
ssh-add -l
```

The SSH private key can be loaded into the local agent using:

```bash
ssh-add ~/.ssh/id_ed25519
```

The identity can then be verified:

```bash
ssh-add -l
```

The management VM is accessed with SSH agent forwarding enabled:

```bash
ssh -A <USERNAME>@<PROD-MGMT01-PUBLIC-IP>
```

The `-A` option makes the local SSH agent available to the remote SSH session.

The private key itself remains on the Mac.

```text
Mac
│
│ Private Key
│ id_ed25519
│
│ ssh -A
▼
Prod-mgmt01
│
│ Forwarded SSH Agent
│
▼
Dev-app01
```

From `Prod-mgmt01`, the forwarded identity can be verified:

```bash
ssh-add -l
```

The private VM can then be accessed:

```bash
ssh <USERNAME>@10.20.1.4
```

The final administrative path is:

```text
Mac → Prod-mgmt01 → Dev-app01
```

---

## Effective Route Validation

Successful communication also required Azure to have a valid route between the two VNet address spaces.

Effective routes were inspected for the development VM's NIC.

```bash
az network nic show-effective-route-table --resource-group "DevLab_RG" --name "<DEV-APP01-NIC>" -o table
```

The effective routes showed the management network as reachable through VNet peering:

```text
10.10.0.0/16 → VNetPeering
```

The routing path can therefore be represented as:

```text
Dev-app01
     │
     │ Destination: 10.10.0.0/16
     ▼
VNetPeering
     │
     ▼
HomeLab_VNet
```

This confirmed that Azure recognized the remote VNet address space and selected the peering connection as the next hop.

---

## Reverse Connectivity Validation

Connectivity was also tested from the development environment back toward the management environment.

Testing included:

* ICMP connectivity
* TCP/22 connectivity

This helped verify that private communication was functioning across the peering relationship in both directions.

---

## Outbound HTTPS Validation

Outbound connectivity from `Dev-app01` was tested even though the VM did not have a public IP address.

```bash
curl -I https://www.microsoft.com
```

A successful response confirmed outbound HTTPS connectivity from the private workload.

This also demonstrated an important networking distinction:

```text
No Public IP ≠ No Outbound Connectivity
```

A VM does not require direct inbound Internet exposure simply to communicate with external services.

---

## Azure DNS Validation

Azure-provided DNS was also validated from the development VM.

Azure provides the virtual IP:

```text
168.63.129.16
```

DNS configuration can be inspected from Linux using:

```bash
cat /etc/resolv.conf
```

Name resolution can be tested using:

```bash
nslookup microsoft.com
```

Successful DNS resolution confirmed that the VM could resolve external hostnames while operating as a private workload.

---

## VM Lifecycle Validation

VM lifecycle operations were tested on `Prod-mgmt01` after deployment.

The current VM power state can be queried using:

```bash
az vm get-instance-view --resource-group "HomeLab_RG" --name "Prod-mgmt01" --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" -o tsv
```

The VM was deallocated:

```bash
az vm deallocate --resource-group "HomeLab_RG" --name "Prod-mgmt01"
```

The VM was subsequently started again:

```bash
az vm start --resource-group "HomeLab_RG" --name "Prod-mgmt01"
```

SSH connectivity was revalidated after the VM returned to a running state.

Testing the VM lifecycle was also important for managing lab costs because compute charges stop when an Azure VM is fully deallocated, although attached resources such as disks may continue to incur charges.

---

# Troubleshooting

## SSH Directory Did Not Exist

### Issue

Before generating the SSH key pair, the local SSH directory was inspected:

```bash
ls -la ~/.ssh
```

The command returned:

```text
ls: /Users/ev/.ssh: No such file or directory
```

### Investigation

The error was local to the administrator workstation rather than an Azure infrastructure issue.

No SSH keys had previously been generated for the local user, so the `.ssh` directory did not yet exist.

### Resolution

An Ed25519 SSH key pair was generated:

```bash
ssh-keygen -t ed25519 -C "azure-homelab"
```

The default location was accepted:

```text
/Users/ev/.ssh/id_ed25519
```

`ssh-keygen` created the required `.ssh` directory and generated both the private and public keys.

### Lesson Learned

Infrastructure troubleshooting should begin by identifying which layer produced the error.

In this case, the failure occurred before Azure networking or authentication was involved. The issue was limited to the local SSH configuration.

---

## Second-Hop SSH Authentication Failure

### Issue

The initial connection from the Mac to `Prod-mgmt01` succeeded.

The second connection from `Prod-mgmt01` to `Dev-app01`, however, failed with:

```text
Permission denied (publickey)
```

The failing path was:

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

Before modifying the Azure network configuration, the failure was separated into network connectivity and authentication.

`Prod-mgmt01` could reach `Dev-app01`, and TCP/22 was reachable.

The SSH server was therefore responding.

That indicated the failure was occurring during authentication rather than network transport.

The local SSH agent was inspected:

```bash
ssh-add -l
```

The required Ed25519 identity was not loaded into the agent.

Agent forwarding cannot forward an identity that is not available to the local SSH agent.

### Root Cause

The SSH private key existed on the Mac, but it had not been loaded into the SSH agent.

The authentication path therefore looked like:

```text
Mac SSH Agent
     │
     │ No SSH Identity
     X
Prod-mgmt01
     │
     X
Dev-app01
```

The Azure networking configuration was functioning correctly.

### Resolution

The private key was added to the local SSH agent:

```bash
ssh-add ~/.ssh/id_ed25519
```

The identity was verified:

```bash
ssh-add -l
```

The connection to the management VM was then re-established with agent forwarding:

```bash
ssh -A <USERNAME>@<PROD-MGMT01-PUBLIC-IP>
```

From `Prod-mgmt01`, the forwarded identity was verified:

```bash
ssh-add -l
```

SSH to the development VM was retried:

```bash
ssh <USERNAME>@10.20.1.4
```

Authentication succeeded.

The corrected authentication path became:

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
│ Forwarded identity
│
│ TCP/22 across VNet peering
▼
Dev-app01
```

### Lesson Learned

The SSH error provided an important clue:

```text
Permission denied (publickey)
```

The SSH server had already been reached. This was different from a connection timeout or unreachable host.

The troubleshooting process therefore focused on authentication before making unnecessary changes to:

* NSGs
* VNet peering
* Azure routes
* subnet configuration
* VM networking

The troubleshooting sequence became:

```text
Can Prod-mgmt01 reach Dev-app01?
              │
             Yes
              │
              ▼
Is TCP/22 reachable?
              │
             Yes
              │
              ▼
Is SSH responding?
              │
             Yes
              │
              ▼
Authentication failure
              │
              ▼
Check SSH agent
              │
              ▼
Identity missing
              │
              ▼
ssh-add ~/.ssh/id_ed25519
              │
              ▼
Reconnect with ssh -A
              │
              ▼
Verify forwarded identity
              │
              ▼
SSH succeeds
```

---

## Validation Summary

The final environment was validated at multiple infrastructure layers.

| Validation                         | Result     |
| ---------------------------------- | ---------- |
| `Prod-mgmt01` deployment           | Successful |
| `Dev-app01` deployment             | Successful |
| Management VM SSH access           | Successful |
| `Prod-mgmt01 → Dev-app01` TCP/22   | Successful |
| `Prod-mgmt01 → Dev-app01` SSH      | Successful |
| SSH agent forwarding               | Successful |
| Reverse private connectivity       | Successful |
| VNet peering routing               | Successful |
| `10.10.0.0/16 → VNetPeering` route | Verified   |
| Outbound HTTPS from `Dev-app01`    | Successful |
| Azure DNS resolution               | Successful |
| VM deallocation                    | Successful |
| VM restart                         | Successful |
| SSH after lifecycle testing        | Successful |

---

## Lessons Learned

### Validate Infrastructure by Layer

A successful Azure deployment does not necessarily mean that application or administrative connectivity is functioning.

Validation was performed across:

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
Effective Route
 ↓
TCP/22
 ↓
SSH
 ↓
Authentication
 ↓
DNS
 ↓
Outbound Connectivity
```

This approach made it easier to isolate failures without changing unrelated infrastructure.

### Network Connectivity and Authentication Are Separate

The `Permission denied (publickey)` error initially occurred after network connectivity had already succeeded.

Recognizing the difference prevented unnecessary changes to Azure networking resources.

### Private Workloads Do Not Require Direct Administrative Exposure

`Dev-app01` was successfully administered through:

```text
Mac → Prod-mgmt01 → Dev-app01
```

without assigning a public IP address to the application VM.

### Keep Private Keys Local

SSH agent forwarding allowed authentication to the private VM without copying `id_ed25519` onto `Prod-mgmt01`.

The private key remained on the administrator workstation while the management VM temporarily accessed the forwarded SSH identity.

### Effective Routes Provide Important Troubleshooting Evidence

Verifying:

```text
10.10.0.0/16 → VNetPeering
```

confirmed that Azure understood how traffic from the development network should reach the management network.

Effective routes provide a useful validation point when troubleshooting connectivity across Azure networks.

---

## Next Steps

The next phase will extend the development environment by introducing the data tier.

`Dev-data01` will be deployed into `DataSubnet` and used to validate controlled communication between application and data workloads.

The architecture will evolve toward:

```text
Administrator Mac
        │
        ▼
   Prod-mgmt01
        │
        │ VNet Peering
        ▼
    Dev-app01
        │
        │ Controlled Application
        │ to Data Communication
        ▼
   Dev-data01
```

Network Security Group rules will be used to control which traffic is permitted between the application and data tiers.

After the core infrastructure is complete and validated, the environment will be rebuilt using Bicep to transition the deployment from manual Azure CLI operations to declarative Infrastructure as Code.

