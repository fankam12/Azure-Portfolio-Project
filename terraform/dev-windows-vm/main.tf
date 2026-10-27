# Reference the existing DevLab resource group
data "azurerm_resource_group" "devlab" {
  name = "DevLab_RG"
}

# Reference the existing DevLab virtual network
data "azurerm_virtual_network" "devlab_vnet" {
  name                = "Devlab_VNet"
  resource_group_name = data.azurerm_resource_group.devlab.name
}

# Reference the existing application subnet
data "azurerm_subnet" "app_subnet" {
  name                 = "AppSubnet"
  virtual_network_name = data.azurerm_virtual_network.devlab_vnet.name
  resource_group_name  = data.azurerm_resource_group.devlab.name
}

# Deploy Windows Server 2022 in DevLab
resource "azurerm_windows_virtual_machine" "dev_win01" {
  name                = "Dev-win01"
  resource_group_name = data.azurerm_resource_group.devlab.name
  location            = data.azurerm_resource_group.devlab.location
  size                = "Standard_D2as_v7"

  admin_username = "azureadmin"
  admin_password = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.dev_win01_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  tags = {
    Environment = "Dev"
    Project     = "AzureCloudPortfolio"
    ManagedBy   = "Terraform"
  }
}