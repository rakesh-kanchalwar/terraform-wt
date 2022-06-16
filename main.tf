########################################### Create resource group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = { "name" = "resource_group", "env" = "bootcamp" }
}

########################################### Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = var.virtual_network
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "public_subnet" {
  name                 = var.public_sub_name
  address_prefixes     = ["10.0.1.0/24"]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "private_subnet" {
  name                 = var.private_sub_name
  address_prefixes     = ["10.0.2.0/24"]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_group" "public_nsg" {
  name                = "btc_public_nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

}

#########################################################Create DB VM
resource "azurerm_network_interface" "private_nic" {
  name                = "private_nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "private_nic_ip"
    subnet_id                     = azurerm_subnet.private_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "lvm" {
  name                = "btc-db"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  size                = "Standard_B1ms"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.private_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "18.04.202206090"
  }
}

resource "azurerm_managed_disk" "m_disk" {
  name                 = "managed_disk"
  location             = var.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 16
}

resource "azurerm_virtual_machine_data_disk_attachment" "m_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.m_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.lvm.id
  lun                = "10"
  caching            = "ReadWrite"
}

#####################################################Security Group

resource "azurerm_network_security_group" "private_nsg" {
  name                = "btc_private_nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  
}
resource "azurerm_network_security_rule" "allow_ssh" {
  name                        = "Allow SSH port"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = var.ssh_port
  source_address_prefix       = "*"
  destination_address_prefix  = azurerm_network_interface.private_nic.private_ip_address
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.private_nsg.name
}

resource "azurerm_network_security_rule" "allow_db" {
  name                        = "Allow database port"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = var.db_port
  source_address_prefix       = "*"
  destination_address_prefix  = azurerm_network_interface.private_nic.private_ip_address
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.private_nsg.name
}

resource "azurerm_network_security_rule" "deny_ssh" {
  name                        = "Deny SSH from all"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = var.ssh_port
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.private_nsg.name
}

resource "azurerm_network_security_rule" "deny_db" {
  name                        = "Deny db from all"
  priority                    = 400
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = var.db_port
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.private_nsg.name
}

resource "azurerm_subnet_network_security_group_association" "private_subnet_sg" {
  subnet_id                 = azurerm_subnet.private_subnet.id
  network_security_group_id = azurerm_network_security_group.private_nsg.id
}