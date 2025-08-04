# Step 3 – Create Network Security Group (NSG)

In this step, we retrieve the existing Network Security Group (HomeLabNSG) and configure inbound rules to allow secure remote access and internal VM communication. Rules are added to allow:
Remote Desktop Protocol (RDP) access for Windows VMs
Secure Shell (SSH) access for Linux VMs
ICMP (Ping) traffic for basic connectivity testing
Internal communication between VMs on the same virtual network

## 💻 Azure PowerShell Commands
```powershell
# ---------------------------------------------
# Set your current public IP address
# ---------------------------------------------

$myIP = "YOUR_PUBLIC_IP/32"

# ---------------------------------------------
# Retrieve the existing Network Security Group
# ---------------------------------------------

$nsg = Get-AzNetworkSecurityGroup -Name "HomeLabNSG" -ResourceGroupName "HomeLabRG"

# ---------------------------------------------
# Add Inbound Rule to Allow RDP (TCP 3389) from your IP
# ---------------------------------------------

$nsg.SecurityRules += New-AzNetworkSecurityRuleConfig -Name "Allow-RDP" -Protocol "Tcp" -Direction "Inbound" `
  -Priority 1000 -SourceAddressPrefix $myIP -SourcePortRange "*" -DestinationPortRange 3389 `
  -Access "Allow" -DestinationAddressPrefix "*"

# ---------------------------------------------
# Add Inbound Rule to Allow SSH (TCP 22) from your IP
# ---------------------------------------------

$nsg.SecurityRules += New-AzNetworkSecurityRuleConfig -Name "Allow-SSH" -Protocol "Tcp" -Direction "Inbound" `
  -Priority 1001 -SourceAddressPrefix $myIP -SourcePortRange "*" -DestinationPortRange 22 `
  -Access "Allow" -DestinationAddressPrefix "*"

# ---------------------------------------------
# Add Inbound Rule to Allow Ping (ICMP)
# ---------------------------------------------

$nsg.SecurityRules += New-AzNetworkSecurityRuleConfig -Name "Allow-Ping" -Protocol "Icmp" -Direction "Inbound" `
  -Priority 1002 -SourceAddressPrefix "*" -SourcePortRange "*" -DestinationPortRange "*" `
  -Access "Allow" -DestinationAddressPrefix "*"

# ---------------------------------------------
# Add Inbound Rule to Allow Internal Subnet Communication
# ---------------------------------------------

$nsg.SecurityRules += New-AzNetworkSecurityRuleConfig -Name "Allow-Internal-Subnet" `
  -Description "Allow VMs to talk to each other within the Virtual Network" `
  -Access "Allow" -Protocol "*" -Direction "Inbound" -Priority 100 `
  -SourceAddressPrefix "VirtualNetwork" -SourcePortRange "*" `
  -DestinationAddressPrefix "VirtualNetwork" -DestinationPortRange "*"

# ---------------------------------------------
# Apply the Updated Rule Set to the NSG
# ---------------------------------------------

Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg

