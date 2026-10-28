# Private Linux Virtual Machines — Azure Deployment & Security Validation

## Overview

This project documents the deployment and validation of three Ubuntu 22.04 LTS virtual machines across a segmented Microsoft Azure HomeLab. The implementation builds on existing resource groups, subnets, Network Security Groups (NSGs), and bidirectional VNet peering.

The goal was to establish a management entry point, deploy private application and data workloads, and validate least-privilege communication using both live traffic tests and Azure effective configuration.

**Implementation outcomes**

- Three Linux VMs deployed into management, application, and data tiers.
- SSH public-key authentication and private administration through a management VM.
- No public IP addresses on the application and data VMs.
- Explicit NSG rules allowing management SSH and application-to-data TCP/5432 while denying other AppSubnet-to-DataSubnet traffic.
- Successful positive and negative connectivity tests, effective route and NSG inspection, DNS and outbound HTTPS validation.
- Documented deployment, authentication, and security troubleshooting.

[← Compute overview](./README.md)

## Architecture

| VM | Role | Resource group | VNet / subnet | Private IP | Public IP | OS / size |
|---|---|---|---|---|---|---|
| `Prod-mgmt01` | Administrative entry point | `HomeLab_RG` | `HomeLab_VNet` / `ManagementSubnet` | `10.10.0.4` | Yes | Ubuntu 22.04 LTS / `Standard_D2als_v7` |
| `Dev-app01` | Application tier | `DevLab_RG` | `Devlab_VNet` / `AppSubnet` | `10.20.1.4` | No | Ubuntu 22.04 LTS / `Standard_D2als_v7` |
| `Dev-data01` | Data tier | `DevLab_RG` | `Devlab_VNet` / `DataSubnet` | `10.20.2.4` | No | Ubuntu 22.04 LTS / `Standard_D2als_v7` |

```text
HomeLab_RG                                      DevLab_RG
HomeLab_VNet 10.10.0.0/16                      Devlab_VNet 10.20.0.0/16
└── ManagementSubnet 10.10.0.0/24              ├── AppSubnet 10.20.1.0/24
    ├── ManagementSubnet_NSG                   │   ├── AppSubnet_NSG
    └── Prod-mgmt01 10.10.0.4                  │   └── Dev-app01 10.20.1.4
         │                                     │
         └──────── Bidirectional peering ──────┤
                                               └── DataSubnet 10.20.2.0/24
                                                   ├── DataSubnet_NSG
                                                   └── Dev-data01 10.20.2.4
```

The management VM has a public administrative endpoint with restricted SSH access. Both development workloads remain private. VNet peering provides private routing between the two environments; NSGs enforce workload-specific traffic policy.

### Intended traffic flows

| Source | Destination | Protocol | Policy |
|---|---|---|---|
| Management subnet `10.10.0.0/24` | Data tier | TCP/22 | Allow |
| Management subnet `10.10.0.0/24` | Application tier | TCP/22 | Allow |
| Application subnet `10.20.1.0/24` | Data subnet `10.20.2.0/24` | TCP/5432 | Allow |
| Application subnet `10.20.1.0/24` | Data subnet `10.20.2.0/24` | Other inbound traffic | Deny |

> **Design distinction:** VNet peering supplies connectivity; subnet-level NSGs determine which traffic is permitted. Subnet separation alone does not create a deny-by-default boundary.

## Deployment

### SSH key authentication

The workstation initially had no `~/.ssh` directory. An Ed25519 key pair was generated locally:

```bash
ls -la ~/.ssh
ssh-keygen -t ed25519 -C "azure-homelab"
cat ~/.ssh/id_ed25519.pub
```

The public key was supplied to Azure Linux VMs for SSH authentication. The private key remained on the administrator workstation and is not included in this repository.

### VM provisioning

The management and application VMs were deployed into the existing network resources. Their deployed configurations can be inspected with:

```bash
az vm show --resource-group HomeLab_RG --name Prod-mgmt01 -d -o table
az vm show --resource-group DevLab_RG --name Dev-app01 -d -o table
```

Before deploying the data VM, the target subnet and NSG association were checked:

```bash
az network vnet subnet show --resource-group DevLab_RG --vnet-name Devlab_VNet --name DataSubnet --query "{Subnet:name,Prefix:addressPrefix,NSG:networkSecurityGroup.id}" -o table
```

The documented `Dev-data01` deployment command was:

```bash
az vm create --resource-group DevLab_RG --name Dev-data01 --location eastus --image Ubuntu2204 --size Standard_D2als_v7 --vnet-name Devlab_VNet --subnet DataSubnet --admin-username "<USERNAME>" --ssh-key-values ~/.ssh/id_ed25519.pub --public-ip-address "" --nsg "" --os-disk-delete-option Delete --nic-delete-option Delete
```

`--public-ip-address ""` avoided creating a public IP. `--nsg ""` avoided creating a separate NIC-level NSG because the subnet already had `DataSubnet_NSG`. The deployment returned private IP `10.20.2.4` with no public IP.

**Note:** These commands document the original implementation. Review existing resources, quota, current Azure CLI behavior, and costs before attempting any redeployment.

### VM and NIC verification

```bash
az vm list -d --query "[].{VM:name,ResourceGroup:resourceGroup,PrivateIP:privateIps,PowerState:powerState}" -o table
az vm show -g DevLab_RG -n Dev-data01 --query "networkProfile.networkInterfaces[].id" -o tsv
```

The original deployment validation confirmed all three Linux VMs with their intended private IP addresses. Power state is time-dependent and should be checked rather than assumed.

## Network Security Configuration

### Management SSH to data tier

`DataSubnet_NSG` was configured to allow SSH from `ManagementSubnet`:

```bash
az network nsg rule create --resource-group DevLab_RG --nsg-name DataSubnet_NSG --name Allow-SSH-ManagementSubnet --priority 100 --direction Inbound --access Allow --protocol Tcp --source-address-prefixes 10.10.0.0/24 --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges 22
```

The existing `AppSubnet_NSG` likewise allowed management-subnet SSH to the application tier.

### Application-to-data controls

Initial testing showed that application-to-data SSH and ICMP were permitted by Azure's default `AllowVnetInBound` rule. The following explicit custom rules were introduced:

```bash
az network nsg rule create --resource-group DevLab_RG --nsg-name DataSubnet_NSG --name Allow-PostgreSQL-AppSubnet --priority 110 --direction Inbound --access Allow --protocol Tcp --source-address-prefixes 10.20.1.0/24 --source-port-ranges "*" --destination-address-prefixes 10.20.2.0/24 --destination-port-ranges 5432
```

```bash
az network nsg rule create --resource-group DevLab_RG --nsg-name DataSubnet_NSG --name Deny-AppSubnet-Other-Inbound --priority 120 --direction Inbound --access Deny --protocol "*" --source-address-prefixes 10.20.1.0/24 --source-port-ranges "*" --destination-address-prefixes 10.20.2.0/24 --destination-port-ranges "*"
```

| Priority | NSG rule | Effect |
|---|---|---|
| 100 | `Allow-SSH-ManagementSubnet` | Allow management subnet to TCP/22 |
| 110 | `Allow-PostgreSQL-AppSubnet` | Allow application subnet to data subnet TCP/5432 |
| 120 | `Deny-AppSubnet-Other-Inbound` | Deny other application-to-data traffic |
| 65000 | Azure default `AllowVnetInBound` | Broad VNet allowance, evaluated after custom rules |

Lower numeric priorities are evaluated first. The custom rules override the broad default where they match.

Inspect the custom rules with:

```bash
az network nsg rule list -g DevLab_RG --nsg-name DataSubnet_NSG --query "[].{Priority:priority,Name:name,Source:sourceAddressPrefix,Destination:destinationAddressPrefix,Protocol:protocol,DestinationPort:destinationPortRange,Access:access,Direction:direction}" -o table
```

## Validation Results

### Private SSH access

The administrator connected to the management VM and then reached private development workloads:

```bash
ssh -A azureadmin@<PROD-MGMT01-PUBLIC-IP>
# From Prod-mgmt01:
ssh azureadmin@10.20.1.4
ssh azureadmin@10.20.2.4
```

SSH agent forwarding allowed the local workstation's key to be used without copying the private key to the management VM. The original tests confirmed successful management-to-application and management-to-data SSH access.

### Positive and negative traffic testing

| Source | Destination | Test | Expected | Observed |
|---|---|---|---|---|
| `Prod-mgmt01` | `Dev-data01` | TCP/22 | Allow | Allowed |
| `Dev-app01` | `Dev-data01` | TCP/22 | Deny | Timed out |
| `Dev-app01` | `Dev-data01` | TCP/80 | Deny | Timed out |
| `Dev-app01` | `Dev-data01` | TCP/5432 | Allow | Connected |

From `Dev-app01`, negative tests used:

```bash
nc -vz -w 5 10.20.2.4 22
nc -vz -w 5 10.20.2.4 80
```

Both timed out as expected. The configured deny rule and effective NSG inspection corroborated the blocked traffic; a timeout by itself would not identify the root cause.

For the allowed port, a **temporary Netcat listener** was started on `Dev-data01`:

```bash
nc -lv 5432
```

Then `Dev-app01` tested:

```bash
nc -vz -w 5 10.20.2.4 5432
```

The connection succeeded and the listener observed the incoming connection. This validated **TCP/5432 network connectivity**, not a PostgreSQL installation or database transaction.

### Effective routes

```bash
az network nic show-effective-route-table --resource-group DevLab_RG --name Dev-data01VMNic -o table
```

The documented active routes included:

| Prefix | Next hop |
|---|---|
| `10.20.0.0/16` | `VnetLocal` |
| `10.10.0.0/16` | `VNetPeering` |
| `0.0.0.0/0` | `Internet` |

These results supported the expected local and peered network paths at the time of validation.

### Effective NSG rules

```bash
az network nic list-effective-nsg -g DevLab_RG -n Dev-data01VMNic --query "value[].effectiveSecurityRules[].{Priority:priority,Name:name,Protocol:protocol,Source:sourceAddressPrefixes[0],Destination:destinationAddressPrefixes[0],DestinationPort:destinationPortRanges[0],Access:access,Direction:direction}" -o table
```

The effective configuration showed the three custom rules at priorities `100`, `110`, and `120`, ahead of Azure's default inbound VNet allowance. This verified that the policy was applied to the data VM's NIC, not merely present in an NSG definition.

### DNS and outbound HTTPS

From the private workload:

```bash
nslookup microsoft.com
curl -I https://www.microsoft.com
```

The DNS query resolved successfully, and the HTTPS test returned `HTTP/2 200`. The guest used `127.0.0.53` as its local stub resolver. These tests confirmed DNS resolution and outbound HTTPS at the time of testing; they did not imply inbound public reachability.

## Troubleshooting & Resolutions

The original implementation surfaced several operational issues. The table summarizes the documented findings while preserving the key diagnostic lessons.

| Issue | Root cause or finding | Resolution / lesson |
|---|---|---|
| VM deployment rejected a requested size | Requested SKU unavailable for the region/subscription configuration | Selected supported `Standard_D2als_v7`; investigate compute errors at the compute layer |
| SSH key directory missing | Workstation had no `~/.ssh` directory | Generated a local Ed25519 key pair and used its public key |
| Incorrect SSH username | Login identity did not match the configured VM administrator | Verified the correct username before retrying |
| SSH authentication between VMs failed | Key/authentication configuration did not match the intended access path | Used the local key and SSH agent forwarding; kept private keys off remote hosts |
| Azure CLI command run inside a Linux guest | Azure control-plane administration was confused with guest OS administration | Used Azure CLI in the authenticated administration environment |
| VM deployment failed due to existing name | Resource naming conflict | Inspected existing resources before attempting redeployment |
| Failed deployment left an orphaned NIC | Partial resource creation | Inventoried dependencies and cleaned up only confirmed unused resources |
| App-to-data traffic too permissive | Default `AllowVnetInBound` allowed traffic across subnets | Added explicit allow and deny rules and reran both positive and negative tests |

### Detailed example: default NSG behavior

**Issue:** Before custom segmentation, `Dev-app01` could reach `Dev-data01` over SSH and ICMP, contrary to the intended isolation model.

**Investigation:**

```bash
az network nsg rule list --resource-group DevLab_RG --nsg-name DataSubnet_NSG --include-default -o table
```

The default inbound `AllowVnetInBound` rule at priority `65000` permitted broader VNet communication.

**Resolution:** Added higher-priority management SSH allow, application TCP/5432 allow, and other application-to-data deny rules. Repeated live traffic tests and checked effective NSG rules.

**Lesson:** Network segmentation requires enforced policy, not just separate subnets.

## Engineering Lessons Learned

1. **Validate each layer independently.** VM SKU and capacity errors, NIC configuration, routing, NSGs, and guest authentication require different diagnostic approaches.
2. **Test both permitted and denied traffic.** A working connection alone does not demonstrate least-privilege segmentation.
3. **Inspect effective configuration.** NSG definitions and route tables should be verified on the workload NIC, alongside live tests.
4. **Separate connectivity from authentication.** A reachable TCP port does not guarantee successful SSH login.
5. **Protect private credentials.** Keep SSH private keys on the trusted workstation and out of source control.
6. **Distinguish Azure control plane from guest OS operations.** Azure CLI resource management and in-guest Linux commands solve different problems.
7. **Expect partial deployments.** Failed provisioning may leave NICs or other resources; inspect dependencies before cleanup.
8. **Use VM lifecycle controls.** Deallocate idle compute to reduce charges, while remembering disks and other retained resources may continue to incur costs.

## Related Documentation

- [Azure Compute Overview](./README.md)
- [Azure Portfolio Home](../../README.md)

## Security & Responsible Testing

This project documents an independent Azure HomeLab. No employer credentials, proprietary infrastructure configurations, confidential information, or production data are used. Examples use representative values, and SSH private keys are excluded from version control.
