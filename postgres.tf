resource "azurerm_subnet" "private_subnet" {
  name                 = var.private_sub_name
  address_prefixes     = [var.private_subnet_address_space]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
}
#########################################################Create Password
resource "random_password" "password_db" {
  length  = 12
  special = false
  upper = true
  lower = true
  number = true
}
#########################################################Create DB VM
resource "azurerm_network_interface" "private_nic" {
  name                = "private_nic_bonus"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "private_nic_ip_bonus"
    subnet_id                     = azurerm_subnet.private_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "lvm_db" {
  name                            = "btc-db-bonus"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = var.location
  size                            = var.vm_sku
  admin_username                  = var.admin_username
  admin_password                  = random_password.password_db.result
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.private_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }
}

resource "azurerm_managed_disk" "m_disk" {
  name                 = "managed_disk_db"
  location             = var.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 16
}

resource "azurerm_virtual_machine_data_disk_attachment" "m_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.m_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.lvm_db.id
  lun                = "10"
  caching            = "ReadWrite"
}
###############Private
resource "azurerm_network_security_group" "private_nsg" {
  name                = "btc_private_nsg_bonus"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "private_allow_ssh" {
  name                        = "Allow SSH port"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = var.ssh_port
  source_address_prefixes     = azurerm_subnet.public_subnet.address_prefixes
  destination_address_prefix  = azurerm_network_interface.private_nic.private_ip_address
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.private_nsg.name
}

resource "azurerm_network_security_rule" "private_allow_db" {
  name                        = "Allow database port"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = var.db_port
  source_address_prefixes     = azurerm_subnet.public_subnet.address_prefixes
  destination_address_prefix  = azurerm_network_interface.private_nic.private_ip_address
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.private_nsg.name
}

resource "azurerm_network_security_rule" "private_deny_ssh" {
  name                        = "Deny SSH from all"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.private_nsg.name
}

resource "azurerm_network_security_rule" "private_deny_db" {
  name                        = "Deny db from all"
  priority                    = 400
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.private_nsg.name
}

resource "azurerm_subnet_network_security_group_association" "private_subnet_sg" {
  subnet_id                 = azurerm_subnet.private_subnet.id
  network_security_group_id = azurerm_network_security_group.private_nsg.id
}