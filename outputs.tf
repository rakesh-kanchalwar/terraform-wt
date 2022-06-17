output "resource_group_id" {
  value = azurerm_resource_group.rg.id
}

output "public_ip" {
  value = azurerm_public_ip.public_ip.ip_address
}

output "private_ip" {
  value = azurerm_network_interface.private_nic.private_ip_address
}
