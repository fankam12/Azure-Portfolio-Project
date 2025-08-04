# Step 2 – Create Virtual Network and Subnet

The VNet allows all VMs to exist within a private, isolated network.

## 💻 Azure PowerShell Commands
```powershell
# ---------------------------------------------
# Create Subnet Configuration (not deployed yet)
# ---------------------------------------------
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name HomeLabSubnet -AddressPrefix "10.0.0.0/24"

# ---------------------------------------------
# Create Virtual Network and Attach the Subnet
# ---------------------------------------------
New-AzVirtualNetwork -Name HomeLabVNet -ResourceGroupName HomeLabRG -Location "East US" `
    -AddressPrefix "10.0.0.0/16" -Subnet $subnetConfig
