# Windows Server 2022 Deployment with Terraform

## Project Overview

This project demonstrates Infrastructure-as-Code (IaC) deployment of a Windows Server 2022 virtual machine into an existing Microsoft Azure environment using Terraform.

The deployment integrates with existing Azure networking resources while enforcing private connectivity and restricted administrative access.

## Architecture

| Component | Configuration |
|---|---|
| Resource Group | DevLab_RG |
| Azure Region | East US |
| Virtual Network | Devlab_VNet |
| Subnet | AppSubnet (10.20.1.0/24) |
| Virtual Machine | Dev-win01 |
| Operating System | Windows Server 2022 Datacenter |
| VM Size | Standard_D2as_v7 |
| Private IP | 10.20.1.5 (Static) |
| OS Disk | Standard SSD |
| Network Security Group | AppSubnet_NSG |
| Public IP | None |

## Terraform Resources

Terraform provisions and manages:

- Azure Windows virtual machine
- Azure network interface with a static private IP
- Network security rule permitting restricted RDP access

Existing resource groups, virtual networks, and subnets are referenced using Terraform data sources rather than recreated.

## Network Security

The Windows VM does not have a public IP address.

RDP access on TCP port 3389 is restricted to the management VM's private IP address, 10.10.0.4/32, through the existing AppSubnet_NSG.

Administrative access is performed through the management VM and an SSH tunnel rather than exposing RDP directly to the internet.

## Project Files

| File | Purpose |
|---|---|
| main.tf | Windows Server VM deployment |
| network.tf | Network interface and static IP configuration |
| security.tf | Restricted RDP NSG rule |
| providers.tf | AzureRM provider configuration |
| variables.tf | Sensitive administrator password input |
| versions.tf | Terraform and provider version requirements |
| .terraform.lock.hcl | Provider dependency lock file |

## Deployment Workflow

1. Authenticate to Azure and select the intended subscription.
2. Provide the Azure subscription ID through ARM_SUBSCRIPTION_ID.
3. Supply the administrator password securely through TF_VAR_admin_password or an approved secret-management solution.
4. Initialize Terraform using terraform init.
5. Validate the configuration using terraform validate.
6. Review proposed infrastructure changes using terraform plan.
7. Apply the configuration only after reviewing the execution plan.

## State Management

Terraform state files are excluded from Git using .gitignore.

The existing deployment is managed using local Terraform state in a separate working directory. This GitHub repository contains the source configuration, not the active deployment state.

Running Terraform from a new directory without the existing state or an appropriately configured backend may result in duplicate-resource creation attempts.

## Key Engineering Decisions

- Reused existing Azure networking resources to avoid unnecessary infrastructure duplication.
- Used a static private IP for predictable administrative connectivity.
- Avoided exposing RDP through a public IP.
- Restricted RDP traffic to a designated management VM.
- Used a sensitive Terraform variable instead of hardcoding the administrator password.
- Removed the Azure subscription ID from version-controlled configuration.

## Future Improvements

- Introduce Azure Storage remote state with appropriate access controls.
- Replace environment-specific values with reusable Terraform variables.
- Add automated Terraform formatting, validation, and security checks.
- Integrate Azure Monitor, patch management, and backup policies.
- Expand infrastructure deployment through reusable Terraform modules.
