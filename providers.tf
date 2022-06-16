terraform {
  #  required_providers {
  #    azurerm = {
  #      source  = "hashicorp/azurerm"
  #      version = "=3.9.0"
  #    }
  #  }
  #  backend "azurerm" {
  #    resource_group_name  = "tfstate"
  #    storage_account_name = "value"
  #    container_name       = "value"
  #    key                  = "value"
  #  }
}

provider "azurerm" {
  features {}
}