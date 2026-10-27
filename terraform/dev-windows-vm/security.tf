# Allow RDP only from Prod-mgmt01 to Dev-win01
resource "azurerm_network_security_rule" "allow_rdp_management" {
  name      = "Allow-RDP-ManagementSubnet"
  priority  = 110
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_port_range      = "*"
  destination_port_range = "3389"

  source_address_prefix      = "10.10.0.4/32"
  destination_address_prefix = azurerm_network_interface.dev_win01_nic.private_ip_address

  resource_group_name         = data.azurerm_resource_group.devlab.name
  network_security_group_name = "AppSubnet_NSG"
}