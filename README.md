# Azure Infrastructure & Cloud Engineering Portfolio

**Microsoft Azure | Infrastructure Engineering | Terraform | Azure CLI | PowerShell | Bicep**

## Overview

Welcome to my Azure Infrastructure & Cloud Engineering Portfolio.

I am a Systems Platform Engineer II with over six years of IT experience, including enterprise infrastructure administration, virtualization, Windows and Linux systems, and Microsoft Azure operations.

My professional experience includes provisioning and managing Azure virtual machines, configuring virtual networks, supporting patching and backup operations, and using Terraform, Azure CLI, and PowerShell to deploy and manage infrastructure.

Building on my enterprise infrastructure background, I use this portfolio to deepen my Azure-specific engineering skills through hands-on implementation, testing, and troubleshooting. My goal is to continue strengthening my capabilities in cloud infrastructure deployment, administration, networking, monitoring, security, and automation as I transition toward a dedicated Azure Cloud Infrastructure Engineering role.

## Purpose of This Portfolio

This repository serves as both a professional engineering portfolio and an independent Azure testing environment.

### Hands-On Azure Infrastructure Engineering

Document practical experience deploying, configuring, administering, and troubleshooting Azure infrastructure.

Projects focus on understanding how infrastructure components operate together, evaluating configuration decisions, and applying established infrastructure engineering principles within Microsoft Azure.

### Controlled Testing & Configuration Validation

Maintain a personal Azure environment where I can independently test configurations, reproduce technical scenarios, troubleshoot unexpected behavior, and evaluate different deployment approaches.

I also use this environment to reinforce concepts relevant to my professional responsibilities. When working with unfamiliar configurations or technologies that require additional practice, I can recreate representative scenarios in a controlled setting to strengthen my understanding before applying those lessons in an enterprise environment.

### Continuous Technical Development

Continue developing my Azure engineering skills while building on my existing infrastructure and systems administration experience.

Areas of focus include Azure compute, networking, identity, monitoring, backup and recovery, security, infrastructure automation, and operational troubleshooting.

## Azure HomeLab Environment

My Azure HomeLab is organized into separate production-style and development/testing environments to support practical infrastructure exercises.

| Component | Implementation |
|---|---|
| Subscription | HomeLab |
| Region | East US |
| Resource Groups | HomeLab_RG, DevLab_RG |
| Networking | Azure VNets, subnets, NSGs, VNet peering |
| Compute | Windows Server and Linux virtual machines |
| Infrastructure as Code | Terraform |
| Administration | Azure CLI, PowerShell |
| Governance | Resource tagging, budgets, cost alerts |

The environment supports testing infrastructure configurations, validating connectivity, investigating deployment behavior, and practicing troubleshooting scenarios.

## Azure Engineering Projects

This section highlights documented Azure infrastructure projects completed within my HomeLab environment.

### Subscription Governance & Cost Controls

Implemented resource organization, environment tagging, Azure budgets, and cost monitoring practices.

### Secure Azure Networking

Configured Azure virtual networks, subnet segmentation, network security groups, and VNet peering to establish controlled communication between environments.

### Azure Virtual Machines & Private Connectivity

Deployed Linux virtual machines across segmented Azure networks and validated private connectivity and network security configurations.

### Windows Server 2022 Deployment with Terraform

Provisioned Azure Windows Server infrastructure using Terraform, including compute, networking, and security configurations.

[View Terraform Windows Server 2022 Project](terraform/dev-windows-vm/README.md)

## Technologies & Tools

| Category | Technologies |
|---|---|
| Cloud Infrastructure | Microsoft Azure, Azure VMs, VNets, NSGs, Azure Storage |
| Infrastructure as Code | Terraform, Bicep, ARM Templates |
| Scripting & Automation | Azure CLI, PowerShell, Bash |
| Operating Systems | Windows Server, Ubuntu Linux |
| Monitoring & Operations | Azure Monitor, Log Analytics, Azure Backup |
| Identity & Access | Microsoft Entra ID, Azure RBAC |
| Version Control | Git, GitHub |

These technologies reflect a combination of professional experience, working knowledge, and areas of continued hands-on development.

## Infrastructure Automation & Working Knowledge

I have working knowledge of infrastructure automation and Infrastructure as Code, including Terraform, Azure CLI, and PowerShell.

I use these tools to provision and manage Azure resources, streamline repeatable administrative tasks, and develop more consistent infrastructure deployment workflows.

Through this portfolio, I continue improving my understanding of reusable configurations, deployment validation, scripting, and infrastructure automation practices.

## Engineering Approach

My projects follow a structured engineering workflow:

1. **Plan** — Identify requirements, dependencies, and expected infrastructure behavior.
2. **Deploy** — Provision and configure resources using Azure CLI, Terraform, or other appropriate tools.
3. **Validate** — Verify infrastructure configuration, connectivity, security, and operational functionality.
4. **Troubleshoot** — Investigate deployment issues, unexpected behavior, and configuration failures.
5. **Document** — Capture implementation steps, design decisions, validation results, and lessons learned.
6. **Improve** — Review opportunities to strengthen reliability, security, repeatability, and cost efficiency.

## Security & Responsible Testing

This repository documents an independent personal Azure environment used for professional development and technical experimentation.

Work-related concepts and scenarios are recreated independently using representative configurations and synthetic data. Employer credentials, confidential information, proprietary infrastructure configurations, and production data are not used.

Sensitive configuration values, credentials, and local Terraform state files are excluded from version control where appropriate.

## Certifications

- Microsoft Certified: Azure Solutions Architect Expert
- Microsoft Certified: Azure Administrator Associate
- CompTIA Security+ CE
