########################################### Create resource group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = { "name" = "resource_group", "env" = "bootcamp" }
}

########################################### Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = var.virtual_network
  address_space       = [var.vnet_address_space]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "public_subnet" {
  name                 = var.public_sub_name
  address_prefixes     = [var.public_subnet_address_space]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "private_subnet" {
  name                 = var.private_sub_name
  address_prefixes     = [var.private_subnet_address_space]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
}

################################Load Balancer Configurations#############################################

resource "azurerm_public_ip" "public_ip" {
  name                = "btc_public_ip_address"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_lb" "lb" {
  name                = "btc_lb"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Basic"

  frontend_ip_configuration {
    name                 = "btc_public_ip"
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_lb_backend_address_pool" "add_pool" {
  name            = "btc_back-address-pool"
  loadbalancer_id = azurerm_lb.lb.id
}

#resource "azurerm_lb_probe" "health_probe" {
#  loadbalancer_id = azurerm_lb.lb.id
#  name            = "${azurerm_lb.lb.name}_health_probe"
#  port            = var.application_port
#}

resource "azurerm_lb_rule" "lb_rule" {
  name                           = "btc_lb_rule"
  loadbalancer_id                = azurerm_lb.lb.id
  backend_port                   = var.application_port
  frontend_port                  = var.application_port
  protocol                       = "Tcp"
  frontend_ip_configuration_name = azurerm_lb.lb.frontend_ip_configuration[0].name
  #probe_id                       = azurerm_lb_probe.health_probe.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.add_pool.id]
}

resource "azurerm_lb_nat_pool" "lb_nat_pool" {
  name = "lb_nat_pool"
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id = azurerm_lb.lb.id
  protocol = "Tcp"
  frontend_port_start = 200
  frontend_port_end = 202
  backend_port = 22
  frontend_ip_configuration_name = azurerm_lb.lb.frontend_ip_configuration[0].name
}

#########################################################Create application VM
resource "azurerm_linux_virtual_machine_scale_set" "lvm_app" {
  name                            = "btc-app"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = var.location
  sku                             = var.vm_sku
  instances                       = var.scale_set_instances
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

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

  network_interface {
    name                      = "public_nic"
    primary                   = true
    network_security_group_id = azurerm_network_security_group.public_nsg.id
    ip_configuration {
      name                                   = "nic"
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.add_pool.id]
      subnet_id                              = azurerm_subnet.public_subnet.id
    }
  }

  #health_probe_id = azurerm_lb_probe.health_probe.id

  data_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    create_option        = "Empty"
    disk_size_gb         = 16
    lun                  = "30"
  }
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

resource "azurerm_linux_virtual_machine" "lvm_db" {
  name                            = "btc-db"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = var.location
  size                            = var.vm_sku
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
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
  name                 = "managed_disk"
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

#####################################################Security Group
###############Public
resource "azurerm_network_security_group" "public_nsg" {
  name                = "btc_public_nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
}

resource "azurerm_network_security_rule" "pub_deny_ssh" {
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
  network_security_group_name = azurerm_network_security_group.public_nsg.name
}

resource "azurerm_network_security_rule" "pub_deny_http" {
  name                   = "Deny db from all"
  priority               = 400
  direction              = "Inbound"
  access                 = "Deny"
  protocol               = "Tcp"
  source_port_range      = "*"
  destination_port_range = "*"
  source_address_prefix  = "*"

  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.public_nsg.name
}


###############Private
resource "azurerm_network_security_group" "private_nsg" {
  name                = "btc_private_nsg"
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