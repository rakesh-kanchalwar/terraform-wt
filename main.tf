########################################### Create resource group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = { "name" = "resource_group", "env" = "bootcamp_bonus" }
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

################################Load Balancer Configurations#############################################

resource "azurerm_public_ip" "public_ip" {
  name                = "btc_bonus_public_ip_address"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "lb" {
  name                = "btc_lb_bonus"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "btc_public_ip_bonus"
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_lb_backend_address_pool" "add_pool" {
  name            = "btc_bonus_back-address-pool"
  loadbalancer_id = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "health_probe" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "${azurerm_lb.lb.name}_bonus_health_probe"
  port            = var.application_port
}

resource "azurerm_lb_rule" "lb_rule" {
  name                           = "btc_lb_rule_bonus"
  loadbalancer_id                = azurerm_lb.lb.id
  backend_port                   = var.application_port
  frontend_port                  = var.application_port
  protocol                       = "Tcp"
  frontend_ip_configuration_name = azurerm_lb.lb.frontend_ip_configuration[0].name
  probe_id                       = azurerm_lb_probe.health_probe.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.add_pool.id]
}


resource "azurerm_lb_nat_pool" "lb_nat_pool" {
  name                           = "lb_nat_pool_bonus"
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port_start            = 200
  frontend_port_end              = 210
  backend_port                   = 22
  frontend_ip_configuration_name = azurerm_lb.lb.frontend_ip_configuration[0].name
}
#########################################################Create Password
resource "random_password" "password" {
  count   = var.scale_set_instances
  length  = 12
  special = false
  upper = true
  lower = true
  number = true
}
#########################################################Create application VM
resource "azurerm_linux_virtual_machine_scale_set" "lvm_app" {
  name                            = "btc-app-bonus"
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
    name                      = "public_nic_bonus"
    primary                   = true
    #network_security_group_id = azurerm_network_security_group.public_nsg.id
    ip_configuration {
      name                                   = "nic-bonus"
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.add_pool.id]
      load_balancer_inbound_nat_rules_ids    = [azurerm_lb_nat_pool.lb_nat_pool.id]
      subnet_id                              = azurerm_subnet.public_subnet.id
    }
  }

  health_probe_id = azurerm_lb_probe.health_probe.id

  data_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    create_option        = "Empty"
    disk_size_gb         = 16
    lun                  = "30"
  }
}

#####################################################Security Group
###############Public
resource "azurerm_network_security_group" "public_nsg" {
  name                = "btc_public_nsg_bonus"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
}

resource "azurerm_network_security_rule" "pub_allow_ssh" {
  name                        = "Allow SSH port"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = var.ssh_port
  source_address_prefix       = var.my_ip_address
  destination_address_prefix  = var.public_subnet_address_space
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.public_nsg.name
}

resource "azurerm_network_security_rule" "pub_allow_http" {
  name                        = "Allow Http port"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = var.http_port
  source_address_prefix       = "*"
  destination_address_prefix  = var.public_subnet_address_space
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.public_nsg.name
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

resource "azurerm_subnet_network_security_group_association" "public_subnet_sg" {
  subnet_id                 = azurerm_subnet.public_subnet.id
  network_security_group_id = azurerm_network_security_group.public_nsg.id
}


