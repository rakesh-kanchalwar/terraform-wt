output "public_ip" {
  value = azurerm_public_ip.public_ip.ip_address
}

output "password_0" {
  value = random_password.password[0].result
  sensitive = true
}

output "password_1" {
  value = random_password.password[1].result
  sensitive = true
}

output "password_2" {
  value = random_password.password[2].result
  sensitive = true
}

output "password_db" {
  value = random_password.password_db.result
  sensitive = true
}