#########################################################
# Define the AWS provider
#########################################################
provider "aws" {
  version = "~> 1.2"
  region  = "${var.aws_region}"
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
}


#########################################################
# Define the variables
#########################################################
variable aws_access_key {}
variable aws_secret_key {}

variable "aws_tag_key" {
  description = "AWS tag to use with k8s"
  default     = "kubernetes-io-cluster-6f4cddf0"
}

variable "aws_tag_value" {
  description = "AWS tag value to use with k8s"
  default     = "6f4cddf0"
}


variable "aws_region" {
  description = "AWS region to launch servers"
  default     = "eu-central-1"
}

#Variable : AWS image name
variable "aws_image" {
  type = "string"
  description = "Operating system image id / template that should be used when creating the virtual image"
  default = "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"
}

variable "aws_ami_owner_id" {
  description = "AWS AMI Owner ID"
  default = "099720109477"
}

# Lookup for AMI based on image name and owner ID
data "aws_ami" "aws_ami" {
  most_recent = true
  filter {
    name = "name"
    values = ["${var.aws_image}*"]
  }
  owners = ["${var.aws_ami_owner_id}"]
}

variable "icp_instance_name" {
  description = "The hostname of server with ICP"
  default     = "mycluster.icp"
}

variable "network_name_prefix" {
  description = "The prefix of names for VPC, Gateway, Subnet and Security Group"
  default     = "opencontent-icp"
}

variable "public_key_name" {
  description = "Name of the public SSH key used to connect to the servers"
  default     = "cam-public-key-icp"
}

variable "public_key" {
  description = "Public SSH key used to connect to the servers"
}

#########################################################
# Build network
#########################################################
resource "aws_vpc" "default" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags {
    Name = "${var.network_name_prefix}-vpc"
    "6f4cddf0" = "6f4cddf0"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"

  tags {
    Name = "${var.network_name_prefix}-gateway"
	"6f4cddf0" = "6f4cddf0"
  }
}

resource "aws_subnet" "primary" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}b"

  tags {
    Name = "${var.network_name_prefix}-subnet"
	"6f4cddf0" = "6f4cddf0"
  }
}

resource "aws_route_table" "default" {
  vpc_id = "${aws_vpc.default.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default.id}"
  }

  tags {
    Name = "${var.network_name_prefix}-route-table"
	"6f4cddf0" = "6f4cddf0"
  }
}

resource "aws_route_table_association" "primary" {
  subnet_id      = "${aws_subnet.primary.id}"
  route_table_id = "${aws_route_table.default.id}"
}

resource "aws_security_group" "application" {
  name        = "${var.network_name_prefix}-security-group-app"
  description = "Security group which applies to icp server"
  vpc_id      = "${aws_vpc.default.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  
  ingress {
    from_port   = 8001
    to_port     = 8001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    
  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
    ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 9443
    to_port     = 9443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.network_name_prefix}-security-group-application"
	"6f4cddf0" = "6f4cddf0"
  }
}

##############################################################
# Create user-specified public key in AWS
##############################################################
resource "aws_key_pair" "cam_public_key" {
  key_name   = "${var.public_key_name}"
  public_key = "${var.public_key}"
}

##############################################################
# Create temp public key for ssh connection
##############################################################
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
}

resource "aws_key_pair" "temp_public_key" {
  key_name   = "${var.public_key_name}-temp"
  public_key = "${tls_private_key.ssh.public_key_openssh}"
}


##############################################################
# Create a master node for icp 
##############################################################
resource "aws_instance" "icp_master" {
  depends_on                  = ["aws_route_table_association.primary"]
  instance_type               = "m5.2xlarge"
  ami                         = "${data.aws_ami.aws_ami.id}"
  subnet_id                   = "${aws_subnet.primary.id}"
  vpc_security_group_ids      = ["${aws_security_group.application.id}"]
  key_name                    = "${aws_key_pair.temp_public_key.id}"
  associate_public_ip_address = true
  root_block_device {
        volume_size = 250
    }

  tags {
    Name = "${var.icp_instance_name}_master"
	"6f4cddf0" = "6f4cddf0"
  }
  
  # Specify the ssh connection
  connection {
    user        = "ubuntu"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host        = "${self.public_ip}"
  }
  
  # Prepare the worker node for ICP installation
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get install libltdl7",
      "sudo apt-get install python2.7 -y",
	  "sudo apt install python-minimal -y",
      "wget https://download.docker.com/linux/ubuntu/dists/xenial/pool/stable/amd64/docker-ce_17.12.1~ce-0~ubuntu_amd64.deb",
      "sudo dpkg -i docker-ce_17.12.1~ce-0~ubuntu_amd64.deb",
	  "sudo systemctl start docker",
	  "sudo echo 'StrictHostKeyChecking no' >> /home/ubuntu/.ssh/config",
	  "sudo echo ${var.public_key} >> /home/ubuntu/.ssh/authorized_keys",
	  "sudo cp /home/ubuntu/.ssh/authorized_keys /root/.ssh/authorized_keys",
	  "sudo systemctl restart ssh",
	  ## hosts file ?
	  ]
  }
}

##############################################################
# Create a worker node for icp 
##############################################################
resource "aws_instance" "icp_worker" {
  depends_on                  = ["aws_route_table_association.primary"]
  instance_type               = "m5.2xlarge"
  ami                         = "${data.aws_ami.aws_ami.id}"
  subnet_id                   = "${aws_subnet.primary.id}"
  vpc_security_group_ids      = ["${aws_security_group.application.id}"]
  key_name                    = "${aws_key_pair.temp_public_key.id}"
  associate_public_ip_address = true
  root_block_device {
        volume_size = 250
    }

  tags {
    Name = "${var.icp_instance_name}_worker"
	"6f4cddf0" = "6f4cddf0"
  }
  
  # Specify the ssh connection
  connection {
    user        = "ubuntu"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host        = "${self.public_ip}"
  }
  
  # Prepare the worker node for ICP installation
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get install libltdl7",
      "sudo apt-get install python2.7 -y",
	  "sudo apt install python-minimal -y",
      "wget https://download.docker.com/linux/ubuntu/dists/xenial/pool/stable/amd64/docker-ce_17.12.1~ce-0~ubuntu_amd64.deb",
      "sudo dpkg -i docker-ce_17.12.1~ce-0~ubuntu_amd64.deb",
	  "sudo systemctl start docker",
	  "sudo echo 'StrictHostKeyChecking no' >> /home/ubuntu/.ssh/config",
	  "sudo echo ${var.public_key} >> /home/ubuntu/.ssh/authorized_keys",
	  "sudo cp /home/ubuntu/.ssh/authorized_keys /root/.ssh/authorized_keys",
	  "sudo systemctl restart ssh",
	  ## hosts file ?
	  ]
  }
}

##############################################################
# Create a server for icp
##############################################################
resource "aws_instance" "icp_server" {
  depends_on                  = ["aws_route_table_association.primary"]
  instance_type               = "m5.large"
  ami                         = "${data.aws_ami.aws_ami.id}"
  subnet_id                   = "${aws_subnet.primary.id}"
  vpc_security_group_ids      = ["${aws_security_group.application.id}"]
  key_name                    = "${aws_key_pair.temp_public_key.id}"
  associate_public_ip_address = true
  root_block_device {
        volume_size = 250
    }

  tags {
    Name = "${var.icp_instance_name}"
	"6f4cddf0" = "6f4cddf0"
  }

  # Specify the ssh connection
  connection {
    user        = "ubuntu"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host        = "${self.public_ip}"
  }
## Do the ICP cluster config
 
  provisioner "file" {
    content = <<EOF
[master]
${aws_instance.icp_master.private_ip}

[worker]
${aws_instance.icp_worker.private_ip}

[proxy]
${aws_instance.icp_master.private_ip}

EOF
	destination = "/tmp/icphosts"
  }
 
  provisioner "file" {
    content = <<EOF
${aws_instance.icp_server.public_ip}	${var.icp_instance_name}
${aws_instance.icp_worker.public_ip}	${var.icp_instance_name}_worker

EOF
	destination = "/tmp/etchosts"
  }
  
  provisioner "file" {
    source      = "id_icp"
    destination = "/tmp/id_rsa"
  }
    
  provisioner "file" {
    source      = "id_icp.pub"
    destination = "/tmp/id_rsa.pub"
  }
  
    provisioner "file" {
    content = <<EOF
# Licensed Materials - Property of IBM
# IBM Cloud private
# @ Copyright IBM Corp. 2017 All Rights Reserved
# US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.

---
network_type: calico
calico_tunnel_mtu: 8981
network_cidr: 10.1.0.0/16
service_cluster_ip_range: 10.0.0.1/24
etcd_extra_args: ["--grpc-keepalive-timeout=0", "--grpc-keepalive-interval=0", "--snapshot-count=10000"]
default_admin_user: admin
default_admin_password: admin
isolated_namespaces: []
isolated_proxies: []
vip_manager: etcd
cluster_lb_address: ${aws_instance.icp_master.public_dns}
proxy_lb_address: ${aws_instance.icp_master.public_dns}
#cloud_provider: aws
#kubelet_nodename: ${var.icp_instance_name}
management_services:
  istio: disabled
  vulnerability-advisor: disabled
  storage-glusterfs: disabled
  storage-minio: disabled
#  metering: disabled
#  monitoring: disabled
image-security-enforcement:
  clusterImagePolicy:
    - name: "*"
      policy:
EOF
	destination = "/tmp/config.yaml"
  }

  
  # Prepare the node for ICP installation
  provisioner "remote-exec" {
    inline = [
## insert own key
	  "sudo echo ${var.public_key} >> /home/ubuntu/.ssh/authorized_keys",
	  "sudo apt-get install libltdl7",
      "sudo apt-get install python2.7 -y",
	  "sudo apt install python-minimal -y",
      "wget https://download.docker.com/linux/ubuntu/dists/xenial/pool/stable/amd64/docker-ce_17.12.1~ce-0~ubuntu_amd64.deb",
      "sudo dpkg -i docker-ce_17.12.1~ce-0~ubuntu_amd64.deb",
	  "sudo systemctl start docker",
	  "sudo snap install kubectl --classic",
	  "sudo docker pull ibmcom/icp-inception:3.1.0",
	  "sudo mkdir /opt/ibm-cloud-private-ce-3.1.0; sudo mkdir /opt/ibm-cloud-private-ce-3.1.0/cluster; cd /opt/ibm-cloud-private-ce-3.1.0",
	  "sudo docker run -e LICENSE=accept -v \"$(pwd)\":/data ibmcom/icp-inception:3.1.0 cp -r cluster /data",
	  
## copy user provided key authorized_keys for ssh access and icp installation
      "sudo cat /tmp/id_rsa.pub >> /home/ubuntu/.ssh/authorized_keys",
	  "sudo cp /tmp/id_rsa /opt/ibm-cloud-private-ce-3.1.0/cluster/ssh_key",
	  "sudo chmod +r+w /opt/ibm-cloud-private-ce-3.1.0/cluster/ssh_key",
	  "echo '***Key copy to ubuntu ok***'",
## make the keys available for root so the icp installer can use them
	  "sudo cp /home/ubuntu/.ssh/authorized_keys /root/.ssh/authorized_keys",
## copy key to worker
	  "sudo echo 'StrictHostKeyChecking no' >> /root/.ssh/config",
	  "sudo echo 'StrictHostKeyChecking no' >> /home/ubuntu/.ssh/config",
	  "sudo cp /tmp/id_rsa ~/.ssh/id_rsa",
	  "sudo chmod 600 ~/.ssh/id_rsa",	  
	  "sudo cp ~/.ssh/id_rsa /root/.ssh/id_rsa",
	  "sudo chown ubuntu ~/.ssh/id_rsa",
	  "echo '*** keys copied ***'",
      "sudo rm /etc/hosts",
      "sudo cp /tmp/etchosts /etc/hosts",
	  "echo '*** /etc/hosts modified ***'",
## copy new /etc/hosts file to worker
	  "scp /etc/hosts ubuntu@${aws_instance.icp_worker.private_ip}:/home/ubuntu",
	  "ssh ubuntu@${aws_instance.icp_worker.private_ip} 'sudo cp hosts /etc/hosts'",
## copy modified icp config & hosts file to installation directories
      "sudo cp /tmp/icphosts /opt/ibm-cloud-private-ce-3.1.0/cluster/hosts",
	  "sudo cp /tmp/config.yaml /opt/ibm-cloud-private-ce-3.1.0/cluster/config.yaml",
## Instead of the above line, use the one below if you rather want to use the original config.yaml file with changed elements
##    "sudo sed -i 's/minio: disabled/minio: disabled\n  metering: disabled\n  monitoring: disabled/' config.yaml",
      "cd /opt/ibm-cloud-private-ce-3.1.0/cluster",
      "sudo echo '*** STARTING ICP INSTALL***'",
	  "sudo docker run -e LICENSE=accept --net=host -t -v \"$(pwd)\":/installer/cluster ibmcom/icp-inception:3.1.0 install",
	  ]
  }

 
}

#########################################################
# Output
#########################################################
output "AWS ICP address" {
  value = "https://${aws_instance.icp_master.public_dns}:8443"
}
