
---

## 📄 `Phase1/03_Create_NSG.md`
```markdown
# Step 3 – Create Network Security Group (NSG)

NSG is used to control inbound and outbound traffic for your VMs.

## 💻 PowerShell Command
```powershell
New-AzNetworkSecurityGroup -ResourceGroupName HomeLabRG -Location "East US" -Name HomeLabNSG


Inbound Rule to Allow Internal Subnet Communication:


$nsgRule = New-AzNetworkSecurityRuleConfig -Name "Allow-Internal-Subnet" -Description "Allow VMs to talk to each other" `
  -Access Allow -Protocol * -Direction Inbound -Priority 100 `
  -SourceAddressPrefix "VirtualNetwork" -SourcePortRange * `
  -DestinationAddressPrefix "VirtualNetwork" -DestinationPortRange "*"

$nsg = Get-AzNetworkSecurityGroup -Name HomeLabNSG -ResourceGroupName HomeLabRG
$nsg.SecurityRules.Add($nsgRule)
Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg
