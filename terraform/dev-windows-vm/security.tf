
# ============================================================
# Dev-win01 - Secure RDP Network Security Rules
# Updated: November 14, 2026
#
# Purpose:
# Test a more convenient method of connecting to Dev-win01
# directly through Windows App without an SSH tunnel.
#
# Security:
# - Allow RDP from approved home public IP
# - Preserve private RDP from Prod-mgmt01
# - Deny RDP from all other sources
# ============================================================


# ------------------------------------------------------------
# Rule 105 - Allow RDP from approved home public IP
# ------------------------------------------------------------

resource "azurerm_network_security_rule" "allow_rdp_home" {
  name        = "Allow-RDP-MacBook"
  description = "Allow RDP to Dev-win01 only from approved MacBook home public IP"
  priority    = 105
  direction   = "Inbound"
  access      = "Allow"
  protocol    = "Tcp"

  source_port_range      = "*"
  destination_port_range = "3389"

  source_address_prefix      = "69.250.140.202/32"
  destination_address_prefix = "10.20.1.5/32"

  resource_group_name         = data.azurerm_resource_group.devlab.name
  network_security_group_name = "AppSubnet_NSG"
}


# ------------------------------------------------------------
# Rule 110 - Preserve private RDP from Prod-mgmt01
# ------------------------------------------------------------

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


# ------------------------------------------------------------
# Rule 120 - Deny all other inbound RDP to Dev-win01
# ------------------------------------------------------------

resource "azurerm_network_security_rule" "deny_rdp_other" {
  name        = "Deny-RDP-NonManagement"
  description = "Deny RDP to Dev-win01 from all sources except the management VM allowed at priority 110"
  priority    = 120
  direction   = "Inbound"
  access      = "Deny"
  protocol    = "Tcp"

  source_port_range      = "*"
  destination_port_range = "3389"

  source_address_prefix      = "*"
  destination_address_prefix = "10.20.1.5/32"

  resource_group_name         = data.azurerm_resource_group.devlab.name
  network_security_group_name = "AppSubnet_NSG"
}
