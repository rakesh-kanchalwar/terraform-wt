# Componenets
This terraform script creates following components
- Resource Group
- Virtual Network, public subnet, private subnet(dedicated to managed postgres)
- Load Balancer - with public IP
- Scaleset VM
- Azure managed postgres database(flexible postgres database)

# Prerequisite
- Create a <env>.tfvars file, this file be used to provide runtime values for terraform execution. Here, replace <env> with environment name
- Provide following values in this file
 ```sh
    admin_username      = ""
    admin_password      = ""
    db_admin_login      = ""
    db_admin_password   = ""
    resource_group_name = ""
    virtual_network     = ""
    environment         = ""
    vm_sku              = ""
```
## Init terraform
    terraform init -backend-config="key=terraform_stage.tfstate"
## Check what gets created
    terraform plan -var-file stage.tfvars
## To provision Infrastructure
    terraform apply -auto-approve -var-file stage.tfvars
## To destroy Infrastructure
    terraform apply -auto-approve -var-file stage.tfvars


 NOTE: Ansible to configure these servers https://github.com/rakesh-kanchalwar/Bootcamp-Ansible - main branch   