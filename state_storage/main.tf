terraform {

}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "tfstate_rg" {
  name = "tfstate-rg"
  location = "eastus"
}

resource "azurerm_storage_account" "tfstate_storage" {
    name = "tfstatestorage17062022"
    resource_group_name = azurerm_resource_group.tfstate_rg.name
    location = "eastus"
    account_tier = "Standard"
    account_replication_type = "LRS"
}

resource "azurerm_storage_container" "tfstate_container" {
  name = "statecontainer"
  storage_account_name = azurerm_storage_account.tfstate_storage.name
}