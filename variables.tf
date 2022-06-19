variable "resource_group_name" {
  default = "btc_resource_group_bonus"
}
variable "virtual_network" {
  default = "btc_vn_bonus"
}
variable "location" {
  default = "eastus"
}
variable "public_sub_name" {
  default = "public_sub_bonus"
}
variable "private_sub_name" {
  default = "private_sub_bonus"
}

variable "application_port" {
  default = 8080
}

variable "ssh_port" {
  default = 22
}
variable "db_port" {
  default = 5432
}
variable "http_port" {
  default = 8080
}
variable "scale_set_instances" {
  default = 3
}

variable "vm_sku" {
  default = "Standard_B1ms"
}

variable "my_ip_address" {
  default = "*"
}
variable "vnet_address_space" {
  default = "10.1.0.0/16"
}
variable "public_subnet_address_space" {
  default = "10.1.1.0/24"
}

variable "private_subnet_address_space" {
  default = "10.1.2.0/24"
}

variable "image_publisher" {
  default = "Canonical"
}

variable "image_offer" {
  default = "UbuntuServer"
}

variable "image_sku" {
  default = "18.04-LTS"
}

variable "image_version" {
  default = "18.04.202206090"
}

variable "admin_username" {
  default   = ""
  sensitive = true
}

variable "admin_password" {
  default   = ""
  sensitive = true
}
