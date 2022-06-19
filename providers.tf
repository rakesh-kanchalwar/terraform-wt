terraform {
  #  required_providers {
  #    azurerm = {
  #      source  = "hashicorp/azurerm"
  #      version = "=3.9.0"
  #    }
  #  }
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstatestorage17062022"
    container_name       = "statecontainer"
    key                  = "terraform_bonus.tfstate"
  }
}

provider "azurerm" {
  features {}
}