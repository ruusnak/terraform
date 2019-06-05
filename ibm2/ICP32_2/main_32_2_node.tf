#################################################################
# Terraform template that will deploy an VM :
#    * Docker
#    * IBM Cloud Private CE - OFFLINE version
#    * Installation as root
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
  default="fra04"
}

variable "hostname" {
  description = "Hostname of the virtual instance to be deployed"
  default="icphost"
}

##variable "public_ssh_key" {
##  description = "Public SSH key used to connect to the virtual guest"
##  default = "ssh-rsa your key here if not provided as variable"
##}
  
data "ibm_security_group" "allow_outbound" {
    name = "allow_outbound"
}

data "ibm_security_group" "allow_https" {
    name = "allow_https"
}

data "ibm_security_group" "allow_all" {
    name = "allow_all"
}

data "ibm_security_group" "allow_ssh" {
    name = "allow_ssh"
}
##############################################################
# Create public key in Devices>Manage>SSH Keys in SL console
##############################################################
##resource "ibm_compute_ssh_key" "cam_public_key" {
##  label      = "CAM Public Key"
##  public_key = "${var.public_ssh_key}"
##}

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
# Define the master node
##############################################################################
resource "ibm_compute_vm_instance" "softlayer_virtual_guest_master" {
  hostname                 = "${var.hostname}-master"
  os_reference_code        = "CENTOS_7_64"
  domain                   = "cam.ibm.com"
  datacenter               = "${var.datacenter}"
  network_speed            = 10
  hourly_billing           = true
  private_network_only     = false
  cores                    = 8
  memory                   = 32768
  disks                    = [100,200]
  dedicated_acct_host_only = false
  local_disk               = false
  #public_security_group_ids  = ["${data.ibm_security_group.allow_outbound.id}","${data.ibm_security_group.allow_https.id}","${data.ibm_security_group.allow_ssh.id}"]
  public_security_group_ids  = ["${data.ibm_security_group.allow_all.id}", "${data.ibm_security_group.allow_outbound.id}","${data.ibm_security_group.allow_https.id}","${data.ibm_security_group.allow_ssh.id}"]
  private_security_group_ids = ["${data.ibm_security_group.allow_all.id}","${data.ibm_security_group.allow_outbound.id}"]
  ssh_key_ids              = ["${ibm_compute_ssh_key.temp_public_key.id}"]
## ssh_key_ids              = ["${ibm_compute_ssh_key.cam_public_key.id}", "${ibm_compute_ssh_key.temp_public_key.id}"]


  # Specify the ssh connection
  connection {
    user        = "root"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host        = "${self.ipv4_address}"
  }

 ## copy your own keypair to boot node  
  provisioner "file" {
    source      = "id_icp"
    destination = "/tmp/id_rsa"
  }
    
  provisioner "file" {
    source      = "id_icp.pub"
    destination = "/tmp/id_rsa.pub"
  }
  
  # Prepare the node for ICP installation
  provisioner "remote-exec" {
    inline = [
      "systemctl stop firewalld",
      "systemctl disable firewalld",
	  "yum install -y wget yum-utils",
	  "wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-17.12.1.ce-1.el7.centos.x86_64.rpm",
      "echo '***Install Docker***'",
	  "yum install -y docker-ce-17.12.1.ce-1.el7.centos.x86_64.rpm",
	  "systemctl start docker",
	  "echo 'StrictHostKeyChecking no' >> /root/.ssh/config",
	  "cat /tmp/id_rsa.pub >> /root/.ssh/authorized_keys",
	  "systemctl restart sshd.service",
##      "echo '*** Pulling ICP install media ***'",
##      "docker pull ibmcom/icp-inception:3.2.0 && sudo docker save -o /opt/icp-inception.tar ibmcom/icp-inception:3.2.0",
##      "echo '***Load ICP images from tarball***'",
##      "sudo docker load -i /opt/icp-inception.tar",
	  ]
  }
  
}
##############################################################################
# Define the worker node for ICP installation
##############################################################################
resource "ibm_compute_vm_instance" "softlayer_virtual_guest_worker" {
  hostname                 = "${var.hostname}-worker"
  os_reference_code        = "CENTOS_7_64"
  domain                   = "cam.ibm.com"
  datacenter               = "${var.datacenter}"
  network_speed            = 10
  hourly_billing           = true
  private_network_only     = false
  cores                    = 16
  memory                   = 32768
  disks                    = [100,200]
  dedicated_acct_host_only = false
  local_disk               = false
  #public_security_group_ids  = ["${data.ibm_security_group.allow_outbound.id}","${data.ibm_security_group.allow_https.id}","${data.ibm_security_group.allow_ssh.id}"]
  public_security_group_ids  = ["${data.ibm_security_group.allow_all.id}", "${data.ibm_security_group.allow_outbound.id}","${data.ibm_security_group.allow_https.id}","${data.ibm_security_group.allow_ssh.id}"]
  private_security_group_ids = ["${data.ibm_security_group.allow_all.id}","${data.ibm_security_group.allow_outbound.id}"]
    ssh_key_ids              = ["${ibm_compute_ssh_key.temp_public_key.id}"]


  # Specify the ssh connection
  connection {
    user        = "root"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host        = "${self.ipv4_address}"
  }
## copy your own keypair to node  
  provisioner "file" {
    source      = "id_icp"
    destination = "/tmp/id_rsa"
  }
    
  provisioner "file" {
    source      = "id_icp.pub"
    destination = "/tmp/id_rsa.pub"
  }
  
  # Prepare the node for ICP installation
  provisioner "remote-exec" {
    inline = [
      "systemctl stop firewalld",
      "systemctl disable firewalld",
	  "yum install -y wget yum-utils",
	  "wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-17.12.1.ce-1.el7.centos.x86_64.rpm",
      "echo '***Install Docker***'",
	  "yum install -y docker-ce-17.12.1.ce-1.el7.centos.x86_64.rpm",
	  "systemctl start docker",
	  "echo 'StrictHostKeyChecking no' >> /root/.ssh/config",
	  "cat /tmp/id_rsa.pub >> /root/.ssh/authorized_keys",
	  "systemctl restart sshd.service",
##      "echo '*** Pulling ICP install media ***'",
##      "docker pull ibmcom/icp-inception:3.2.0 && sudo docker save -o /opt/icp-inception.tar ibmcom/icp-inception:3.2.0",
##      "echo '***Load ICP images from tarball***'",
##      "sudo docker load -i /opt/icp-inception.tar",
	  ]
  }
 
}

##############################################################################
# Define the boot node
##############################################################################
resource "ibm_compute_vm_instance" "softlayer_virtual_guest_boot" {
  hostname                 = "${var.hostname}-boot"
  os_reference_code        = "CENTOS_7_64"
  domain                   = "cam.ibm.com"
  datacenter               = "${var.datacenter}"
  network_speed            = 10
  hourly_billing           = true
  private_network_only     = false
  cores                    = 4
  memory                   = 8192
  disks                    = [100,200]
  dedicated_acct_host_only = false
  local_disk               = false
  #public_security_group_ids  = ["${data.ibm_security_group.allow_outbound.id}","${data.ibm_security_group.allow_https.id}","${data.ibm_security_group.allow_ssh.id}"]
  public_security_group_ids  = ["${data.ibm_security_group.allow_all.id}", "${data.ibm_security_group.allow_outbound.id}","${data.ibm_security_group.allow_https.id}","${data.ibm_security_group.allow_ssh.id}"]
  private_security_group_ids = ["${data.ibm_security_group.allow_all.id}","${data.ibm_security_group.allow_outbound.id}"]
  ssh_key_ids              = ["${ibm_compute_ssh_key.temp_public_key.id}"]


  # Specify the ssh connection
  connection {
    user        = "root"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host        = "${self.ipv4_address}"
  }
  
## copy your own keypair to boot node  
  provisioner "file" {
    source      = "id_icp"
    destination = "/tmp/id_rsa"
  }
    
  provisioner "file" {
    source      = "id_icp.pub"
    destination = "/tmp/id_rsa.pub"
  }

## Create a template for new hosts file
  provisioner "file" {
    content = <<EOF
127.0.0.1	localhost
${ibm_compute_vm_instance.softlayer_virtual_guest_master.ipv4_address}	${var.hostname}_master.cam.ibm.com
${ibm_compute_vm_instance.softlayer_virtual_guest_worker.ipv4_address}	${var.hostname}_worker.cam.ibm.com
${ibm_compute_vm_instance.softlayer_virtual_guest_boot.ipv4_address}	${var.hostname}_boot.cam.ibm.com
EOF
	destination = "/tmp/hostsnew"
  }
## create a hosts file for ICP installation directory
  provisioner "file" {
    content = <<EOF
[master]
${ibm_compute_vm_instance.softlayer_virtual_guest_master.ipv4_address}

[worker]
${ibm_compute_vm_instance.softlayer_virtual_guest_worker.ipv4_address}

[proxy]
${ibm_compute_vm_instance.softlayer_virtual_guest_master.ipv4_address}
EOF
	destination = "/tmp/icphosts"
  }
  
    provisioner "file" {
    content = <<EOF
## Customizations for config.yaml 
password_rules:
 - '(.*)'
default_admin_password: PyRK8s

image-security-enforcement:
  clusterImagePolicy:
    - name: "*"
      policy:

EOF
	destination = "/tmp/config_add.yaml"
  } 
  
  # Prepare the node for ICP installation
  provisioner "remote-exec" {
    inline = [
      "systemctl stop firewalld",
      "systemctl disable firewalld",
	  "yum install -y wget yum-utils",
	  "wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-17.12.1.ce-1.el7.centos.x86_64.rpm",
      "echo '***Install Docker***'",
	  "yum install -y docker-ce-17.12.1.ce-1.el7.centos.x86_64.rpm",
	  "systemctl start docker",
	  ## avoid ssh prompt 
	  "echo 'StrictHostKeyChecking no' >> /root/.ssh/config",
	  "systemctl restart sshd.service",
      "echo '*** Pulling ICP install media ***'",
      "docker pull ibmcom/icp-inception:3.2.0 && sudo docker save -o /opt/icp-inception.tar ibmcom/icp-inception:3.2.0",
      "echo '***Load ICP images from tarball***'",
      "sudo docker load -i /opt/icp-inception.tar",
      "mkdir /opt/ibm-cloud-private-ce-3.2.0; cd /opt/ibm-cloud-private-ce-3.2.0",
	  "docker run -e LICENSE=accept -v \"$(pwd)\":/data ibmcom/icp-inception:3.2.0 cp -r cluster /data",
	  ## copy user provided key authorized_keys for ssh access and icp installation
      "cat /tmp/id_rsa.pub >> /root/.ssh/authorized_keys",
	  "cp /tmp/id_rsa /opt/ibm-cloud-private-ce-3.2.0/cluster/ssh_key",
	  "chmod +r+w /opt/ibm-cloud-private-ce-3.2.0/cluster/ssh_key",
	  "echo '***Key copy to icp installer ok***'",
	  ## "ssh-keygen -b 2048 -f ~/.ssh/id_rsa -N \"\"",
	  ## "cat ~/.ssh/id_rsa.pub | sudo tee -a ~/.ssh/authorized_keys",
      ## "systemctl restart sshd",
	  ## "cp ~/.ssh/id_rsa ./cluster/ssh_key",
      "sudo echo '*** first part done ***'",
	  ## hosts -file to all nodes
      "rm /etc/hosts",
      "cp /tmp/hostsnew /etc/hosts",
	  "sudo cp /tmp/id_rsa ~/.ssh/id_rsa",
	  "sudo chmod 600 ~/.ssh/id_rsa",
	  "scp /tmp/hostsnew root@${ibm_compute_vm_instance.softlayer_virtual_guest_master.ipv4_address}:/etc/hosts",
	  "scp /tmp/hostsnew root@${ibm_compute_vm_instance.softlayer_virtual_guest_worker.ipv4_address}:/etc/hosts",
      "cp /tmp/icphosts /opt/ibm-cloud-private-ce-3.2.0/cluster/hosts",
	"cat /tmp/config_add.yaml >> /opt/ibm-cloud-private-ce-3.2.0/cluster/config.yaml",
## Instead of the above line, you could use sed
##      "sudo sed -i 's/minio: disabled/minio: disabled\n  metering: disabled\n  monitoring: disabled/' config.yaml",
      "cd /opt/ibm-cloud-private-ce-3.2.0/cluster",
      "sudo echo '*** STARTING ICP INSTALL***'",
	  "docker run -e LICENSE=accept --net=host -t -v \"$(pwd)\":/installer/cluster ibmcom/icp-inception:3.2.0 install | sudo tee -a icpinstall.log",
	  ]
  }
  
}

#########################################################
# Output
#########################################################
output "Please access the IBM Cloud Private console using the following url" {
  value = "https://${ibm_compute_vm_instance.softlayer_virtual_guest_master.ipv4_address}:8443"
}
