variable "image" {
  default = "CentOS7_with_root"
}

variable "flavor" {
  default = "icb_base"
}

variable "ssh_user_name" {
  default = "root"
}

variable "external_gateway" {
   default = "Note! Network ID from gateway"
}

variable "pool" {
  default = "public"
}

variable "user_public_key" {
  default = "ssh-rsa XXXX..."
}

resource "openstack_compute_keypair_v2" "terraform2" {
  name       = "terraform2"
}

resource "openstack_compute_keypair_v2" "icpkey" {
  name       = "icpkey"
  public_key = ${var.user_public_key}
}

resource "openstack_networking_network_v2" "terraform2" {
  name           = "terraform2"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "terraform2" {
  name            = "terraform2"
  network_id      = "${openstack_networking_network_v2.terraform2.id}"
  cidr            = "10.0.0.0/24"
  ip_version      = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

resource "openstack_networking_router_v2" "terraform2" {
  name             = "terraform2"
  admin_state_up   = "true"
  external_network_id = "${var.external_gateway}"
}

resource "openstack_networking_router_interface_v2" "terraform2" {
  router_id = "${openstack_networking_router_v2.terraform2.id}"
  subnet_id = "${openstack_networking_subnet_v2.terraform2.id}"
}

resource "openstack_compute_secgroup_v2" "terraform2" {
  name        = "terraform2"
  description = "Security group for the terraform2 example instances"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 80
    to_port     = 80
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

 rule {
    from_port   = 8443
    to_port     = 8443
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_compute_floatingip_v2" "terraform2" {
  pool       = "${var.pool}"
  depends_on = ["openstack_networking_router_interface_v2.terraform2"]
}

resource "openstack_compute_instance_v2" "terraform2" {
  name            = "terraform2"
  image_name      = "${var.image}"
  flavor_name     = "${var.flavor}"
  key_pair        = "${openstack_compute_keypair_v2.terraform2.name}"
  security_groups = ["${openstack_compute_secgroup_v2.terraform2.name}"]

  network {
    uuid = "${openstack_networking_network_v2.terraform2.id}"
  }
  

}

resource "openstack_compute_floatingip_associate_v2" "terraform2" {
  floating_ip = "${openstack_compute_floatingip_v2.terraform2.address}"
  instance_id = "${openstack_compute_instance_v2.terraform2.id}"

  connection {
      host = "${openstack_compute_floatingip_v2.terraform2.address}"
      user     = "${var.ssh_user_name}"
      private_key = "${openstack_compute_keypair_v2.terraform2.private_key}"
  }
  # Prepare the node for ICP installation
  provisioner "remote-exec" {
    inline = [
	  "echo '${openstack_compute_instance_v2.terraform2.access_ip_v4} ${openstack_compute_instance_v2.terraform2.name}' >> /etc/hosts",
	  "sudo sysctl -w vm.max_map_count=262144",
	  "sudo yum install -y wget policycoreutils-python.x86_64",
	  "sudo systemctl stop firewalld",
	  "sudo systemctl disable firewalld",
	  "wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-17.09.1.ce-1.el7.centos.x86_64.rpm",
	  "echo '*** INSTALLING DOCKER ***'",
	  "sudo yum install -y docker-ce-17.09.1.ce-1.el7.centos.x86_64.rpm",
	  "sudo systemctl start docker",
	  "echo '*** PULLING ICP IMAGE ***'",
	  "sudo docker pull ibmcom/icp-inception:2.1.0.2 && sudo docker save -o /opt/icp-inception.tar ibmcom/icp-inception:2.1.0.2",
	  "echo '*** LOADING ICP TO DOCKER ***'",
	  "sudo docker load -i /opt/icp-inception.tar",
	  "sudo chmod -R 777 /opt; mkdir /opt/ibm-cloud-private-ce-2.1.0.2; cd /opt/ibm-cloud-private-ce-2.1.0.2",
	  "sudo docker run -e LICENSE=accept -v \"$(pwd)\":/data ibmcom/icp-inception:2.1.0.2 cp -r cluster /data",
	  "sudo chmod -R 777 /opt",
#    "sudo mkdir ~/.ssh",
	  "sudo ssh-keygen -b 4096 -f ~/.ssh/id_rsa -N \"\"",
	  "sudo cat ~/.ssh/id_rsa.pub | sudo tee -a ~/.ssh/authorized_keys",
	  "sudo cat ${openstack_compute_keypair_v2.icpkey.public_key} | sudo tee -a ~/.ssh/authorized_keys",
	  "sudo systemctl restart sshd",
	  "sudo cp ~/.ssh/id_rsa /opt/ibm-cloud-private-ce-2.1.0.2/cluster/ssh_key",
    ]
  }
  
  provisioner "file" {
    content = <<EOF
[master]
${openstack_compute_instance_v2.terraform2.access_ip_v4}
[worker]
${openstack_compute_instance_v2.terraform2.access_ip_v4}
[proxy]
${openstack_compute_instance_v2.terraform2.access_ip_v4}
EOF
	destination = "/opt/ibm-cloud-private-ce-2.1.0.2/cluster/hosts"
  }
 
# replace the hosts file
  # first remove the old /etc/hosts file
  provisioner "remote-exec" {
    inline = [
	"sudo rm /etc/hosts",
	"sudo chmod -R 777 /etc",
    ]
  }
    provisioner "file" {
    content = <<EOF
127.0.0.1	localhost
${openstack_compute_instance_v2.terraform2.access_ip_v4}	${openstack_compute_instance_v2.terraform2.name}
EOF
	destination = "/etc/hosts"
  }
  
  # Run ICP installation
  provisioner "remote-exec" {
    inline = [
	  "cd /opt/ibm-cloud-private-ce-2.1.0.2/cluster",
	  "Echo '*** STARTING ICP INSTALL***'",
	  "sudo docker run -e LICENSE=accept --net=host -t -v \"$(pwd)\":/installer/cluster ibmcom/icp-inception:2.1.0.2 install",
    ]
  }

}

#########################################################
# Output
#########################################################
output "Please access the IBM Cloud Private console using the following url" {
  value = "https://${openstack_compute_instance_v2.terraform2.access_ip_v4}:8443"
}

output "The private key for accessing the VM with ssh:" {
  value = "${openstack_compute_keypair_v2.terraform2.private_key}"
}