
---

## 📄 `Phase1/02_Create_VNet_Subnet.md`
```markdown
# Step 2 – Create Virtual Network and Subnet

The VNet allows all VMs to exist within a private, isolated network.

## 💻 Azure PowerShell Commands
```powershell
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name HomeLabSubnet -AddressPrefix "10.0.0.0/24"

New-AzVirtualNetwork -Name HomeLabVNet -ResourceGroupName HomeLabRG -Location "East US" `
    -AddressPrefix "10.0.0.0/16" -Subnet $subnetConfig
