resource "azurerm_resource_group" "test-lamp" {
    name = "learn-webserver-rg"
    location = "East US"
}

resource "azurerm_storage_account" "test-lamp-sa" {
    name = "learnwebserversa"
    resource_group_name = azurerm_resource_group.test-lamp.name
    location = azurerm_resource_group.test-lamp.location
    account_tier = "Standard"
    account_replication_type = "GRS"
  
}

resource "azurerm_virtual_network" "test-lamp-network" {
    name = "learn-webserver-net"
    address_space = [ "10.0.0.0/16" ]
    location = azurerm_resource_group.test-lamp.location
    resource_group_name = azurerm_resource_group.test-lamp.name
  
}

resource "azurerm_subnet" "test-lamp-subnet" {
    name = "learn-webserver-subnet"
    resource_group_name = azurerm_resource_group.test-lamp.name
    virtual_network_name = azurerm_virtual_network.test-lamp-network.name
    address_prefixes = [ "10.0.2.0/24" ]
  
}

resource "azurerm_public_ip" "test-lamp-pubip" {
    name = "learn-webserver-public"
    resource_group_name = azurerm_resource_group.test-lamp.name
    location = azurerm_resource_group.test-lamp.location
    allocation_method = "Dynamic"
    domain_name_label = "test-lamp-webserver"

}

resource "azurerm_network_interface" "test-lamp-nic" {
    name = "learn-webserver-nic"
    resource_group_name = azurerm_resource_group.test-lamp.name
    location = azurerm_resource_group.test-lamp.location

    ip_configuration {
      name = "primary"
      subnet_id = azurerm_subnet.test-lamp-subnet.id
      private_ip_address_allocation = "Dynamic"
      public_ip_address_id = azurerm_public_ip.test-lamp-pubip.id
    }
  
}

resource "azurerm_network_interface" "test-lamp-nic-internal" {
    name = "learn-webserver-nic-internal"
    resource_group_name = azurerm_resource_group.test-lamp.name
    location = azurerm_resource_group.test-lamp.location

    ip_configuration {
      name = "internal"
      subnet_id = azurerm_subnet.test-lamp-subnet.id
      private_ip_address_allocation = "Dynamic"
    }
  
}

resource "azurerm_network_security_group" "test-lamp-sg" {
    name = "learn-webserver-sg"
    location = azurerm_resource_group.test-lamp.location
    resource_group_name = azurerm_resource_group.test-lamp.name
    security_rule {
        name = "HTTP"
        access = "Allow"
        direction = "Inbound"
        priority = 100
        protocol = "Tcp"
        source_port_range = "*"
        source_address_prefix = "*"
        destination_port_range = "80"
        destination_address_prefix = azurerm_network_interface.test-lamp-nic.private_ip_address
    }
    security_rule {
        name = "SSH"
        access = "Allow"
        direction = "Inbound"
        priority = 101
        protocol = "Tcp"
        source_port_range = "*"
        source_address_prefix = "*"
        destination_port_range = "22"
        destination_address_prefix = azurerm_network_interface.test-lamp-nic.private_ip_address

    }
  
}

resource "azurerm_network_interface_security_group_association" "test-lamp-sg-association" {
    network_interface_id = azurerm_network_interface.test-lamp-nic-internal.id
    network_security_group_id = azurerm_network_security_group.test-lamp-sg.id
  
}

resource "azurerm_virtual_machine" "test-lamp-vm" {
    name = "learn-webserver-vm"
    resource_group_name = azurerm_resource_group.test-lamp.name
    location = azurerm_resource_group.test-lamp.location
    vm_size = "Standard_F2"
    network_interface_ids = ["${azurerm_network_interface.test-lamp-nic.id}"]
    

    storage_image_reference {
      publisher = "Canonical"
      offer = "0001-com-ubuntu-server-jammy"
      sku = "22_04-lts"
      version = "latest"
    }

    storage_os_disk {
        name = "test-lamp-webserver1_osdisk"
        managed_disk_type = "Standard_LRS"
        caching = "ReadWrite"
        create_option = "FromImage"
    }

    os_profile {
      computer_name = "test-lamp-webserver"
      admin_username = var.admin_username
      admin_password = var.admin_password
    }

    os_profile_linux_config {
      disable_password_authentication = true
      ssh_keys {
        path = "/home/${var.admin_username}/.ssh/authorized_keys"
        key_data = file("~/.ssh/id_rsa.pub")
      }
    }

    provisioner "remote-exec" {
        inline = [ 
            "sudo apt-get install -y apache2 && systemctl start apache2",
            "sudo apt-get install -y php php-mysql mysql-server",
            "echo '<h1><center>My first website using terraform provisioner</center></h1>' > index.html",
            "echo '<h1><center>Gyan and Shankar created this website</center></h1>' >> index.html",
            "sudo mv index.html /var/www/html/"
         ]
        connection {
          type = "ssh"
          host = azurerm_public_ip.test-lamp-pubip.fqdn
          user = var.admin_username
          private_key = file("~/.ssh/id_rsa")
        }
    }

}