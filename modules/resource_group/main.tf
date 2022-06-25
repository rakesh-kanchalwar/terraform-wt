########################################### Create resource group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = { "name" = "resource_group", "env" = "bootcamp" }
}
