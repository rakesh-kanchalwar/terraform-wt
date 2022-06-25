module "db_rg" {
  source              = "./modules/resource_group"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_subnet" "private_subnet" {
  name                 = var.private_sub_name
  address_prefixes     = [var.private_subnet_address_space]
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = module.db_rg.resource_group.name
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "fs"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_zone" "dns_zone" {
  name                = "${var.environment}.postgres.database.azure.com"
  resource_group_name = module.db_rg.resource_group.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "vn_link" {
  name                  = "${var.environment}VnetZone.com"
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = module.db_rg.resource_group.name
  registration_enabled  = true
}

resource "azurerm_postgresql_flexible_server" "flexi_server" {
  name                   = "${var.environment}-dbserver"
  resource_group_name    = module.db_rg.resource_group.name
  location               = var.location
  version                = "12"
  delegated_subnet_id    = azurerm_subnet.private_subnet.id
  private_dns_zone_id    = azurerm_private_dns_zone.dns_zone.id
  administrator_login    = var.db_admin_login
  administrator_password = var.db_admin_password
  zone                   = "1"

  storage_mb = 32768
  sku_name   = "B_Standard_B1ms"
  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.vn_link
  ]
}

resource "azurerm_postgresql_flexible_server_configuration" "ssloff" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.flexi_server.id
  value     = "off"
}
