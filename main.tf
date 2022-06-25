module "rg" {
  source              = "./modules/resource_group"
  resource_group_name = var.resource_group_name
  location            = var.location
}
########################################### Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = var.virtual_network
  address_space       = [var.vnet_address_space]
  location            = var.location
  resource_group_name = module.rg.resource_group.name
}

resource "azurerm_subnet" "public_subnet" {
  name                 = var.public_sub_name
  address_prefixes     = [var.public_subnet_address_space]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = module.rg.resource_group.name
}

################################Load Balancer Configurations#############################################

resource "azurerm_public_ip" "public_ip" {
  name                = "btc_public_ip_address"
  location            = var.location
  resource_group_name = module.rg.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "lb" {
  name                = "btc_lb"
  location            = var.location
  resource_group_name = module.rg.resource_group.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "btc_public_ip"
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_lb_backend_address_pool" "add_pool" {
  name            = "btc_back-address-pool"
  loadbalancer_id = azurerm_lb.lb.id
}

resource "azurerm_lb_backend_address_pool_address" "addr-pool-addr" {
  count                   = var.scale_set_instances
  name                    = "backend-add-pool-add-${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.add_pool.id
  virtual_network_id      = azurerm_virtual_network.vnet.id
  ip_address              = azurerm_network_interface.public_nic[count.index].private_ip_address
}

resource "azurerm_lb_probe" "health_probe" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "${azurerm_lb.lb.name}_health_probe"
  port            = var.application_port
}

resource "azurerm_lb_rule" "lb_rule" {
  name                           = "btc_lb_rule"
  loadbalancer_id                = azurerm_lb.lb.id
  backend_port                   = var.application_port
  frontend_port                  = var.application_port
  protocol                       = "Tcp"
  frontend_ip_configuration_name = azurerm_lb.lb.frontend_ip_configuration[0].name
  probe_id                       = azurerm_lb_probe.health_probe.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.add_pool.id]
}

resource "azurerm_lb_nat_rule" "lb_nat_rule" {
  count                          = var.scale_set_instances
  name                           = "lb_nat_rule-${count.index}"
  resource_group_name            = module.rg.resource_group.name
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_ip_configuration_name = azurerm_lb.lb.frontend_ip_configuration[0].name
  frontend_port                  = "20${count.index}"
  backend_port                   = 22
}

resource "azurerm_network_interface_nat_rule_association" "nat_rule_assoc" {
  count                 = var.scale_set_instances
  network_interface_id  = azurerm_network_interface.public_nic[count.index].id
  ip_configuration_name = "public_nic_ip-${count.index}"
  nat_rule_id           = azurerm_lb_nat_rule.lb_nat_rule[count.index].id
}
#########################################################Create Password
resource "random_password" "password" {
  count   = var.scale_set_instances
  length  = 12
  special = false
  upper   = true
  lower   = true
  number  = true
}
#########################################################Create application VM
resource "azurerm_availability_set" "avail_set" {
  name                = "vm-availability-set"
  location            = var.location
  resource_group_name = module.rg.resource_group.name
}

resource "azurerm_network_interface" "public_nic" {
  count               = var.scale_set_instances
  name                = "public_nic-${count.index}"
  location            = var.location
  resource_group_name = module.rg.resource_group.name

  ip_configuration {
    name                          = "public_nic_ip-${count.index}"
    subnet_id                     = azurerm_subnet.public_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "lvm_app" {
  count                           = var.scale_set_instances
  name                            = "btc-app-${count.index}"
  resource_group_name             = module.rg.resource_group.name
  location                        = var.location
  size                            = var.vm_sku
  admin_username                  = var.admin_username
  admin_password                  = random_password.password[count.index].result
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.public_nic[count.index].id]

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

  availability_set_id = azurerm_availability_set.avail_set.id

}

resource "azurerm_managed_disk" "m_app_disk" {
  count                = var.scale_set_instances
  name                 = "managed_app_disk-${count.index}"
  location             = var.location
  resource_group_name  = module.rg.resource_group.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 16
}

resource "azurerm_virtual_machine_data_disk_attachment" "m_app_disk_attachment" {
  count              = var.scale_set_instances
  managed_disk_id    = azurerm_managed_disk.m_app_disk.*.id[count.index]
  virtual_machine_id = azurerm_linux_virtual_machine.lvm_app[count.index].id
  lun                = "10"
  caching            = "ReadWrite"
}


#####################################################Security Group
###############Public
resource "azurerm_network_security_group" "public_nsg" {
  name                = "btc_public_nsg"
  resource_group_name = module.rg.resource_group.name
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
  resource_group_name         = module.rg.resource_group.name
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
  resource_group_name         = module.rg.resource_group.name
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
  resource_group_name         = module.rg.resource_group.name
  network_security_group_name = azurerm_network_security_group.public_nsg.name
}

resource "azurerm_network_security_rule" "pub_deny_http" {
  name                        = "Deny Http from all"
  priority                    = 400
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = module.rg.resource_group.name
  network_security_group_name = azurerm_network_security_group.public_nsg.name
}

resource "azurerm_subnet_network_security_group_association" "public_subnet_sg" {
  subnet_id                 = azurerm_subnet.public_subnet.id
  network_security_group_id = azurerm_network_security_group.public_nsg.id
}

