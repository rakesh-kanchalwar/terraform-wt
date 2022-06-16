variable "resource_group_name" {
  default = "btc_resource_group"
}
variable "virtual_network" {
  default = "btc_vn"
}
variable "location" {
  default = "eastus"
}
variable "public_sub_name" {
  default = "public_sub"
}
variable "private_sub_name" {
  default = "private_sub"
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
variable "scale_set_instances" {
  default = 1
}

variable "admin_username" {
  default = ""
}

variable "admin_password" {
  default = ""
}

variable "vm_sku" {
  default = "Standard_B1ms"
}
