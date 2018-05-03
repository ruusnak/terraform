#################################################################
# Terraform template that will deploy an VM :
#    * Docker
#    * IBM Cloud Private CE
#
# Version: 1.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Licensed Materials - Property of IBM
#
# ©Copyright IBM Corp. 2017.
#
#################################################################

#########################################################
# Define the ibmcloud provider
#########################################################
provider "ibm" {
  bluemix_api_key = "${var.bxapikey}"
  softlayer_username = "${var.slusername}"
  softlayer_api_key = "${var.slapikey}"
}

#########################################################
# Define the variables
#########################################################
variable bxapikey {
  description = "Your Bluemix API Key."
  default = "valuenotneeded"
}

variable slusername {
  description = "Your Softlayer username."
  default = "value"
}

variable slapikey {
  description = "Your Softlayer API Key."
  default = "value"
}

variable "datacenter" {
  description = "Softlayer datacenter where infrastructure resources will be deployed"
  default="fra02"
}

variable "hostname" {
  description = "Hostname of the virtual instance to be deployed"
  default="icphost"
}

variable "public_ssh_key" {
  description = "Public SSH key used to connect to the virtual guest"
  default="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7P8Yw0vVZpUwD94mLbAhgjhGRTwwgBW1wLILfik8BiaL7psThwnelR9YcPO2FOs+u2x6SzLKe2VWVrhU/ZREmX9t5qgtB0xHP2n4gqGbDv7PU7vILSYxzQdmlHmrF0YfTTHOq0/IlogDcoAFN4jysZs26DwcCrzDcifcvjkGs29vZZcpkJBZeRzufqP4+MiP0u7BckXGL3dbyRyoaWEy2hgk+n9cqDoE57WMKUkA357q945N6/HFeLvd6J2YQzI+64riBIg3I03xTbFZJ/T0VXNCk530CBalW453hP9sXdtBktuu1MHawtmt8VldqMVSp7ZXsz25KNjgZtAfC7oUV"
}

##############################################################
# Create public key in Devices>Manage>SSH Keys in SL console
##############################################################
resource "ibm_compute_ssh_key" "cam_public_key" {
  label      = "CAM Public Key"
  public_key = "${var.public_ssh_key}"
}

##############################################################
# Create temp public key for ssh connection
##############################################################
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
}

resource "ibm_compute_ssh_key" "temp_public_key" {
  label      = "Temp Public Key"
  public_key = "${tls_private_key.ssh.public_key_openssh}"
}

##############################################################################
# Define the module to create a server and install strongloop-single-stack
##############################################################################
resource "ibm_compute_vm_instance" "softlayer_virtual_guest" {
  hostname                 = "${var.hostname}"
  os_reference_code        = "CENTOS_7_64"
  domain                   = "cam.ibm.com"
  datacenter               = "${var.datacenter}"
  network_speed            = 10
  hourly_billing           = true
  private_network_only     = false
  cores                    = 4
  memory                   = 16384
  disks                    = [100]
  dedicated_acct_host_only = false
  local_disk               = false
  ssh_key_ids              = ["${ibm_compute_ssh_key.cam_public_key.id}", "${ibm_compute_ssh_key.temp_public_key.id}"]

  # Specify the ssh connection
  connection {
    user        = "root"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host        = "${self.ipv4_address}"
  }


  # Prepare the node for ICP installation
  provisioner "remote-exec" {
    inline = [
## remove hosts entries... to do!!
	  "echo '${var.hostname}.cam.ibm.com' >> /etc/hosts",
	  "sudo sysctl -w vm.max_map_count=262144",
	  "wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-17.09.1.ce-1.el7.centos.x86_64.rpm",
	  "sudo yum install -y docker-ce-17.09.1.ce-1.el7.centos.x86_64.rpm",
	  "sudo systemctl start docker",
	  "sudo docker pull ibmcom/icp-inception:2.1.0.2",
	  "mkdir /opt/ibm-cloud-private-ce-2.1.0.2; cd /opt/ibm-cloud-private-ce-2.1.0.2",
	  "sudo docker run -e LICENSE=accept -v \"$(pwd)\":/data ibmcom/icp-inception:2.1.0.2 cp -r cluster /data",
	  "sudo ssh-keygen -b 4096 -f ~/.ssh/id_rsa -N \"\"",
	  "sudo cat ~/.ssh/id_rsa.pub | sudo tee -a ~/.ssh/authorized_keys",
      "sudo systemctl restart sshd",
	  "sudo cp ~/.ssh/id_rsa ./cluster/ssh_key",
    ]
  }
  
  provisioner "file" {
    content = <<EOF
[master]
${ibm_compute_vm_instance.softlayer_virtual_guest.ipv4_address}

[worker]
${ibm_compute_vm_instance.softlayer_virtual_guest.ipv4_address}

[proxy]
${ibm_compute_vm_instance.softlayer_virtual_guest.ipv4_address}
EOF
	destination = "/opt/ibm-cloud-private-ce-2.1.0.2/cluster/hosts"
  }
 
# replace the hosts file
  # first remove the old /etc/hosts file
  provisioner "remote-exec" {
    inline = [
	  "sudo rm /etc/hosts",
    ]
  }
    provisioner "file" {
    content = <<EOF
127.0.0.1	localhost
${ibm_compute_vm_instance.softlayer_virtual_guest.ipv4_address}	${var.hostname}.cam.ibm.com
EOF
	destination = "/etc/hosts"
  }
  
  # Run ICP installation
  provisioner "remote-exec" {
    inline = [
	  "cd /opt/ibm-cloud-private-ce-2.1.0.2/cluster",
	  "sudo docker run -e LICENSE=accept --net=host -t -v \"$(pwd)\":/installer/cluster ibmcom/icp-inception:2.1.0.2 install",
    ]
  }
  
}

#########################################################
# Output
#########################################################
output "Please access the IBM Cloud Private console using the following url" {
  value = "https://${ibm_compute_vm_instance.softlayer_virtual_guest.ipv4_address}:8443"
}
