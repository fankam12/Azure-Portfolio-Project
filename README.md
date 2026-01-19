
# Azure Portfolio Project — Home lab Infrastructure

This repository documents a **hands-on, production-aligned Azure home lab** designed to reinforce **all domains of the AZ-104: Microsoft Azure Administrator certification**.  

The lab simulates a **secure, cost-aware, enterprise-style Azure environment** using **Azure Portal** and **Azure PowerShell**, with a strong emphasis on governance, networking, security, monitoring, and automation.

---

## 🔍 Project Overview

The objective of this project is to build and evolve a realistic Azure environment that mirrors how organizations design, secure, and operate cloud infrastructure in production.

The lab is structured around **two primary resource groups** within a single Azure subscription:

- **HomeLabRG** – Core learning and experimentation environment  
- **ProdHome** – A controlled, production-like environment for larger-scale scenarios  

All resources are deployed in **East US** and **East US 2** and governed through **Azure Policy**, **budgets**, and **monitoring alerts** to enforce cost control and regional compliance.

This project grows incrementally through structured labs, each aligned to specific **AZ-104 exam objectives** and **real-world cloud engineering responsibilities**.

---

## 🎯 Project Goals

- Reinforce **all AZ-104 exam domains** through hands-on, scenario-driven labs  
- Build strong operational skills using **Azure Portal** and **Azure PowerShell**  
- Apply **Azure best practices** for security, networking, governance, and cost management  
- Simulate a real organizational Azure ecosystem with segmented environments  
- Maintain a **monthly cost target of $80–$100** (hard cap at $120)  
- Produce **professional-quality documentation and architecture diagrams** suitable for a public portfolio  

---

## 🧱 Core Architecture (Evolving)

### Subscription
- **Subscription Name:** HomeLab

### Resource Groups

#### HomeLabRG
- Primary lab environment  
- Foundational networking, security, and identity services  
- **4–6 virtual machines**

#### ProdHome
- Production-style environment  
- **2–6 virtual machines**  
- Secure connectivity to **HomeLabRG**

---

## 🌐 Networking & Security (Planned / Implemented)

- Hub-and-spoke virtual network architecture  
- Dedicated **Jump Box VM** for secure administrative access  
- Network Security Groups (NSGs)  
- Azure Firewall with firewall policies  
- User-defined routes (UDRs)  
- Private IP–only workloads where possible  
- Secure inter-resource group communication  

---

## 🔐 Governance, Security & Cost Management

### Azure Policy
- Restrict resource deployment to **East US** and **East US 2**  
- Enforce standardized **resource tagging**

### Azure Budgets & Alerts
- Monthly budget: **$100**
  - Alerts at **50%**, **75%**, and **90%**  
- Cost anomaly alerts

### Operational Controls
- VM auto-shutdown schedules  
- Manual VM deallocation after lab usage  

### Monitoring
- Azure Monitor  
- Log Analytics Workspace  
- Custom dashboards  
- Activity log alerts  

---

## 🖥️ Compute Strategy

- Mix of **Windows Server** and **Linux** virtual machines  
- VM sizing optimized for cost (B-series where applicable)  
- Jump box pattern for secure access  
- Minimal public exposure (no direct RDP/SSH to workload VMs)  

---

## 📦 Automation & Infrastructure as Code

- **Azure PowerShell** (primary automation tool)  
- Azure Portal (full step-by-step parity with PowerShell)  
- Terraform (introduced in later phases)  
- Scripts and templates stored in **Azure-based storage**  

---

## 🚀 Why This Project Matters

This home lab goes beyond exam preparation. It demonstrates **real-world Azure administration skills**, including secure architecture design, cost control, governance enforcement, and operational monitoring—skills expected of cloud engineers and Azure administrators in production environments.

---

## 📌 Status

🟡 **In Progress** — The environment is actively expanding through structured lab phases.
