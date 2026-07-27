# Azure Portfolio Project — Cloud Infrastructure Automation with Azure CLI & Bicep

## About This Project

This repository documents a production-aligned Azure infrastructure project focused on cloud engineering practices, Infrastructure-as-Code automation, governance, networking, security, and operational management.

The environment demonstrates how Azure resources can be designed, deployed, secured, and managed using:

- Azure CLI for infrastructure operations and automation
- Azure Bicep for repeatable Infrastructure-as-Code deployments
- Azure Resource Manager for deployment orchestration
- Azure Portal for validation, monitoring, troubleshooting, and operational visibility

The goal of this project is to showcase enterprise-style Azure implementation patterns used by Cloud Engineers, Platform Engineers, and Azure Solutions Architects.

---

# ☁️ Cloud Engineering Focus

This project focuses on building hands-on experience with:

- Azure Infrastructure-as-Code using Bicep
- Azure CLI automation workflows
- Azure networking architecture
- Cloud security best practices
- Azure governance and policy enforcement
- Identity and access management
- Compute and storage deployment
- Monitoring and operational management
- Cost optimization strategies

The architecture follows Microsoft Azure best practices with an emphasis on secure, scalable, and repeatable deployments.

---

# 🔍 Project Overview

The objective of this project is to build and evolve a realistic Azure environment that reflects how organizations deploy and operate cloud infrastructure.

All infrastructure deployments are performed using:

- Azure CLI commands
- Azure Bicep templates
- Git-based version control

Azure Portal is used only for:

- Deployment verification
- Resource validation
- Monitoring dashboards
- Reviewing metrics and logs
- Troubleshooting configuration issues


The environment is structured into two resource groups representing different operational purposes:

---

# 🏗️ Azure Environment Architecture

## Azure Subscription

**Subscription Name:** HomeLab

---

## Resource Groups

### HomeLab_RG

**Environment Tag:** `prod`

Purpose:

Primary production-style Azure environment containing shared infrastructure and enterprise services.

Planned and implemented resources:

- Core networking components
- Hub virtual network
- Security services
- Azure Firewall
- Jump Box administrative access
- Monitoring services
- Shared infrastructure components

---

### DevLab_RG

**Environment Tag:** `testing`

Purpose:

Development and testing environment used for validating Azure CLI commands, Bicep templates, and infrastructure changes before production deployment.

Planned and implemented resources:

- Test virtual machines
- Application workloads
- Storage resources
- Network testing scenarios
- Bicep deployment validation

---

# 🌎 Azure Regions

Primary deployment regions:

- East US
- East US 2

Regional governance is enforced through Azure Policy and deployment standards.

---

# 🧱 Infrastructure Architecture

The environment follows a simplified enterprise architecture model:
