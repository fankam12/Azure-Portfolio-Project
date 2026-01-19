# Lab 1 – Azure Governance, Policy & Cost Management

## Overview
This lab establishes foundational governance controls within an Azure subscription by implementing cost management budgets, alerts, tagging standards, and Azure Policy. These controls ensure that all future resources remain compliant, cost-efficient, and aligned with organizational standards. Monitoring and notifications are configured to proactively manage spending and reduce the risk of misconfigurations. This lab provides the governance baseline required for all subsequent Azure workloads.

---

## AZ-104 Exam Domains Covered

### Manage Azure Subscriptions and Governance
- Configure budgets and cost alerts
- Implement Azure Policy
- Apply and enforce tagging standards
- Manage resource groups

### Monitor and Maintain Azure Resources
- Cost analysis and reporting
- Alerts and action groups

---

## Lab Architecture (Initial State)

Azure Subscription: HomeLab
│
├── Resource Group: HomeLabRG
│
├── Azure Budgets
│   ├── HomeLab-Monthly-Budget
│   │   ├── Warning Alert – 70%
│   │   ├── High Alert – 85%
│   │   └── Critical Alert – 100%
│
├── Azure Policy Assignments
│   ├── Allowed Locations
│   │   └── East US, East US 2
│   ├── Required Resource Tags
│   └── Public IP Restrictions (future)
│
└── Action Groups
    └── HomeLab-Cost-Alerts
        └── Email Notifications


This architecture will expand in future labs to include networking, compute, storage, and monitoring resources.

---

## Key Configuration Summary

### Azure Budget
- **Name:** HomeLab-Monthly-Budget
- **Amount:** $100 USD
- **Reset Period:** Monthly
- **Scope:** Subscription-level
- **Purpose:** Maintain actual spend within a preferred $80–$90 range

### Cost Alerts
| Alert Level | Threshold | Action |
|------------|----------|--------|
| Warning | 70% | Email Notification |
| High | 85% | Email Notification |
| Critical | 100% | Email Notification |

### Action Group
- **Name:** HomeLab-Cost-Alerts
- **Notification Type:** Email
- **Scope:** Subscription-level

---

## Automation & Infrastructure as Code Alignment
This lab introduces Azure PowerShell to support repeatable and auditable governance configurations. While some controls are initially created manually for learning and visibility, automation principles are applied to align with Infrastructure as Code (IaC) best practices. Future labs will extend this foundation using Terraform and CI/CD pipelines.

---

## Why This Matters
Lack of governance is one of the primary causes of cost overruns and security gaps in cloud environments. This lab ensures that every resource deployed in future labs is monitored, compliant, and financially accountable. Cost alerts provide early visibility into abnormal spending patterns and help enforce financial discipline. Implementing governance first prevents architectural rework and unexpected billing issues. This approach reflects how enterprises implement Azure governance and FinOps practices at scale.

---

## Next Lab
**Lab 2 – Azure Identity & Access Management (IAM)**  
Azure AD users and groups, RBAC, and least-privilege access enforcement.
