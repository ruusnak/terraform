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
  default="fra02"
}

variable "hostname" {
  description = "Hostname of the virtual instance to be deployed"
  default="icphost"
}

variable "public_ssh_key" {
  description = "Public SSH key used to connect to the virtual guest"
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDO1DMOCqd6JQ57UUBWQH4gfZ30MV4TYaaM5jJnahFouSPhvIq2WpAUj9eLEfkpiBI1Iz6VnIe1JJpUr433pUZjHdW16nshbnknZ1JD9Zvq5sYQUBhE+29JKE/q4GA7DUzUPZlZ8QFbTNGBRRd7X/n0HSJgB/BmGNSOq0ZSjsuE3dMgC0Wfz0Y74HhabJwDl6MKlAN3YFexNLRtixIHm3hfh/1y48HZ342lqEbViFVDGhM5y24pR2nvyVnfGurqOVtX5+2Y2vlMSvDpCb14wGc8ygSKAIGW70R8dNbY4L5CeNiZhrwF9WbECXeiQurILtXeU5+tr4OMLcIuZPuLPNNTyc/FVSGkPocFdBVfZ1/ChiXEUoRy9yZy3SnGPcVbWIk2BQHsvpDwrVzdZfklF8n9Ii223G+I2Ogh8aHtClxFlZMVFqNGK5Igi6luZFnjepxKbfmzgnPh4DNkXgLnekVWqQ+Ig4Dnq4XiYZMetrquBIp/kj6r2srspTzkRkTmBeS7rhbLOlbV32U4J+qiygOgKZsdru2GC1fRC0UZYMsPY5JmG7Xq+qKixYgMWVTtf0dqe0p8qVOLZ7BbPI6Q+NHX0tzB7Wj3PwgSZspbLlQXpq9o2G0AZxn/4Ml14F0T4eZfYh/T+AT4CKHjiDs3TNfWAp/zjPIlbISMdL7mBXEppQ=="
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

[va]
${ibm_compute_vm_instance.softlayer_virtual_guest.ipv4_address}
EOF
	destination = "/tmp/icphosts"
  }
  
    provisioner "file" {
    content = <<EOF
# IBM Cloud private 
# Installation configuration

---

network_type: calico
network_cidr: 10.1.0.0/16
## Kubernetes Settings
service_cluster_ip_range: 10.0.0.1/24
kubelet_extra_args: ["--fail-swap-on=false"]
etcd_extra_args: ["--grpc-keepalive-timeout=0", "--grpc-keepalive-interval=0", "--snapshot-count=10000"]
default_admin_user: admin
default_admin_password: admin
## External loadbalancer IP or domain
## Or floating IP in OpenStack environment
cluster_lb_address: none
proxy_lb_address: none
## You can disable the following management services: ["service-catalog", "metering", "monitoring", "istio", "vulnerability-advisor", "custom-metrics-adapter"]
disabled_management_services: ["istio", "vulnerability-advisor", "custom-metrics-adapter", "metering", "monitoring"]
## Docker and logs
docker_log_max_size: 50m
docker_log_max_file: 10
metrics_max_age: 2
logs_maxage: 2
EOF
	destination = "/tmp/config.yaml"
  }
  
  # Prepare the node for ICP installation
  provisioner "remote-exec" {
    inline = [
      "sudo systemctl stop firewalld",
      "sudo systemctl disable firewalld",
	  "sudo sysctl -w vm.max_map_count=262144",
	  "wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-17.12.1.ce-1.el7.centos.x86_64.rpm",
      "echo '***Install Docker***'",
	  "sudo yum install -y docker-ce-17.12.1.ce-1.el7.centos.x86_64.rpm",
	  "sudo systemctl start docker",
      "echo '*** Pulling ICP install media ***'",
      "sudo docker pull ibmcom/icp-inception:2.1.0.3 && sudo docker save -o /opt/icp-inception.tar ibmcom/icp-inception:2.1.0.3",
      "echo '***Load ICP images from tarball***'",
      "sudo docker load -i /opt/icp-inception.tar",
	  "mkdir /opt/ibm-cloud-private-ce-2.1.0.3; cd /opt/ibm-cloud-private-ce-2.1.0.3",
	  "sudo docker run -e LICENSE=accept -v \"$(pwd)\":/data ibmcom/icp-inception:2.1.0.3 cp -r cluster /data",
	  "sudo ssh-keygen -b 4096 -f ~/.ssh/id_rsa -N \"\"",
	  "sudo cat ~/.ssh/id_rsa.pub | sudo tee -a ~/.ssh/authorized_keys",
      "sudo systemctl restart sshd",
	  "sudo cp ~/.ssh/id_rsa ./cluster/ssh_key",
      "sudo echo '*** first part done ***'",
      "sudo rm /etc/hosts",
      "sudo cp /tmp/hostsnew /etc/hosts",
      "sudo cp /tmp/icphosts /opt/ibm-cloud-private-ce-2.1.0.3/cluster/hosts",
	  "sudo cp /tmp/config.yaml /opt/ibm-cloud-private-ce-2.1.0.3/cluster/config.yaml",
      "cd /opt/ibm-cloud-private-ce-2.1.0.3/cluster",
      "sudo echo '*** STARTING ICP INSTALL***'",
	  "sudo docker run -e LICENSE=accept --net=host -t -v \"$(pwd)\":/installer/cluster ibmcom/icp-inception:2.1.0.3 install",
	  "sudo mkdir ~/.kube",
	  "sudo cp /var/lib/kubelet/kubectl-config ~/.kube/config",
    ]
  }
  
}

#########################################################
# Output
#########################################################
output "Please access the IBM Cloud Private console using the following url" {
  value = "https://${ibm_compute_vm_instance.softlayer_virtual_guest.ipv4_address}:8443"
}
