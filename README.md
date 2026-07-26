# Azure Portfolio Project — Azure CLI & Bicep Home Lab Infrastructure

This repository documents a hands-on, production-aligned Azure home lab designed to reinforce Azure administration, cloud engineering, and Infrastructure-as-Code (IaC) skills aligned with the AZ-104: Microsoft Azure Administrator and AZ-305: Azure Solutions Architect certification paths.

The lab simulates a secure, cost-conscious enterprise Azure environment using:

- Azure CLI for resource provisioning and operational automation
- Azure Bicep for declarative Infrastructure-as-Code deployments
- Azure Portal for validation, monitoring, troubleshooting, and verification only

The goal of this project is to demonstrate real-world Azure deployment practices used by cloud engineers, including repeatable infrastructure deployments, governance enforcement, network security, and operational management.

---

# 🔍 Project Overview

The objective of this project is to build and continuously evolve a realistic Azure environment that mirrors how organizations design, deploy, secure, and manage cloud infrastructure.

All infrastructure changes are performed through:

- Azure CLI commands
- Azure Bicep templates
- Git-based version control workflows

Azure Portal is used only for:

- Deployment validation
- Resource verification
- Monitoring dashboards
- Reviewing logs and alerts
- Troubleshooting configuration issues

The lab is structured around two primary resource groups within a single Azure subscription.

## Azure Subscription

**Subscription Name:** HomeLab

## Resource Groups

### HomeLab_rg

**Environment Tag:** prod

Purpose:
- Core enterprise-style Azure environment
- Foundational networking and security components
- Shared services
- Production-like infrastructure scenarios

Planned Resources:
- Hub networking components
- Azure Firewall
- Jump Box VM
- Shared monitoring services
- Identity and governance services


### DevLab_RG

**Environment Tag:** testing

Purpose:
- Development and experimentation environment
- Testing Azure CLI commands
- Validating Bicep templates before production deployment
- Learning new Azure services safely

Planned Resources:
- Application workloads
- Test virtual machines
- Storage services
- Network configurations
- Automation experiments


All resources are deployed primarily in:

- East US
- East US 2

Resource governance is enforced through Azure Policy, tagging standards, budgets, and monitoring controls.

---

# 🎯 Project Goals

- Build Azure infrastructure using Azure CLI and Bicep only
- Develop repeatable Infrastructure-as-Code deployment practices
- Reinforce AZ-104 Azure Administrator objectives through hands-on labs
- Build architecture skills aligned with AZ-305 Azure Solutions Architect
- Implement enterprise Azure networking and security patterns
- Automate resource provisioning and configuration
- Apply Azure governance and cost-management best practices
- Maintain a monthly cloud spend target of $80–$100 (hard cap: $120)
- Create professional documentation and architecture diagrams suitable for a cloud engineering portfolio

---

# 🧱 Core Architecture

## Deployment Model

All infrastructure follows an Infrastructure-as-Code approach:
