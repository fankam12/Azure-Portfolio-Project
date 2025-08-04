# Step 4 – Create Virtual Machines (via Azure PowerShell)

In this step, we create up to four virtual machines inside the `HomeLabRG` resource group, associate them with the same subnet (`HomeLabSubnet`), virtual network (`HomeLabVNet`), and apply the existing network security group (`HomeLabNSG`) to their network interfaces.

## 💻 Azure PowerShell Commands
```powershell
# ---------------------------------------------
# Set common configuration variables
# ---------------------------------------------
$resourceGroup = "HomeLabRG"
$location = "East US"
$vnet = Get-AzVirtualNetwork -Name "HomeLabVNet" -ResourceGroupName $resourceGroup
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "HomeLabSubnet" -VirtualNetwork $vnet
$nsg = Get-AzNetworkSecurityGroup -Name "HomeLabNSG" -ResourceGroupName $resourceGroup

# ---------------------------------------------
# Loop to Create 4 VMs: HomeLabVM01–HomeLabVM04
# ---------------------------------------------
1..4 | ForEach-Object {
    $vmName = "HomeLabVM0$_"
    $nicName = "$vmName-NIC"

    # Create NIC and associate with subnet and NSG
    $nic = New-AzNetworkInterface -Name $nicName `
        -ResourceGroupName $resourceGroup -Location $location `
        -SubnetId $subnet.Id -NetworkSecurityGroupId $nsg.Id

    # Define VM configuration
    $vmConfig = New-AzVMConfig -VMName $vmName -VMSize "Standard_B1s" |
        Set-AzVMOperatingSystem -Linux -ComputerName $vmName -Credential (Get-Credential) |
        Set-AzVMSourceImage -PublisherName "Canonical" -Offer "UbuntuServer" -Skus "20_04-lts" -Version "latest" |
        Add-AzVMNetworkInterface -Id $nic.Id

    # Create the VM
    New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig
}
