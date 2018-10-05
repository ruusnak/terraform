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

variable "public_ssh_key" {
  description = "Public SSH key used to connect to the virtual guest"
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7P8Yw0vVZpUwD94mLbAhgjhGRTwwgBW1wLILfik8BiaL7psThwnelR9YcPO2FOs+u2x6SzLKe2VWVrhU/ZREmX9t5qgtB0xHP2n4gqGbDv7PU7vILSYxzQdmlHmrF0YfTTHOq0/IlogDcoAFN4jysZs26DwcCrzDcifcvjkGs29vZZcpkJBZeRzufqP4+MiP0u7BckXGL3dbyRyoaWEy2hgk+n9cqDoE57WMKUkA357q945N6/HFeLvd6J2YQzI+64riBIg3I03xTbFZJ/T0VXNCk530CBalW453hP9sXdtBktuu1MHawtmt8VldqMVSp7ZXsz25KNjgZtAfC7oUV"  }

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
  cores                    = 8
  memory                   = 32768
  disks                    = [100,200]
  dedicated_acct_host_only = false
  local_disk               = false
  public_security_group_ids  = ["${data.ibm_security_group.allow_outbound.id}","${data.ibm_security_group.allow_https.id}","${data.ibm_security_group.allow_ssh.id}"]
  private_security_group_ids = ["${data.ibm_security_group.allow_all.id}","${data.ibm_security_group.allow_outbound.id}"]
  ssh_key_ids              = ["${ibm_compute_ssh_key.cam_public_key.id}", "${ibm_compute_ssh_key.temp_public_key.id}"]


  # Specify the ssh connection
  connection {
    user        = "root"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host        = "${self.ipv4_address}"
  }

## Create a template for new hosts file
  provisioner "file" {
    content = <<EOF
127.0.0.1	localhost
${ibm_compute_vm_instance.softlayer_virtual_guest.ipv4_address}	${var.hostname}.cam.ibm.com
EOF
	destination = "/tmp/hostsnew"
  }
## create a hosts file for ICP installation directory
  provisioner "file" {
    content = <<EOF
[master]
${ibm_compute_vm_instance.softlayer_virtual_guest.ipv4_address}

[worker]
${ibm_compute_vm_instance.softlayer_virtual_guest.ipv4_address}

[proxy]
${ibm_compute_vm_instance.softlayer_virtual_guest.ipv4_address}
EOF
	destination = "/tmp/icphosts"
  }
  
    provisioner "file" {
    content = <<EOF
# Licensed Materials - Property of IBM
# IBM Cloud private
# @ Copyright IBM Corp. 2017 All Rights Reserved
# US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.

---
network_type: calico
network_cidr: 10.1.0.0/16
service_cluster_ip_range: 10.0.0.1/24
etcd_extra_args: ["--grpc-keepalive-timeout=0", "--grpc-keepalive-interval=0", "--snapshot-count=10000"]
default_admin_user: admin
default_admin_password: admin
isolated_namespaces: []
isolated_proxies: []
vip_manager: etcd
management_services:
  istio: disabled
  vulnerability-advisor: disabled
  storage-glusterfs: disabled
  storage-minio: disabled
  metering: disabled
  monitoring: disabled

image-security-enforcement:
  clusterImagePolicy:
    - name: "docker.io/ibmcom/*"
      policy:

EOF
	destination = "/tmp/config.yaml"
  }
  
  # Prepare the node for ICP installation
  provisioner "remote-exec" {
    inline = [
      "systemctl stop firewalld",
      "systemctl disable firewalld",
	  "yum install -y wget yum-utils",
##	  "sudo sysctl -w vm.max_map_count=262144",
	  "wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-17.12.1.ce-1.el7.centos.x86_64.rpm",
      "echo '***Install Docker***'",
	  "yum install -y docker-ce-17.12.1.ce-1.el7.centos.x86_64.rpm",
	  "systemctl start docker",
      "echo '*** Pulling ICP install media ***'",
##      "sudo docker pull ibmcom/icp-inception:3.1.0 && sudo docker save -o /opt/icp-inception.tar ibmcom/icp-inception:3.1.0",
      "docker pull ibmcom/icp-inception:3.1.0 && sudo docker save -o /opt/icp-inception.tar ibmcom/icp-inception:3.1.0",
      "echo '***Load ICP images from tarball***'",
      "sudo docker load -i /opt/icp-inception.tar",
	    "mkdir /opt/ibm-cloud-private-ce-3.1.0; cd /opt/ibm-cloud-private-ce-3.1.0",
	    "docker run -e LICENSE=accept -v \"$(pwd)\":/data ibmcom/icp-inception:3.1.0 cp -r cluster /data",
	    "ssh-keygen -b 4096 -f ~/.ssh/id_rsa -N \"\"",
	    "cat ~/.ssh/id_rsa.pub | sudo tee -a ~/.ssh/authorized_keys",
      "systemctl restart sshd",
	  "cp ~/.ssh/id_rsa ./cluster/ssh_key",
      "sudo echo '*** first part done ***'",
      "rm /etc/hosts",
      "cp /tmp/hostsnew /etc/hosts",
      "cp /tmp/icphosts /opt/ibm-cloud-private-ce-3.1.0/cluster/hosts",
	  "cp /tmp/config.yaml /opt/ibm-cloud-private-ce-3.1.0/cluster/config.yaml",
## Instead of the above line, use the one below if you rather want to use the original config.yaml file with changed elements
##    "sudo sed -i 's/minio: disabled/minio: disabled\n  metering: disabled\n  monitoring: disabled/' config.yaml",
      "cd /opt/ibm-cloud-private-ce-3.1.0/cluster",
      "sudo echo '*** STARTING ICP INSTALL***'",
	  "docker run -e LICENSE=accept --net=host -t -v \"$(pwd)\":/installer/cluster ibmcom/icp-inception:3.1.0 install | sudo tee -a icpinstall.log",
	  ]
  }
  
}

#########################################################
# Output
#########################################################
output "Please access the IBM Cloud Private console using the following url" {
  value = "https://${ibm_compute_vm_instance.softlayer_virtual_guest.ipv4_address}:8443"
}
