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

The completed environment consists of three Linux virtual machines distributed across dedicated management, application, and data subnets.

`Prod-mgmt01` provides the administrative entry point from `HomeLab_VNet`, while `Dev-app01` and `Dev-data01` remain private within `Devlab_VNet`. The two virtual networks communicate through bidirectional VNet peering.

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
│           └── Prod-mgmt01 ✅
│               │
│               ├── Ubuntu 22.04 LTS
│               ├── Standard_D2als_v7
│               ├── NIC: Prod-mgmt01-nic
│               ├── Private IP: 10.10.0.4
│               └── Public administrative endpoint
│
│                         ⇅
│                  VNet Peering ✅
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
        │   └── Dev-app01 ✅
        │       │
        │       ├── Ubuntu 22.04 LTS
        │       ├── Standard_D2als_v7
        │       ├── NIC: Dev-app01-nic
        │       ├── Private IP: 10.20.1.4
        │       └── No Public IP
        │
        └── DataSubnet
            │
            ├── DataSubnet_NSG
            │
            └── Dev-data01 ✅
                │
                ├── Ubuntu 22.04 LTS
                ├── Standard_D2als_v7
                ├── NIC: Dev-data01VMNic
                ├── Private IP: 10.20.2.4
                └── No Public IP
```

## Traffic Flow

The architecture separates administrative access from application-to-data communication.

```text
                         Administrative Access
                                TCP/22
                                   │
                                   ▼
                            Prod-mgmt01
                             10.10.0.4
                                   │
                                   │ VNet Peering
                     ┌─────────────┴─────────────┐
                     │                           │
                     │ TCP/22                    │ TCP/22
                     ▼                           ▼
                Dev-app01                  Dev-data01
                10.20.1.4                  10.20.2.4
                     │                           ▲
                     │        TCP/5432           │
                     └───────────────────────────┘
                          PostgreSQL Traffic
```

The resulting traffic model follows these principles:

* Administrative SSH access to the development environment originates from `ManagementSubnet`.
* `Dev-app01` and `Dev-data01` do not have public IP addresses.
* `HomeLab_VNet` and `Devlab_VNet` communicate through bidirectional VNet peering.
* `AppSubnet_NSG` allows SSH from `ManagementSubnet` to the application tier.
* `DataSubnet_NSG` allows SSH from `ManagementSubnet` to the data tier.
* `DataSubnet_NSG` allows TCP/5432 from `AppSubnet` for application-to-database communication.
* Other inbound traffic from `AppSubnet` to `DataSubnet` is explicitly denied.

This design creates a private three-tier infrastructure foundation while maintaining controlled administrative access and least-privilege communication between workloads.

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

The management VM also provides administrative access to both private resources in the development environment through VNet peering.

```text
Administrator
     │
     ▼
Prod-mgmt01
10.10.0.4
     │
     │ Private Connectivity
     │ VNet Peering
     │
     ├───────────────────────┐
     ▼                       ▼
Dev-app01               Dev-data01
10.20.1.4               10.20.2.4
```

---

## Application Tier

`Dev-app01` was deployed into `AppSubnet` within `Devlab_VNet`.

The VM was intentionally deployed without a public IP address.

| Configuration | Value |
| --- | --- |
| VM | `Dev-app01` |
| Resource Group | `DevLab_RG` |
| VNet | `Devlab_VNet` |
| Subnet | `AppSubnet` |
| Private IP | `10.20.1.4` |
| Public IP | None |
| VM Size | `Standard_D2als_v7` |
| Operating System | Ubuntu Linux |
| Authentication | SSH Public Key |

Administrative access follows:

```text
Administrator
     │
     ▼
Prod-mgmt01
10.10.0.4
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

`Dev-data01` was deployed into `DataSubnet` within `Devlab_VNet`.

The VM was also intentionally deployed without a public IP address.

| Configuration | Value |
| --- | --- |
| VM | `Dev-data01` |
| Resource Group | `DevLab_RG` |
| VNet | `Devlab_VNet` |
| Subnet | `DataSubnet` |
| Private IP | `10.20.2.4` |
| Public IP | None |
| VM Size | `Standard_D2als_v7` |
| Operating System | Ubuntu Linux |
| Authentication | SSH Public Key |

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

| Configuration | Value |
| --- | --- |
| VM | `Prod-mgmt01` |
| Resource Group | `HomeLab_RG` |
| VNet | `HomeLab_VNet` |
| Subnet | `ManagementSubnet` |
| VM Size | `Standard_D2als_v7` |
| Operating System | Ubuntu Linux |
| Private IP | `10.10.0.4` |
| Public IP | Yes |
| Authentication | SSH Public Key |

The deployment reused the existing networking resources rather than creating a new VNet or subnet.

VM configuration can be reviewed with:

```bash
az vm show --resource-group "HomeLab_RG" --name "Prod-mgmt01" -d -o table
```

---

## Dev-app01

The application VM was deployed into the existing `Devlab_VNet` development network.

| Configuration | Value |
| --- | --- |
| VM | `Dev-app01` |
| Resource Group | `DevLab_RG` |
| VNet | `Devlab_VNet` |
| Subnet | `AppSubnet` |
| VM Size | `Standard_D2als_v7` |
| Operating System | Ubuntu Linux |
| Private IP | `10.20.1.4` |
| Public IP | None |
| Authentication | SSH Public Key |

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

The deployed virtual machines were reviewed using:

```bash
az vm list -d --query "[].{VM:name,ResourceGroup:resourceGroup,PrivateIP:privateIps,PowerState:powerState}" -o table
```

The environment returned:

```text
VM           ResourceGroup    PrivateIP    PowerState
-----------  ---------------  -----------  ------------
Dev-app01    DEVLAB_RG        10.20.1.4    VM running
Dev-data01   DEVLAB_RG        10.20.2.4    VM running
Prod-mgmt01  HOMELAB_RG       10.10.0.4    VM running
```

All three planned Linux virtual machines were running.

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

The private IP address was confirmed with:

```bash
hostname -i
```

Result:

```text
10.20.2.4
```

This confirmed that the guest operating system network configuration matched the Azure NIC configuration.

---

## Management-to-Application Connectivity

Administrative access to `Dev-app01` was performed through `Prod-mgmt01`.

From the administrator workstation:

```bash
ssh -A azureadmin@<PROD-MGMT01-PUBLIC-IP>
```

From `Prod-mgmt01`:

```bash
ssh azureadmin@10.20.1.4
```

The connection succeeded.

The application VM hostname was verified:

```bash
hostname
```

Result:

```text
Dev-app01
```

The private address was verified:

```bash
hostname -I
```

Result:

```text
10.20.1.4
```

The successful connection validated:

```text
Administrator
      │
      ▼
Prod-mgmt01
10.10.0.4
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
10.20.1.4
```

---

## Management-to-Data Connectivity

From `Prod-mgmt01`, SSH connectivity to `Dev-data01` was tested:

```bash
ssh azureadmin@10.20.2.4
```

The connection succeeded.

The data VM identity was verified:

```bash
hostname
```

Result:

```text
Dev-data01
```

The private IP was verified:

```bash
hostname -i
```

Result:

```text
10.20.2.4
```

This confirmed that the priority `100` NSG rule successfully preserved administrative access from `ManagementSubnet`.

```text
Prod-mgmt01
10.10.0.4
     │
     │ TCP/22
     ▼
DataSubnet_NSG
     │
     │ Priority 100
     │ Allow-SSH-ManagementSubnet
     ▼
Dev-data01
10.20.2.4

ALLOWED
```

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

This provided a baseline demonstrating that Azure's default VNet rule allowed broader communication than required by the target architecture.

---

# Phase 7 — Application-to-Data Security Validation

Phase 7 validated the least-privilege security model between the application and data tiers using live network traffic.

The objective was to ensure that `Dev-app01` could communicate with `Dev-data01` only over the approved database port while preventing unnecessary access to the data tier.

The relevant workloads were:

```text
Prod-mgmt01
10.10.0.4
ManagementSubnet
     │
     │ Administrative SSH
     │ TCP/22
     ▼
Dev-data01
10.20.2.4
DataSubnet
     ▲
     │
     │ Application Database Traffic
     │ TCP/5432
     │
Dev-app01
10.20.1.4
AppSubnet
```

The intended security policy was:

```text
ManagementSubnet → DataSubnet TCP/22      Allow
AppSubnet        → DataSubnet TCP/5432    Allow
AppSubnet        → DataSubnet Other       Deny
```

This policy was enforced by `DataSubnet_NSG`.

---

## Validate DataSubnet_NSG Configuration

Before generating traffic, the custom rules configured on `DataSubnet_NSG` were reviewed.

```bash
az network nsg rule list -g DevLab_RG --nsg-name DataSubnet_NSG --query "[].{Priority:priority,Name:name,Source:sourceAddressPrefix,Destination:destinationAddressPrefix,Protocol:protocol,DestinationPort:destinationPortRange,Access:access,Direction:direction}" -o table
```

Result:

```text
Priority    Name                          Source        Destination    Protocol    DestinationPort    Access    Direction
----------  ----------------------------  ------------  -------------  ----------  -----------------  --------  -----------
100         Allow-SSH-ManagementSubnet    10.10.0.0/24  *              Tcp         22                 Allow     Inbound
110         Allow-PostgreSQL-AppSubnet    10.20.1.0/24  10.20.2.0/24   Tcp         5432               Allow     Inbound
120         Deny-AppSubnet-Other-Inbound  10.20.1.0/24  10.20.2.0/24   *           *                  Deny      Inbound
```

The priority order is significant because Azure NSG rules are evaluated beginning with the lowest priority number.

```text
100 → Allow management SSH
110 → Allow application database traffic
120 → Deny all other AppSubnet traffic
...
65000 → Azure default AllowVnetInBound
```

The custom workload-specific rules therefore take precedence over Azure's broader default virtual network rule.

---

## Validate App-to-Data TCP/22 Denial

From `Dev-app01`, TCP/22 connectivity to `Dev-data01` was tested:

```bash
nc -vz -w 5 10.20.2.4 22
```

Result:

```text
nc: connect to 10.20.2.4 port 22 (tcp) timed out: Operation now in progress
```

The timeout was expected.

The traffic followed:

```text
Source:           Dev-app01
Source IP:        10.20.1.4
Destination:      Dev-data01
Destination IP:   10.20.2.4
Protocol:         TCP
Destination Port: 22
```

Rule evaluation:

```text
Rule 100 — Allow-SSH-ManagementSubnet
Source is not 10.10.0.0/24
→ No match

Rule 110 — Allow-PostgreSQL-AppSubnet
Destination port is not TCP/5432
→ No match

Rule 120 — Deny-AppSubnet-Other-Inbound
Source = AppSubnet
Destination = DataSubnet
→ MATCH

DENY
```

Result:

```text
Dev-app01 → Dev-data01 TCP/22

DENIED ❌
```

This demonstrated that application-tier systems cannot use SSH to directly administer the data tier.

---

## Validate App-to-Data TCP/80 Denial

A second unauthorized port was tested to demonstrate that the security policy was not limited specifically to SSH.

From `Dev-app01`:

```bash
nc -vz -w 5 10.20.2.4 80
```

Result:

```text
nc: connect to 10.20.2.4 port 80 (tcp) timed out: Operation now in progress
```

The timeout was expected.

TCP/80 did not match the approved TCP/5432 application rule and therefore matched the explicit deny rule.

```text
Dev-app01 → Dev-data01 TCP/80

DENIED ❌
```

Testing multiple unauthorized ports provided additional evidence that `Deny-AppSubnet-Other-Inbound` was enforcing general application-to-data isolation rather than blocking only SSH.

---

## TCP/5432 Application-to-Data Validation

The approved application-to-data communication path was then validated.

The NSG policy allows:

```text
AppSubnet
10.20.1.0/24
     │
     │ TCP/5432
     ▼
DataSubnet
10.20.2.0/24
```

A successful NSG rule does not guarantee that a TCP connection will succeed unless something on the destination VM is listening on the target port.

Instead of installing PostgreSQL solely for the network test, a temporary Netcat listener was created on `Dev-data01`.

On `Dev-data01`:

```bash
nc -lv 5432
```

Result:

```text
Listening on 0.0.0.0 5432
```

From `Dev-app01`:

```bash
nc -vz -w 5 10.20.2.4 5432
```

Result:

```text
Connection to 10.20.2.4 5432 port [tcp/postgresql] succeeded!
```

The destination VM simultaneously reported:

```text
Connection received on dev-app01.internal.cloudapp.net 43384
```

This provided validation from both sides of the TCP connection.

```text
Dev-app01
10.20.1.4
     │
     │ Source ephemeral port: 43384
     │
     │ Destination TCP/5432
     ▼
Dev-data01
10.20.2.4

ALLOWED ✅
```

The temporary source port `43384` was dynamically selected by the operating system.

The destination service port remained:

```text
TCP/5432
```

The successful test validated:

```text
Priority:         110
Rule:             Allow-PostgreSQL-AppSubnet
Source:           10.20.1.0/24
Destination:      10.20.2.0/24
Protocol:         TCP
Destination Port: 5432
Action:           Allow
```

The temporary Netcat listener was used only to validate TCP connectivity.

This test did not validate PostgreSQL itself.

It validated that TCP traffic destined for port `5432` could traverse the Azure network security controls from the application tier to the data tier.

---

## Phase 7 Traffic Validation Results

The completed traffic tests produced the following results:

| Source | Destination | Protocol / Port | Expected | Result |
| --- | --- | --- | --- | --- |
| `Prod-mgmt01` | `Dev-data01` | TCP/22 | Allow | ✅ Allowed |
| `Dev-app01` | `Dev-data01` | TCP/22 | Deny | ✅ Denied |
| `Dev-app01` | `Dev-data01` | TCP/80 | Deny | ✅ Denied |
| `Dev-app01` | `Dev-data01` | TCP/5432 | Allow | ✅ Allowed |

The resulting security architecture is:

```text
                    Management Tier

                     Prod-mgmt01
                      10.10.0.4
                           │
                           │ TCP/22
                           │ ALLOW
                           ▼
                     Dev-data01
                      10.20.2.4
                           ▲
                           │
                           │ TCP/5432
                           │ ALLOW
                           │
                      Dev-app01
                       10.20.1.4
                           │
                           ├── TCP/22 ── DENY
                           │
                           └── TCP/80 ── DENY
```

This validated that the application tier receives only the network access required for its intended database communication while administrative access remains isolated to the management tier.

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

The `10.20.0.0/16 → VnetLocal` route confirmed that development network traffic remained local to `Devlab_VNet`.

---

## Effective NSG Rules

Traffic testing demonstrated the observed network behavior.

The final validation step inspected Azure's effective security configuration to confirm that the intended rules were actually applied to the `Dev-data01` network interface.

The NIC associated with `Dev-data01` was retrieved:

```bash
az vm show -g DevLab_RG -n Dev-data01 --query "networkProfile.networkInterfaces[].id" -o tsv
```

Result:

```text
/subscriptions/<SUBSCRIPTION-ID>/resourceGroups/DevLab_RG/providers/Microsoft.Network/networkInterfaces/Dev-data01VMNic
```

This confirmed:

```text
Dev-data01
     │
     ▼
Dev-data01VMNic
```

An initial attempt to display the effective NSG information directly as a table:

```bash
az network nic list-effective-nsg -g DevLab_RG -n Dev-data01VMNic -o table
```

returned:

```text
Table output unavailable. Use the --query option to specify an appropriate query.
```

The nested effective-security-rule structure was therefore extracted with JMESPath:

```bash
az network nic list-effective-nsg -g DevLab_RG -n Dev-data01VMNic --query "value[].effectiveSecurityRules[].{Priority:priority,Name:name,Protocol:protocol,Source:sourceAddressPrefixes[0],Destination:destinationAddressPrefixes[0],DestinationPort:destinationPortRanges[0],Access:access,Direction:direction}" -o table
```

Result:

```text
Priority    Name                                                Protocol    Source             Destination     DestinationPort    Access    Direction
----------  --------------------------------------------------  ----------  -----------------  --------------  -----------------  --------  -----------
100         securityRules/Allow-SSH-ManagementSubnet            Tcp         10.10.0.0/24       0.0.0.0/0       22-22              Allow     Inbound
110         securityRules/Allow-PostgreSQL-AppSubnet            Tcp         10.20.1.0/24       10.20.2.0/24    5432-5432          Allow     Inbound
120         securityRules/Deny-AppSubnet-Other-Inbound          All         10.20.1.0/24       10.20.2.0/24    0-65535            Deny      Inbound
65000       defaultSecurityRules/AllowVnetInBound               All         VirtualNetwork     VirtualNetwork  0-65535            Allow     Inbound
65001       defaultSecurityRules/AllowAzureLoadBalancerInBound  All         AzureLoadBalancer  0.0.0.0/0       0-65535            Allow     Inbound
65500       defaultSecurityRules/DenyAllInBound                 All         0.0.0.0/0          0.0.0.0/0       0-65535            Deny      Inbound
65000       defaultSecurityRules/AllowVnetOutBound              All         VirtualNetwork     VirtualNetwork  0-65535            Allow     Outbound
65001       defaultSecurityRules/AllowInternetOutBound          All         0.0.0.0/0          Internet        0-65535            Allow     Outbound
65500       defaultSecurityRules/DenyAllOutBound                All         0.0.0.0/0          0.0.0.0/0       0-65535            Deny      Outbound
```

This confirmed that all three custom security rules were effective on the data-tier workload:

```text
100  Allow-SSH-ManagementSubnet
110  Allow-PostgreSQL-AppSubnet
120  Deny-AppSubnet-Other-Inbound
```

It also demonstrated why custom rule priority is important.

Azure's default rule:

```text
65000
AllowVnetInBound
VirtualNetwork → VirtualNetwork
Allow
```

would otherwise permit broader virtual network communication.

Because the custom rules use priorities `100`, `110`, and `120`, Azure evaluates them before priority `65000`.

For an SSH connection from `Dev-app01`:

```text
Source:      10.20.1.4
Destination: 10.20.2.4
Port:        TCP/22

Rule 100
Source is not ManagementSubnet
→ No match

Rule 110
Destination port is not TCP/5432
→ No match

Rule 120
Source is AppSubnet
Destination is DataSubnet
→ MATCH

DENY
```

Azure stops evaluating the remaining rules after the matching deny rule.

For TCP/5432:

```text
Source:      10.20.1.4
Destination: 10.20.2.4
Port:        TCP/5432

Rule 100
→ No match

Rule 110
Source = AppSubnet
Destination = DataSubnet
Port = TCP/5432
→ MATCH

ALLOW
```

Azure again stops evaluating after the matching rule.

This demonstrates how custom NSG rules can override broader Azure defaults to implement workload-specific least-privilege security.

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

# Phase 7 Final Validation

Phase 7 validated application-to-data security through three separate forms of evidence.

## Configuration Validation

The configured NSG rules were inspected:

```text
100  ManagementSubnet → DataSubnet TCP/22      Allow
110  AppSubnet        → DataSubnet TCP/5432    Allow
120  AppSubnet        → DataSubnet Other       Deny
```

## Live Traffic Validation

Actual TCP connections were generated between workloads:

```text
Dev-app01 → Dev-data01 TCP/22     Denied
Dev-app01 → Dev-data01 TCP/80     Denied
Dev-app01 → Dev-data01 TCP/5432   Allowed

Prod-mgmt01 → Dev-data01 TCP/22   Allowed
```

## Effective Configuration Validation

The effective NSG configuration on `Dev-data01VMNic` confirmed that the custom rules were actively applied to the workload.

The validation workflow followed:

```text
Configure
    │
    ▼
Inspect
    │
    ▼
Generate Traffic
    │
    ▼
Validate Behavior
    │
    ▼
Inspect Effective Configuration
    │
    ▼
Confirm Security Policy
```

This provides stronger validation than simply confirming that NSG rules exist.

Phase 7 successfully demonstrated both network segmentation and least-privilege workload communication.

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

## Incorrect SSH Administrator Username

### Issue

An initial attempt to access `Prod-mgmt01` used:

```bash
ssh azureuser@<PROD-MGMT01-PUBLIC-IP>
```

The server returned:

```text
Permission denied (publickey).
```

### Investigation

The VM's configured administrator username was retrieved directly from Azure:

```bash
az vm show -g HomeLab_RG -n Prod-mgmt01 --query "osProfile.adminUsername" -o tsv
```

Result:

```text
azureadmin
```

### Root Cause

The SSH connection used the incorrect Linux administrator username.

The VM had been provisioned with:

```text
azureadmin
```

rather than:

```text
azureuser
```

### Resolution

The connection was retried using:

```bash
ssh azureadmin@<PROD-MGMT01-PUBLIC-IP>
```

The SSH connection succeeded.

### Lesson Learned

A `Permission denied (publickey)` error does not automatically indicate an incorrect SSH key or an Azure networking problem.

The authentication path includes:

```text
Username
   +
Private Key
   +
Authorized Public Key
```

The configured administrator username should be verified before modifying SSH keys or network security rules.

---

## SSH Authentication Failed Between VMs

### Issue

SSH from the administrator workstation to `Prod-mgmt01` succeeded.

The second connection from `Prod-mgmt01` to `Dev-app01` failed with:

```text
Permission denied (publickey)
```

### Investigation

The Ed25519 private key existed on the administrator workstation but was intentionally not copied to the management VM.

The SSH agent was inspected:

```bash
ssh-add -l
```

The required identity needed to be loaded and forwarded.

### Root Cause

The private key existed locally, but the management session did not initially have access to the local SSH identity through agent forwarding.

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
ssh -A azureadmin@<PROD-MGMT01-PUBLIC-IP>
```

SSH to `Dev-app01` was then retried:

```bash
ssh azureadmin@10.20.1.4
```

The connection succeeded.

The same administrative path also allowed:

```bash
ssh azureadmin@10.20.2.4
```

from `Prod-mgmt01`.

### Lesson Learned

SSH agent forwarding provides administrative access through a jump host without requiring the private SSH key to be copied onto that host.

```text
Private Key
    │
    └── Administrator Workstation ONLY
```

This is preferable to unnecessarily distributing the private key across remote systems.

Additionally:

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

## Azure CLI Command Executed Inside Linux VM

### Issue

While connected to `Prod-mgmt01`, an Azure CLI command was attempted:

```bash
az vm show -d -g HomeLab_RG -n Dev-app01
```

The guest operating system returned:

```text
az: command not found
```

### Root Cause

Azure CLI was installed and authenticated on the administrator workstation, not on `Prod-mgmt01`.

The SSH session was operating inside the Ubuntu guest OS rather than the administrator workstation.

### Resolution

Azure control-plane commands continued to be executed from the administrator workstation.

Linux guest commands were executed from the virtual machines.

```text
Administrator Workstation
│
├── Azure CLI
│   ├── az vm show
│   ├── az network nsg rule list
│   ├── az network nic list-effective-nsg
│   └── Azure resource management
│
└── SSH
    │
    ▼
Linux Virtual Machines
    ├── hostname
    ├── hostname -I
    ├── ip addr
    ├── nc
    ├── ping
    └── guest OS administration
```

### Lesson Learned

Azure resource management and guest operating-system administration represent separate management layers.

Azure CLI interacts with the Azure control plane, while commands executed after SSHing into a VM operate inside the guest operating system.

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

The deployment workflow was corrected to target:

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
ManagementSubnet → DataSubnet TCP/22      Allow
AppSubnet → DataSubnet TCP/5432           Allow
AppSubnet → DataSubnet everything else    Deny
```

The traffic tests were repeated after the change.

The following behavior was validated:

```text
Dev-app01 → Dev-data01 TCP/22     Denied
Dev-app01 → Dev-data01 TCP/80     Denied
Dev-app01 → Dev-data01 TCP/5432   Allowed
Prod-mgmt01 → Dev-data01 TCP/22   Allowed
```

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

This limits the application's network privileges to the service it is expected to consume.

---

## Test Both Allow and Deny Conditions

Testing only TCP/5432 would prove that the approved path worked but would not prove that unauthorized traffic was restricted.

Phase 7 tested both sides of the security policy:

```text
Expected Allow → TCP/5432 → Success
Expected Deny  → TCP/22   → Timeout
Expected Deny  → TCP/80   → Timeout
```

A security control should be validated against both permitted and prohibited behavior.

---

## Preserve Management Access Separately

The management network uses a dedicated higher-priority rule:

```text
ManagementSubnet → DataSubnet TCP/22
```

This means operational access can remain available without granting SSH access to application-tier systems.

The resulting separation is:

```text
ManagementSubnet
     │
     └── SSH → DataSubnet
             ALLOW

AppSubnet
     │
     ├── PostgreSQL → DataSubnet
     │                ALLOW
     │
     └── Other → DataSubnet
                 DENY
```

---

## NSG Priority Determines Which Policy Wins

Azure's effective security rules still contain:

```text
65000
AllowVnetInBound
```

However, the custom workload rules use:

```text
100
110
120
```

These rules are evaluated before the broader Azure default.

This allows explicit workload security requirements to override the default virtual-network communication behavior.

---

## Network Connectivity and Authentication Are Different Problems

A working TCP connection does not guarantee successful SSH authentication.

Likewise, an SSH authentication failure does not automatically indicate a network failure.

For example:

```text
Permission denied (publickey)
```

indicates that the SSH service was reached but authentication was unsuccessful.

A timeout more commonly indicates that the network connection could not be established.

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

The overall validation approach became:

```text
Configured Intent
       │
       ▼
Effective Configuration
       │
       ▼
Live Traffic Testing
       │
       ▼
Observed Behavior
```

---

## Keep Private SSH Keys Off Remote Servers

SSH agent forwarding allowed the administrator's private key to remain on the workstation.

The private key did not need to be copied to `Prod-mgmt01`, `Dev-app01`, or `Dev-data01`.

```text
Administrator Workstation
        │
        │ Private key remains here
        │
        ▼
SSH Agent Forwarding
        │
        ▼
Prod-mgmt01
        │
        ├────────► Dev-app01
        │
        └────────► Dev-data01
```

This reduces unnecessary exposure of private authentication material.

---

## Understand the Azure Control Plane vs. Guest OS

Azure CLI commands executed from the administrator workstation manage Azure resources through the Azure control plane.

Commands executed after SSHing into a Linux VM operate inside the guest operating system.

```text
Azure CLI
   │
   └── Azure Resource Management

SSH Session
   │
   └── Linux Guest Administration
```

Understanding which management layer is being used helps isolate troubleshooting problems more quickly.

---

## Private Workloads Do Not Require Public Administrative Access

Both development workloads remain privately addressed.

```text
Administrator
     │
     ▼
Prod-mgmt01
     │
     │ VNet Peering
     ├─────────────────┐
     │                 │
     ▼                 ▼
Dev-app01          Dev-data01
10.20.1.4          10.20.2.4
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

# Phase 7 Completion

Phase 7 successfully implemented and validated least-privilege network segmentation between the application and data tiers.

The final security model is:

```text
Administrator
     │
     ▼
Prod-mgmt01
10.10.0.4
     │
     │ ManagementSubnet
     │
     ├──────────── TCP/22 ──────────────┐
     │                                  │
     ▼                                  ▼
Dev-app01                          Dev-data01
10.20.1.4                         10.20.2.4
AppSubnet                          DataSubnet
     │                                  ▲
     │                                  │
     ├──── TCP/5432 ────────────────────┤
     │          ALLOW                   │
     │                                  │
     ├──── TCP/22 ──────────────────────┤
     │          DENY                    │
     │                                  │
     └──── TCP/80 ──────────────────────┘
                DENY
```

The environment now demonstrates:

* private application and data workloads
* dedicated management access
* VNet peering
* subnet-level NSG enforcement
* explicit workload allow rules
* explicit workload deny rules
* least-privilege application-to-data communication
* live TCP validation
* effective NSG validation
* SSH agent forwarding
* separation of Azure control-plane and guest OS administration

**Project 3 — Phase 7: Application-to-Data Security is complete.**

---

# Next Evolution

The current environment now demonstrates a functional management, application, and data-tier architecture with private connectivity and workload-specific security controls.

```text
Administrator
     │
     ▼
Prod-mgmt01
10.10.0.4
     │
     │ VNet Peering
     │
     ├───────────────────────┐
     │                       │
     │ TCP/22                │ TCP/22
     ▼                       ▼
Dev-app01               Dev-data01
10.20.1.4               10.20.2.4
     │                       ▲
     │      TCP/5432         │
     └───────────────────────┘
```

The completed compute environment now contains all three planned virtual machines:

```text
HomeLab_RG
└── HomeLab_VNet
    └── ManagementSubnet
        └── Prod-mgmt01 ✅
            10.10.0.4
                 │
                 │ VNet Peering ✅
                 ▼
DevLab_RG
└── Devlab_VNet
    │
    ├── AppSubnet
    │   └── Dev-app01 ✅
    │       10.20.1.4
    │
    └── DataSubnet
        └── Dev-data01 ✅
            10.20.2.4
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
