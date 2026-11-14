
# Reference the existing public IP created through Azure CLI
data "azurerm_public_ip" "dev_win01_public_ip" {
  name                = "Dev-win01-PublicIP"
  resource_group_name = data.azurerm_resource_group.devlab.name
}

# Network interface for Dev-win01
resource "azurerm_network_interface" "dev_win01_nic" {
  name                = "Dev-win01-nic"
  location            = data.azurerm_resource_group.devlab.location
  resource_group_name = data.azurerm_resource_group.devlab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.app_subnet.id

    # Preserve the existing static private IP
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.20.1.5"

    # Associate the existing static public IP
    public_ip_address_id = data.azurerm_public_ip.dev_win01_public_ip.id
  }

  tags = {
    Environment = "Dev"
    Project     = "AzureCloudPortfolio"
    ManagedBy   = "Terraform"
  }
}
