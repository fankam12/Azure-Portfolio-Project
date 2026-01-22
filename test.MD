# Azure HomeLab – Cloud Engineering Lab

## Overview

This HomeLab simulates a **secure Azure enterprise environment** designed for hands-on learning, AZ-104 exam preparation, and real-world cloud engineering scenarios. The lab emphasizes:

- Multi-subnet architecture for management and application workloads
- Secure remote access via JumpBox through Azure Firewall
- Cost control via budgets and automated VM shutdown
- Governance enforcement with Azure Policy

**Primary objectives:**

1. Hands-on practice for AZ-104 domains (identity, networking, governance, monitoring)
2. Simulate real-world cloud engineering tasks in a **scalable, secure, and cost-efficient environment**
3. Enable secure administrative access through a **JumpBox VM** protected by **Azure Firewall and NSGs**

---

## Lab Environment Details

| Component | Name / IP | Purpose | Notes |
|-----------|-----------|--------|-------|
| Resource Groups | HomeLabRG, ProdHomeRG | Organize resources for lab & production-style workloads | Separate environments for skills testing and enterprise simulation |
| VNets | HomeLabVNet (10.0.0.0/16), ProdHomeVNet (10.1.0.0/16) | Network segmentation | Peered for secure cross-VNet communication |
| Subnets | JumpBoxSubnet (10.0.0.0/24), AppSubnet1 (10.0.1.0/24), AppSubnet2 (10.0.2.0/24), AzureFirewallSubnet (10.0.3.0/26) | Segregation of roles: management vs application vs firewall | UDR applied to subnets (except firewall) |
| VMs | JumpBox (10.0.0.4), AppVM1 (10.0.1.5), AppVM2 (10.0.2.7) | JumpBox for secure admin access; AppVMs for workloads | All stopped when not in use to control costs |
| Azure Firewall | HomeLab-Firewall | Centralized network traffic inspection | Public IP: 172.172.136.196; routes and DNAT applied |
| Firewall Policy | HomeLab-FW-Policy | Organizes DNAT, network rules | Includes DNAT for JumpBox RDP and network rules for outbound traffic |
| Route Table (UDR) | HomeLab-Default-Route | Forces outbound traffic through firewall | Applied to JumpBoxSubnet, AppSubnet1, AppSubnet2 |
| NSGs | JumpBox-nsg | Control inbound traffic | Only allows RDP from firewall subnet (10.0.3.0/26) |
| Policies | Restrict-Regions-EastUS | Enforces deployment only in East US / East US 2 | Governance best practice |
| Budget | HomeLab-Monthly-Budget | Alerts at 70%, 80%, 85%, 100% | Ensures cost control |

---

## Lab Architecture Diagram

![HomeLab Architecture](HomeLab_Cloud_Environment_O.png)

**Diagram Explanation:**

- **JumpBox in front of Firewall:** secure admin access; all RDP traffic passes through DNAT rules.  
- **Azure Firewall:** inspects inbound/outbound traffic; forced routing (UDR) ensures traffic is logged and filtered.  
- **NSGs:** defense-in-depth; only allow traffic from firewall subnet to JumpBox.  
- **Subnets Segmentation:** simulates multi-tier apps with separate App subnets.  
- **VNet Peering:** enables secure communication with ProdHomeVNet for expansion or production-style simulations.

---

## Security Measures

- **Azure Firewall with DNAT** – protects JumpBox from direct exposure to the internet  
- **NSG restricted RDP access** – only from Firewall subnet  
- **Forced routing via Firewall (UDR)** – all outbound traffic is inspected  
- **Region restriction policies** – ensures all resources deployed in East US / East US 2  

**Suggested Enhancements:**

1. Enable Firewall **Threat Intelligence** to block malicious IPs  
2. Enable **TLS inspection** (Premium Firewall SKU) for HTTPS traffic  
3. Configure **Application rules** to restrict internet access to approved FQDNs  
4. Enable **Azure Monitor / Log Analytics** for monitoring and alerting  
5. Deploy **Azure Key Vault** for secure secret storage  
6. Enable **Azure Defender / Security Center** for continuous security assessment

---

## Suggested Real-World Projects

These projects simulate the tasks of **Cloud Engineers / Platform Engineers**:

### Project 1 – Multi-Tier Web Application Deployment
- Deploy a 3-tier application (Web / App / DB) in separate subnets
- Skills: NSG segmentation, Firewall rules, private endpoints, scaling
- AZ-104 Domains: VMs, networking, NSGs, load balancers
- Real-World Relevance: Enterprise multi-tier app deployment

### Project 2 – Cost Management & Auto-Shutdown Policies
- Configure budgets, alerts, and automatic VM shutdown/start
- Skills: Azure Policy, Automation accounts, cost alerts, tagging
- AZ-104 Domains: Monitoring, governance, cost control
- Real-World Relevance: Platform engineers manage costs across environments

### Project 3 – Secure Remote Access & Conditional Access
- Implement Azure Bastion or JumpBox with DNAT, NSG, and MFA
- Skills: Network security, conditional access, RDP through firewall
- AZ-104 Domains: Identity, network security, governance
- Real-World Relevance: Enterprise zero-trust access for management VMs

### Project 4 – Monitoring & Alerts for Workloads
- Enable Azure Monitor, Log Analytics, and create dashboards/alerts
- Skills: Log Analytics queries, alert rules, dashboards
- AZ-104 Domains: Monitoring, diagnostics, operational excellence
- Real-World Relevance: Detect anomalies and respond proactively

### Project 5 – Hybrid Connectivity Simulation
- Setup VNet Peering + VPN Gateway/ExpressRoute simulation to ProdHomeRG
- Skills: Peering, VPN Gateway, routing, firewall, NSG
- AZ-104 Domains: Networking, routing, secure connectivity
- Real-World Relevance: Integrate on-premises and cloud networks securely

---

## Conclusion

Your HomeLab replicates a **production-like Azure environment**, demonstrating:

- Secure remote administration (JumpBox + Firewall + NSG + DNAT)  
- Segmented network architecture and multi-tier design  
- Governance with Azure Policy and budget controls  
- Traffic inspection via UDR and firewall

This environment is ready for **hands-on AZ-104 practice** and **real-world project implementation**. Future expansions can include Threat Intelligence, Key Vault integration, TLS inspection, and more advanced monitoring dashboards.

---

**GitHub File Notes:**

- Diagram file: `HomeLab_Cloud_Environment_O.png`  
- Include README.md in the root repository  
- Optional: add step-by-step lab scripts (Azure Portal & PowerShell) in a `/Labs` folder for reproducibility
