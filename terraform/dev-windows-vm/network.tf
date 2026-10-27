# Network interface for Dev-win01
resource "azurerm_network_interface" "dev_win01_nic" {
  name                = "Dev-win01-nic"
  location            = data.azurerm_resource_group.devlab.location
  resource_group_name = data.azurerm_resource_group.devlab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.20.1.5"
  }

  tags = {
    Environment = "Dev"
    Project     = "AzureCloudPortfolio"
    ManagedBy   = "Terraform"
  }
}