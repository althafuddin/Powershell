#$ErrorActionPreference = "SilentlyContinue"
$sku_info = Get-Content <#path>
$items =@()
foreach($line in $sku_info){
    $itemFromFile = $line.Split("")
    $items += New-Object -TypeName PSObject -Property @{"module" = $itemFromFile[0];
        "Az" = $itemFromFile[1];
        "site" = $itemFromFile[3];
        "Azure_type" = $itemFromFile[5];         
    }
}

$disksizes = @{
}

$sgfiles = get-childitem <#Path>

Foreach ($item in $sgfiles){

$fname = $item.Directory.Name

$executefile = ".\json2hcl_v0.0.6_windows_amd64.exe -reverse < $item"

$file = cmd /c $executefile
$json = $file | ConvertFrom-Json

$sg = $json.resource | Select-Object -Property aws_security_group_rule
$securitygroups = @()
$sgtemplate = @()

for ($i = 0; $i -lt $sg.Count; $i++) {
    
    $securitygroups = $sg[$i].aws_security_group_rule | Get-Member -MemberType NoteProperty | Select-Object name  
     
    foreach ($s in $securitygroups.name) {
        $v = $sg[$i].aws_security_group_rule[0].$s[0]
        
     
        $local = '${local.name_prefix}'
        $sgtemplate += [PSCustomObject] @{  
            name                        = "$local-$s"
            priority                    = $i * 100
            direction                   = $v.type
            access                      = "Allow"
            protocol                    = $v.protocol
            source_port_range           = $v.from_port
            destination_port_range      = $v.to_port
            source_address_prefix       = '*'
            destination_address_prefix  = '*'
            resource_group_name         = "`${data.azurerm_resource_group.rg.name}"
            network_security_group_name = "`${azurerm_network_security_group.$fname.name}"
        }
    }

}

$module = $fname.Replace('-sg', '')
$lable_module = $module + '_label'
$SSName = $fname.Replace('sg', 'SS')
$sg_info = @()

$mtmodules = <#Attributes>

$btmodules = <#Attributes>

$ftmodules = '<#Attributes>

if ($mtmodules -contains $module){$tier = 'middle_tier'
$tt = 'mt'}
elseif($btmodules -contains $module){ $tier = 'back_tier'
    $tt = 'bt'}
else{$tier = 'front_tier'
    $tt = 'ft'}

$index = $items.module.IndexOf($module)
$az = $items[$index].Az.Split('"')
$site = $items[$index].site
$machinetype = $items[$index].azure_type



foreach ($t in $sgtemplate) {
    if ($t.direction -like 'ingress') {$direction = "inbound"}
    else {$direction = "outbound"}

    #$fname  = $t.name
    $rulename = $t.name.Split("${local.name_prefix}-")[1]
    $priority = $t.priority
    $sport = $t.source_port_range
    $fport = $t.destination_port_range
    $access = $t.access
    $port = $t.protocol
    if ($port.Contains('udp')) {$port = 'udp'}
    else {$port = 'tcp'}
    if ($rulename.Contains('ingress')) {$rulename = $rulename.Replace('ingress', 'inbound')}
    if ($rulename.Contains('egress')) {$rulename = $rulename.Replace('egress', 'outbound')}
    if(-not($sport -like 0)){ $source_address_prefix = 'VirtualNetwork’}
    if($rulename -like 'inbound_any_any_self') {$source_address_prefix = 'AzureLoadBalancer’}
    

    $sg_info += "  
// $access $direction $port : $sport - $fport
resource `"azurerm_network_security_rule`" `"$rulename`" {
  name                        = `"`${local.name_prefix}-$rulename`" 
  priority                    = $priority
  direction                   = `"$direction`"
  access                      = `"$access`"
  protocol                    = `"$port`"
  source_port_range           = $sport
  destination_port_range      = $fport
  source_address_prefix       = `"$source_address_prefix`"
  destination_address_prefix  = `"*`"
  resource_group_name         = `"`${data.azurerm_resource_group.rg.name}`"
  network_security_group_name = `"`${azurerm_network_security_group.nsg.name}`" 
  }"
}

$p1=$priority+100
$p2=$priority+200
$p3=$priority+300
$p4=$priority+400

$additionalsg = @"

  // Deny All TCP
resource "azurerm_network_security_rule" "inbound_tcp_block_cidr" {
  name                        = "`${local.name_prefix}-inbound_tcp_block_cidr" 
  priority                    = $p1
  direction                   = "inbound"
  access                      = "Deny"
  protocol                    = "tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "`${data.azurerm_resource_group.rg.name}"
  network_security_group_name = "`${azurerm_network_security_group.nsg.name}" 
  }

  // Deny All UDP
resource "azurerm_network_security_rule" "inbound_udp_block_cidr" {
  name                        = "`${local.name_prefix}-inbound_udp_block_cidr" 
  priority                    = $p2
  direction                   = "inbound"
  access                      = "Deny"
  protocol                    = "udp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "`${data.azurerm_resource_group.rg.name}"
  network_security_group_name = "`${azurerm_network_security_group.nsg.name}" 
  }

  //Allow ICMP
resource "azurerm_network_security_rule" "inbound_ICMP_Allow_cidr" {
  name                        = "`${local.name_prefix}-inbound_ICMP_Allow_cidr" 
  priority                    = $p3
  direction                   = "inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "`${data.azurerm_resource_group.rg.name}"
  network_security_group_name = "`${azurerm_network_security_group.nsg.name}" 
  }

 //Block Everything
resource "azurerm_network_security_rule" "inbound_Deny_All_cidr" {
  name                        = "`${local.name_prefix}-inbound_Deny_All_cidr" 
  priority                    = $p4
  direction                   = "inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "`${data.azurerm_resource_group.rg.name}"
  network_security_group_name = "`${azurerm_network_security_group.nsg.name}" 
  }

"@

$scaleset_info = @" 
provider "azurerm" {}

locals {
  name_prefix = "`${var.project_name}-`${var.environment_name}"
}

data "azurerm_resource_group" "rg" {
  name = "`${local.name_prefix}-rg"
}

data "azurerm_image" "img" {
  name                = "`${var.packer_image_name}"
  resource_group_name = "`${data.azurerm_resource_group.rg.name}"
}

data "local_file" "ssh_public_key" {
  filename   = "~/`${local.name_prefix}.pub"
}

data "azurerm_subnet" "$tier" {
  name                 = "`${local.prefix}-$tt"
  resource_group_name  = "`${data.azurerm_resource_group.rg.name}"
  virtual_network_name = "`${data.azurerm_virtual_network.vnet.name}"
}

data "azurerm_virtual_network" "vnet" {
  name                = "`${local.name_prefix}-vnet"
  resource_group_name = "`${data.azurerm_resource_group.rg.name}"
}

module "$lable_module" {
  source    = "github.com/cloudposse/terraform-null-label.git?ref=0.3.5"
  namespace = "`${var.project_name}"
  stage     = "`${var.environment_name}"
  name      = "$module"

  tags = "`${map("Environment", "`${var.environment_name}", "Terraform", "true")}"
}

resource "azurerm_virtual_machine_scale_set" "$module" {
  name                = "`${module.$lable_module.id}-vmss"
  resource_group_name = "`${data.azurerm_resource_group.rg.name}"
  zones               = [$az]

  sku {
    name     = "`${var.$module`_sku_name}"
    tier     = "`${var.sku_tier}"
    capacity = "`${var.$module`_minimum_number_of_instances}"
  }

  network_profile {
    name    = "`${module.$lable_module.id}-network"
    primary = true

    ip_configuration {
      name                                   = "`${module.$lable_module.id}-ipconfig"
      subnet_id                              = "`${data.azurerm_subnet.$tier.id}"
    }
  }

  os_profile {
    computer_name_prefix = "`${var.$module`_role}"
    admin_username       = "`${var.admin_username}"
    admin_password       = "`${var.admin_password}"
    custom_data          = "scripts/userdata.sh"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/`${var.admin_username}/.ssh/authorized_keys"
      key_data = "`${var.ssh_public_key}"
    }
  }

  storage_profile_image_reference {
    id = "`${data.azurerm_image.img.id}"
  }

  storage_profile_os_disk {
    create_option     = "FromImage"
    os_type           = "linux"
    caching           = "ReadWrite"
    managed_disk_type = "PremiumLRS"
  }

  storage_profile_data_disk {
    lun               = 0
    create_option     = "Empty"
    caching           = "ReadWrite"
    disk_size_gb      = "`${var.$module`_volume_size}"
    managed_disk_type = "Premium_LRS"
  }

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {
    enabled     = true
    storage_uri = "`${var.storage_uri}"
  }

  extension {
    name                 = "MSILinuxExtension"
    publisher            = "Microsoft.ManagedIdentity"
    type                 = "ManagedIdentityExtensionForLinux"
    type_handler_version = "1.0"
    settings             = "{\"port\": 50342}"
  }

  tags {
    environment = "`${var.environment_name}"
    role = "`${var.$module`_role}"
    name = "`${var.environment_name}-`${var.$module`_role}-VM"
    terraform = "true"
    site = "`${var.$module`_site}"
  }
}

// Module: modules/$module-nsg
//
resource "azurerm_network_security_group" "nsg" {
  name                = "`${module.$lable_module.id}-nsg"
  location            = "`${var.location}"
  resource_group_name = "`${data.azurerm_resource_group.rg.name}"

  tags {
    environment = "`${var.environment_name}"
  }
}
"@

$disksizeval = $disksizes.$module.ToString()

$variables_info = @"
variable "project_name" {
  description = "The name of the project being executed"
  default     = "amplero"
}

variable "environment_name" {
  description = "The name of the environment being deployed"
  default     = "dev"
}

variable "location" {
  type        = "string"
  description = "The Azure Zone which you'd like to deploy your resources to"
  default     = "eastus2"
}

variable "admin_username" {
  description = "User name of admin for virtual machine"
  default     = "amplero"
}

variable "admin_password" {
  description = "password for admin_username"
}
variable "ssh_public_key" {
  description = "The value of SSH Public Key"
}

variable "sku_tier" {
  description = "SKU Tier"
  default     = "Standard"
}

variable "packer_image_name" {
  description = "The name of the packer image created in the Packer module"
}

variable "storage_uri" {
  description = "The storage URI to store boot diagnostics files"
}

##$module - Specific Vaiables ##

variable "$module`_minimum_number_of_instances" {
  description = "The minimum number of instances the ASG should maintain"
  default     = 1
}

variable "$module`_volume_size" {
  default = $disksizeval
}

variable "$module`_role" {
  default = "$module"
}

variable "$module`_site" {
  default = "$site"
}

variable "$module`_sku_name" {
  description = "SKU size of the disk configuration in azure"
  default     = "$machinetype"
}

"@

$output_info = @"
output "principal_id" {
  value = "`${lookup(azurerm_virtual_machine_scale_set.$module.identity[0], "principal_id")}"
}
"@

$main_tf = $scaleset_info + $sg_info + $additionalsg

#$variables_info | Out-File <#path> -Encoding default
#$output_info | Out-File <#path> -Encoding default
$main_tf | Out-File <#path> -Encoding default

}
