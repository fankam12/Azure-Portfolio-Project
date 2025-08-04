# Step 3 – Create Network Security Group (NSG)

An NSG is used to control inbound and outbound traffic to network interfaces, VMs, and subnets.

## 💻 Azure PowerShell Commands
```powershell
# ---------------------------------------------
# Create a Network Security Group named 'HomeLabNSG'
# ---------------------------------------------
New-AzNetworkSecurityGroup -ResourceGroupName HomeLabRG -Location "East US" -Name HomeLabNSG


# ---------------------------------------------
# Create Inbound Rule to Allow Internal Subnet Communication
# ---------------------------------------------
$nsgRule = New-AzNetworkSecurityRuleConfig -Name "Allow-Internal-Subnet" `
  -Description "Allow VMs to talk to each other within the Virtual Network" `
  -Access Allow -Protocol * -Direction Inbound -Priority 100 `
  -SourceAddressPrefix "VirtualNetwork" -SourcePortRange * `
  -DestinationAddressPrefix "VirtualNetwork" -DestinationPortRange "*"

# ---------------------------------------------
# Retrieve the NSG and Add the Inbound Rule
# ---------------------------------------------
$nsg = Get-AzNetworkSecurityGroup -Name HomeLabNSG -ResourceGroupName HomeLabRG
$nsg.SecurityRules.Add($nsgRule)

# ---------------------------------------------
# Apply the Updated Rule Set to the NSG
# ---------------------------------------------
Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg
