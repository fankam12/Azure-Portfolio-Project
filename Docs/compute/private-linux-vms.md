# Private Linux VMs

## Overview

This implementation extends the existing Azure networking environment by deploying Linux virtual machines across management, application, and data tiers.

The existing infrastructure already separated management and development resources using peered Azure virtual networks.

Compute resources were introduced to validate how workloads behave across those network boundaries and how subnet-level Network Security Groups can be used to enforce controlled communication between tiers.

Three Ubuntu Linux virtual machines were deployed:

* `Prod-mgmt01` — management VM
* `Dev-app01` — private application VM
* `Dev-data01` — private data-tier VM

The implementation also introduced SSH public-key authentication, Network Interface Cards, private administrative access, SSH agent forwarding, subnet-level security controls, application-to-data segmentation, effective route validation, effective NSG validation, DNS testing, outbound connectivity testing, VM lifecycle management, and deployment troubleshooting.

---

# Architecture

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
│               └── Public administrative endpoint
│
│                         ⇅
│                    VNet Peering
│                         ⇅
│
└── DevLab_RG
    │
    └── Development VNet
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
            ├── DataSubnet_NSG
            │
            └── Dev-data01
                │
                ├── Ubuntu Linux
                ├── NIC
                ├── Private IP: 10.20.2.4
                └── No Public IP
```

---

# Design

## Management Tier

`Prod-mgmt01` was deployed into `ManagementSubnet` within `HomeLab_VNet`.

The VM provides the administrative entry point for workloads that should not require direct public exposure.

```text
Administrator
     │
     │ SSH
     ▼
Prod-mgmt01
10.10.0.4
```

The management VM also provides administrative access to private resources in the development environment through VNet peering.

```text
Administrator
     │
     ▼
Prod-mgmt01
     │
     │ Private Connectivity
     │ VNet Peering
     ▼
Development Workloads
```

---

## Application Tier

`Dev-app01` was deployed into `AppSubnet`.

The VM was intentionally deployed without a public IP address.

| Configuration    | Value          |
| ---------------- | -------------- |
| VM               | `Dev-app01`    |
| Resource Group   | `DevLab_RG`    |
| Subnet           | `AppSubnet`    |
| Private IP       | `10.20.1.4`    |
| Public IP        | None           |
| Operating System | Ubuntu Linux   |
| Authentication   | SSH Public Key |

Administrative access follows:

```text
Administrator
     │
     ▼
Prod-mgmt01
     │
     │ VNet Peering
     │ TCP/22
     ▼
Dev-app01
10.20.1.4
```

This allows the application workload to remain private while still being administratively reachable from the management tier.

---

## Data Tier

`Dev-data01` was deployed into `DataSubnet`.

The VM was also intentionally deployed without a public IP address.

| Configuration    | Value               |
| ---------------- | ------------------- |
| VM               | `Dev-data01`        |
| Resource Group   | `DevLab_RG`         |
| VNet             | `Devlab_VNet`       |
| Subnet           | `DataSubnet`        |
| Private IP       | `10.20.2.4`         |
| Public IP        | None                |
| VM Size          | `Standard_D2als_v7` |
| Operating System | Ubuntu Linux        |
| Authentication   | SSH Public Key      |

The data-tier VM is administratively reachable from the management subnet but is intentionally restricted from unnecessary application-tier access.

```text
Prod-mgmt01
10.10.0.4
     │
     │ TCP/22
     │ Allowed
     ▼
Dev-data01
10.20.2.4
```

Application-to-data communication follows a different policy:

```text
Dev-app01
10.20.1.4
     │
     │ TCP/5432
     │ Allowed
     ▼
Dev-data01
10.20.2.4
```

Other direct traffic from `AppSubnet` to `DataSubnet` is explicitly denied.

---

# SSH Key Configuration

SSH public-key authentication was used instead of password authentication.

Before generating the key, the existing SSH configuration was checked:

```bash
ls -la ~/.ssh
```

The workstation initially returned:

```text
ls: /Users/ev/.ssh: No such file or directory
```

No SSH directory or existing key pair was present.

An Ed25519 key pair was generated:

```bash
ssh-keygen -t ed25519 -C "azure-homelab"
```

The default key location was accepted:

```text
~/.ssh/id_ed25519
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

is installed on the Azure Linux virtual machines for SSH authentication.

The public key can be displayed with:

```bash
cat ~/.ssh/id_ed25519.pub
```

> The private SSH key is not stored in this repository and should never be committed to source control.

---

# Virtual Machine Deployment

## Prod-mgmt01

The management VM was deployed into the existing management network.

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

## Dev-app01

The application VM was deployed into the existing development network.

| Configuration    | Value          |
| ---------------- | -------------- |
| VM               | `Dev-app01`    |
| Resource Group   | `DevLab_RG`    |
| Subnet           | `AppSubnet`    |
| Operating System | Ubuntu Linux   |
| Private IP       | `10.20.1.4`    |
| Public IP        | None           |
| Authentication   | SSH Public Key |

VM configuration can be reviewed with:

```bash
az vm show --resource-group "DevLab_RG" --name "Dev-app01" -d -o table
```

The VM has no public IP, so administrative access originates from the management environment.

---

## Dev-data01

Before deployment, the environment was checked to confirm that a VM named `Dev-data01` did not already exist.

```bash
az vm show --resource-group "DevLab_RG" --name "Dev-data01" -o table
```

Azure returned:

```text
ResourceNotFound
```

The target subnet and NSG association were then verified:

```bash
az network vnet subnet show --resource-group "DevLab_RG" --vnet-name "Devlab_VNet" --name "DataSubnet" --query "{Subnet:name,Prefix:addressPrefix,NSG:networkSecurityGroup.id}" -o table
```

The validated subnet configuration was:

```text
DataSubnet
10.20.2.0/24
DataSubnet_NSG
```

The data VM was deployed with:

```bash
az vm create --resource-group "DevLab_RG" --name "Dev-data01" --location "eastus" --image "Ubuntu2204" --size "Standard_D2als_v7" --vnet-name "Devlab_VNet" --subnet "DataSubnet" --admin-username "<USERNAME>" --ssh-key-values ~/.ssh/id_ed25519.pub --public-ip-address "" --nsg "" --os-disk-delete-option Delete --nic-delete-option Delete
```

The deployment returned:

```text
VM:         Dev-data01
Power:      VM running
Private IP: 10.20.2.4
Public IP:  None
```

The empty public IP configuration ensured that the data-tier workload remained privately addressed.

The `--nsg ""` option prevented VM deployment from creating an additional VM-level NSG because security was already enforced at the subnet level.

---

# Network Interface Cards

Each virtual machine connects to Azure's software-defined network through a Network Interface Card.

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

The NIC configuration provides:

* private IP addressing
* subnet association
* public IP association when applicable
* effective security rules
* effective route information

NICs can be reviewed with:

```bash
az network nic list -o table
```

The NIC associated with a specific VM can be identified from the VM network profile.

For `Prod-mgmt01`:

```bash
az vm show --resource-group "HomeLab_RG" --name "Prod-mgmt01" --query "networkProfile.networkInterfaces[].id" -o tsv
```

For `Dev-app01`:

```bash
az vm show --resource-group "DevLab_RG" --name "Dev-app01" --query "networkProfile.networkInterfaces[].id" -o tsv
```

For `Dev-data01`:

```bash
az vm show --resource-group "DevLab_RG" --name "Dev-data01" --query "networkProfile.networkInterfaces[].id" -o tsv
```

`Dev-data01` was associated with:

```text
Dev-data01VMNic
```

and received:

```text
10.20.2.4
```

---

# Network Security

Subnet-level Network Security Groups provide traffic filtering for the management, application, and data tiers.

```text
ManagementSubnet
      │
      └── ManagementSubnet_NSG

AppSubnet
      │
      └── AppSubnet_NSG

DataSubnet
      │
      └── DataSubnet_NSG
```

---

## Application Tier SSH Policy

SSH access to `Dev-app01` is restricted to the management subnet.

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

The rule uses the management subnet as the trusted source.

```text
Source:   10.10.0.0/24
Protocol: TCP
Port:     22
Action:   Allow
```

The configured rules can be inspected with:

```bash
az network nsg rule list --resource-group "DevLab_RG" --nsg-name "AppSubnet_NSG" --include-default -o table
```

---

## Data Tier Management Access

`DataSubnet_NSG` initially contained only Azure default rules.

A dedicated SSH rule was added so that administrative access to `Dev-data01` could originate from `ManagementSubnet`.

```bash
az network nsg rule create --resource-group "DevLab_RG" --nsg-name "DataSubnet_NSG" --name "Allow-SSH-ManagementSubnet" --priority 100 --direction Inbound --access Allow --protocol Tcp --source-address-prefixes "10.10.0.0/24" --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges "22"
```

The resulting policy was:

```text
Priority:    100
Source:      10.10.0.0/24
Protocol:    TCP
Port:        22
Action:      Allow
```

---

## Application-to-Data Segmentation

Initial testing showed that `Dev-app01` could reach `Dev-data01` using both ICMP and TCP/22.

```text
Dev-app01 → Dev-data01 ICMP   Allowed
Dev-app01 → Dev-data01 SSH    Allowed
```

This occurred because the default `AllowVnetInBound` rule permitted broad virtual network communication.

Separate subnets therefore did not by themselves provide the required workload isolation.

An explicit database communication rule was created:

```bash
az network nsg rule create --resource-group "DevLab_RG" --nsg-name "DataSubnet_NSG" --name "Allow-PostgreSQL-AppSubnet" --priority 110 --direction Inbound --access Allow --protocol Tcp --source-address-prefixes "10.20.1.0/24" --source-port-ranges "*" --destination-address-prefixes "10.20.2.0/24" --destination-port-ranges "5432"
```

A second rule denied all other inbound traffic from `AppSubnet` to `DataSubnet`.

```bash
az network nsg rule create --resource-group "DevLab_RG" --nsg-name "DataSubnet_NSG" --name "Deny-AppSubnet-Other-Inbound" --priority 120 --direction Inbound --access Deny --protocol "*" --source-address-prefixes "10.20.1.0/24" --source-port-ranges "*" --destination-address-prefixes "10.20.2.0/24" --destination-port-ranges "*"
```

The resulting custom policy became:

```text
100  Allow-SSH-ManagementSubnet      Allow  TCP  10.10.0.0/24 → TCP/22
110  Allow-PostgreSQL-AppSubnet      Allow  TCP  10.20.1.0/24 → TCP/5432
120  Deny-AppSubnet-Other-Inbound    Deny   ALL  10.20.1.0/24 → DataSubnet
```

The lower priority numbers ensure that the explicit workload rules are evaluated before Azure's default inbound virtual network rule.

---

# Validation

## VM Deployment

The deployed virtual machines can be reviewed using:

```bash
az vm list -d -o table
```

The expected compute architecture is:

```text
Prod-mgmt01
Dev-app01
Dev-data01
```

---

## Private IP Addressing

`Prod-mgmt01`:

```text
10.10.0.4
```

`Dev-app01`:

```text
10.20.1.4
```

`Dev-data01`:

```text
10.20.2.4
```

The addresses place each workload within its intended network tier.

---

## Dev-data01 Guest Networking

After connecting to the data VM, the hostname was confirmed:

```bash
hostname
```

Result:

```text
Dev-data01
```

The Linux network interfaces were reviewed with:

```bash
ip addr
```

The primary interface showed:

```text
eth0
10.20.2.4/24
```

This confirmed that the guest operating system network configuration matched the Azure NIC configuration.

---

## Management-to-Application Connectivity

From `Prod-mgmt01`, TCP/22 connectivity to the application VM was tested:

```bash
nc -zv 10.20.1.4 22
```

Private SSH connectivity was then validated:

```bash
ssh <USERNAME>@10.20.1.4
```

The successful connection validated:

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
Development VNet
      │
      ▼
AppSubnet_NSG
      │
      ▼
Dev-app01
```

---

## Management-to-Data Connectivity

From `Prod-mgmt01`, TCP/22 connectivity to `Dev-data01` was tested:

```bash
nc -zv 10.20.2.4 22
```

Result:

```text
Connection to 10.20.2.4 22 port [tcp/ssh] succeeded!
```

SSH was then validated:

```bash
ssh <USERNAME>@10.20.2.4
```

The connection succeeded.

This confirmed that the priority `100` NSG rule successfully preserved administrative access from `ManagementSubnet`.

---

## Application-to-Data Baseline

Before the data-tier NSG was hardened, connectivity from `Dev-app01` to `Dev-data01` was tested.

ICMP:

```bash
ping -c 4 10.20.2.4
```

Result:

```text
4 packets transmitted
4 received
0% packet loss
```

TCP/22:

```bash
nc -zv 10.20.2.4 22
```

Result:

```text
Connection to 10.20.2.4 22 port [tcp/ssh] succeeded!
```

This provided a baseline demonstrating that the Azure default VNet rule allowed broader communication than required by the target architecture.

---

## Application-to-Data Segmentation

After applying the custom NSG rules, the tests were repeated.

ICMP:

```bash
ping -c 4 10.20.2.4
```

Result:

```text
4 packets transmitted
0 received
100% packet loss
```

TCP/22:

```bash
nc -zv -w 5 10.20.2.4 22
```

Result:

```text
Connection timed out
```

The failed tests were expected and confirmed that the explicit deny rule was taking effect.

The resulting behavior was:

```text
Prod-mgmt01 → Dev-data01 TCP/22   Allowed

Dev-app01 → Dev-data01 ICMP       Denied
Dev-app01 → Dev-data01 TCP/22     Denied
Dev-app01 → Dev-data01 TCP/5432   Allowed
```

---

## TCP/5432 Validation

A temporary listener was started on `Dev-data01` to validate the allowed application-to-data path without installing a full database platform.

On `Dev-data01`:

```bash
nc -lv 5432
```

From `Dev-app01`:

```bash
nc -zv -w 5 10.20.2.4 5432
```

The connection succeeded.

The temporary listener was stopped after testing.

This demonstrated that the NSG did not simply block all application-to-data traffic.

Instead, it enforced the intended policy:

```text
AppSubnet
     │
     │ TCP/5432
     ▼
DataSubnet
     │
     ▼
ALLOW
```

while other application-tier traffic remained denied.

---

## Effective Routes

Effective routes were inspected on `Dev-data01VMNic`:

```bash
az network nic show-effective-route-table --resource-group "DevLab_RG" --name "Dev-data01VMNic" -o table
```

The important active routes included:

```text
10.20.0.0/16 → VnetLocal
10.10.0.0/16 → VNetPeering
0.0.0.0/0    → Internet
```

The route:

```text
10.10.0.0/16 → VNetPeering
```

confirmed that Azure recognized the management network as reachable through VNet peering.

The `10.20.0.0/16 → VnetLocal` route confirmed that development network traffic remained local to the development VNet.

---

## Effective NSG Rules

Effective NSG rules were inspected directly from `Dev-data01VMNic`.

```bash
az network nic list-effective-nsg --resource-group "DevLab_RG" --name "Dev-data01VMNic" --query "value[].effectiveSecurityRules[].{Name:name,Priority:priority,Direction:direction,Access:access,Protocol:protocol,Source:sourceAddressPrefix,Destination:destinationAddressPrefix,DestinationPort:destinationPortRange}" -o table
```

The effective custom rules were:

```text
100  Allow-SSH-ManagementSubnet
110  Allow-PostgreSQL-AppSubnet
120  Deny-AppSubnet-Other-Inbound
```

This validated that the intended subnet security configuration was not only present on `DataSubnet_NSG`, but was effective on the VM network interface.

---

## Outbound Connectivity

Outbound HTTPS connectivity was tested from the private workloads.

```bash
curl -I https://www.microsoft.com
```

`Dev-data01` returned:

```text
HTTP/2 200
```

This confirmed that the private workload could establish outbound HTTPS connections while remaining inaccessible through a direct public IP.

---

## DNS Resolution

DNS resolution was tested using:

```bash
nslookup microsoft.com
```

The lookup successfully returned IP addresses for `microsoft.com`.

The Ubuntu guest displayed:

```text
127.0.0.53
```

as its local stub resolver.

Successful name resolution confirmed that DNS functionality was operating correctly from the private workload.

---

## VM Lifecycle

VM lifecycle operations were tested to validate administrative control and support cost-conscious lab operation.

A VM was deallocated using:

```bash
az vm deallocate --resource-group "DevLab_RG" --name "Dev-data01"
```

The power state was verified:

```bash
az vm get-instance-view --resource-group "DevLab_RG" --name "Dev-data01" --query "instanceView.statuses[].{Code:code,DisplayStatus:displayStatus}" -o table
```

The VM reported:

```text
PowerState/deallocated
```

The VM was restarted:

```bash
az vm start --resource-group "DevLab_RG" --name "Dev-data01"
```

The state was validated again:

```bash
az vm get-instance-view --resource-group "DevLab_RG" --name "Dev-data01" --query "instanceView.statuses[].{Code:code,DisplayStatus:displayStatus}" -o table
```

The VM returned to:

```text
PowerState/running
```

Its network configuration was then reviewed:

```bash
az vm show --resource-group "DevLab_RG" --name "Dev-data01" -d --query "{VM:name,PrivateIP:privateIps,PublicIP:publicIps,PowerState:powerState}" -o table
```

The private address remained:

```text
10.20.2.4
```

---

# Troubleshooting

Only troubleshooting events that materially affected the implementation or demonstrate useful infrastructure diagnostic reasoning are included here.

---

## VM Deployment Failed Due to Unsupported VM Size

### Issue

During an earlier VM deployment, the requested VM size was unavailable for the selected Azure region or subscription configuration.

### Investigation

The deployment failure was reviewed before changing unrelated infrastructure.

Potential layers included:

```text
VNet/Subnet
Authentication
VM Image
VM Size / Capacity
```

The existing network resources had already been validated.

The deployment error instead pointed to compute SKU availability.

### Root Cause

The requested VM SKU was unavailable for the deployment.

The failure was therefore a compute provisioning problem rather than a VNet, subnet, NSG, NIC, or SSH problem.

### Resolution

A supported low-cost size was selected:

```text
Standard_D2als_v7
```

The VM deployment then completed successfully.

### Lesson Learned

Azure deployment failures should be diagnosed at the layer identified by the error before modifying previously validated infrastructure.

A compute provisioning error does not automatically indicate a networking problem.

---

## SSH Key Directory Did Not Exist

### Issue

The local SSH configuration was checked:

```bash
ls -la ~/.ssh
```

The command returned:

```text
ls: /Users/ev/.ssh: No such file or directory
```

### Investigation

The failure occurred on the administrator workstation before any Azure networking or VM connectivity was involved.

### Root Cause

The workstation did not yet have an SSH key pair or `.ssh` directory.

### Resolution

An Ed25519 key pair was generated:

```bash
ssh-keygen -t ed25519 -C "azure-homelab"
```

The required SSH directory and key files were created automatically.

### Lesson Learned

The location of an error helps identify the correct troubleshooting domain.

A local SSH configuration issue should not trigger changes to Azure networking resources.

---

## SSH Authentication Failed Between VMs

### Issue

SSH from the administrator workstation to `Prod-mgmt01` succeeded.

The second connection from `Prod-mgmt01` to `Dev-app01` failed with:

```text
Permission denied (publickey)
```

### Investigation

TCP/22 connectivity was tested before modifying Azure networking.

The management VM could reach `Dev-app01`, confirming:

```text
Network Path       → Working
VNet Peering       → Working
Routing            → Working
NSG                → Working
TCP/22             → Reachable
SSH Authentication → Failing
```

The SSH agent was inspected:

```bash
ssh-add -l
```

The required identity was not loaded.

### Root Cause

The Ed25519 private key existed on the administrator workstation but had not been loaded into the local SSH agent.

SSH agent forwarding therefore had no identity available to forward.

### Resolution

The key was loaded:

```bash
ssh-add ~/.ssh/id_ed25519
```

The identity was verified:

```bash
ssh-add -l
```

The management VM was accessed using agent forwarding:

```bash
ssh -A <USERNAME>@<PROD-MGMT01-PUBLIC-IP>
```

The forwarded identity was verified from `Prod-mgmt01`:

```bash
ssh-add -l
```

SSH to `Dev-app01` was then retried:

```bash
ssh <USERNAME>@10.20.1.4
```

The connection succeeded.

### Lesson Learned

```text
Connection timed out
```

typically points toward transport, routing, or filtering.

```text
Permission denied (publickey)
```

means the SSH service was reached but authentication failed.

Recognizing that difference prevented unnecessary changes to working NSGs and VNet peering.

---

## Existing VM Name Caused Deployment Failure

### Issue

While continuing the compute deployment, an `az vm create` command was accidentally executed using the existing VM name:

```text
Dev-app01
```

The command specified a different administrator username than the existing VM.

Azure returned:

```text
PropertyChangeNotAllowed
```

with:

```text
Changing property 'osProfile.adminUsername' is not allowed.
```

### Investigation

The existing VM was inspected:

```bash
az vm show --resource-group "DevLab_RG" --name "Dev-app01" --query "{VMName:name,AdminUsername:osProfile.adminUsername,VMSize:hardwareProfile.vmSize,ProvisioningState:provisioningState}" -d -o table
```

The VM already existed and was successfully provisioned.

Its network profile was then inspected:

```bash
az vm show --resource-group "DevLab_RG" --name "Dev-app01" --query "networkProfile.networkInterfaces[].id" -o tsv
```

This identified the NIC actually attached to the running VM.

### Root Cause

The deployment command targeted an existing VM name and attempted to modify an immutable operating-system profile property.

The problem was not caused by networking or SSH configuration.

### Resolution

The existing `Dev-app01` VM was preserved.

The deployment workflow was corrected to target the intended new VM:

```text
Dev-data01
```

### Lesson Learned

Existing resource names should be validated before running create commands against an environment containing previously deployed infrastructure.

Pre-deployment checks can prevent accidental create/update behavior against existing resources.

---

## Failed Deployment Left an Orphaned NIC

### Issue

Although the accidental `Dev-app01` deployment failed, Azure had already created an additional NIC:

```text
Dev-app01VMNic
```

The NIC was assigned:

```text
10.20.1.5
```

but was not attached to a virtual machine.

### Investigation

The NIC referenced by the real `Dev-app01` VM was retrieved:

```bash
az vm show --resource-group "DevLab_RG" --name "Dev-app01" --query "networkProfile.networkInterfaces[].id" -o tsv
```

The attached NIC was:

```text
Dev-app01-nic
```

NICs in `DevLab_RG` were then reviewed:

```bash
az network nic list --resource-group "DevLab_RG" --query "[].{NIC:name,PrivateIP:ipConfigurations[0].privateIPAddress,VM:virtualMachine.id,Subnet:ipConfigurations[0].subnet.id}" -o table
```

The output showed:

```text
Dev-app01-nic    10.20.1.4    Attached to Dev-app01
Dev-app01VMNic   10.20.1.5    No VM association
```

### Root Cause

The ARM deployment partially created supporting resources before failing on the immutable VM property.

### Resolution

Only the unused NIC was deleted:

```bash
az network nic delete --resource-group "DevLab_RG" --name "Dev-app01VMNic"
```

The NIC inventory was checked again to confirm that the legitimate VM NIC remained intact.

### Lesson Learned

A failed Azure deployment does not necessarily mean that no resources were created.

After a failed deployment, related resources should be inventoried before retrying or deleting anything.

This avoids both orphaned resources and accidental removal of resources still attached to active workloads.

---

## Default VNet Rule Allowed More Traffic Than Intended

### Issue

After deploying `Dev-data01`, testing from `Dev-app01` showed that both ICMP and SSH were initially allowed.

```text
Dev-app01 → Dev-data01 ICMP   Succeeded
Dev-app01 → Dev-data01 :22    Succeeded
```

This was more permissive than the intended application-to-data security model.

### Investigation

`DataSubnet_NSG` was inspected with Azure's default rules included.

```bash
az network nsg rule list --resource-group "DevLab_RG" --nsg-name "DataSubnet_NSG" --include-default -o table
```

The default inbound rule:

```text
AllowVnetInBound
Priority 65000
```

allowed broad virtual network communication.

### Root Cause

Separating workloads into different subnets did not automatically create a security boundary between those workloads.

Without higher-priority custom rules, the default VNet rule continued to permit the traffic.

### Resolution

Three explicit security behaviors were implemented:

```text
ManagementSubnet → DataSubnet TCP/22    Allow
AppSubnet → DataSubnet TCP/5432         Allow
AppSubnet → DataSubnet everything else  Deny
```

The traffic tests were repeated after the change.

SSH and ICMP from `Dev-app01` failed, while the approved TCP/5432 path succeeded.

### Lesson Learned

Subnet separation and security segmentation are related but different concepts.

A subnet organizes workloads into network boundaries.

NSG policy determines which traffic is actually permitted across those boundaries.

---

# Lessons Learned

## Validate Each Infrastructure Layer Independently

The environment was validated progressively:

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
Effective NSGs
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

This made it easier to determine which infrastructure layer was responsible when a test failed.

---

## Separate Subnets Do Not Automatically Mean Isolation

The initial `Dev-app01 → Dev-data01` tests succeeded even though the VMs were located in separate subnets.

The default NSG behavior still permitted virtual network traffic.

Actual workload segmentation required explicit allow and deny rules.

---

## Use Least-Privilege Traffic Rules Between Workload Tiers

The data tier does not need to accept every protocol from the application tier.

The final design allows the intended application database path while denying unrelated traffic.

```text
AppSubnet → DataSubnet TCP/5432   Allow
AppSubnet → DataSubnet Other      Deny
```

---

## Preserve Management Access Separately

The management network uses a dedicated higher-priority rule:

```text
ManagementSubnet → DataSubnet TCP/22
```

This means operational access can remain available without granting SSH access to application-tier systems.

---

## Network Connectivity and Authentication Are Different Problems

A working TCP connection does not guarantee successful SSH authentication.

Likewise, an SSH authentication failure does not automatically indicate a network failure.

Testing each layer separately avoids unnecessary infrastructure changes.

---

## Failed Deployments Can Create Partial Resources

The failed `Dev-app01` deployment demonstrated that supporting resources can be created before the overall deployment fails.

Resource inventory and dependency checks should therefore be performed before cleanup.

---

## Effective Configuration Matters

Configured NSG rules were not treated as sufficient proof.

The effective NSG rules on `Dev-data01VMNic` were inspected to confirm that the intended policy actually applied to the workload.

Effective route tables were also inspected to verify that Azure recognized the expected local, peered, and Internet paths.

---

## Keep Private SSH Keys Off Remote Servers

SSH agent forwarding allowed the administrator's private key to remain on the workstation.

The private key did not need to be copied to `Prod-mgmt01`, `Dev-app01`, or `Dev-data01`.

---

## Private Workloads Do Not Require Public Administrative Access

Both development workloads remain privately addressed.

```text
Administrator
     │
     ▼
Prod-mgmt01
     │
     ├───────────────┐
     ▼               ▼
Dev-app01        Dev-data01
```

This preserves administrative access while limiting direct Internet exposure.

---

## VM Lifecycle Is Part of Cloud Operations

Provisioning a VM is only one part of compute administration.

The environment also validated:

```text
Start
Stop / Deallocate
Power-state verification
Restart validation
Network persistence
Cost-conscious lab operation
```

---

# Next Evolution

The current environment now demonstrates a functional management, application, and data-tier architecture with private connectivity and workload-specific security controls.

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
     │ TCP/5432 Only
     ▼
Dev-data01
```

The next evolution is to represent the manually deployed Azure infrastructure as declarative Infrastructure as Code.

Bicep will be used to reproduce the core environment, including:

```text
Resource Groups
Virtual Networks
Subnets
Network Security Groups
NSG Rules
VNet Peering
Network Interfaces
Virtual Machines
```

This transitions the environment from individually executed Azure CLI deployment commands toward repeatable, version-controlled infrastructure definitions.
