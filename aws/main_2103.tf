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

variable "aws_region" {
  description = "AWS region to launch servers"
  default     = "us-east-1"
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
  default     = "icp"
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
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDO1DMOCqd6JQ57UUBWQH4gfZ30MV4TYaaM5jJnahFouSPhvIq2WpAUj9eLEfkpiBI1Iz6VnIe1JJpUr433pUZjHdW16nshbnknZ1JD9Zvq5sYQUBhE+29JKE/q4GA7DUzUPZlZ8QFbTNGBRRd7X/n0HSJgB/BmGNSOq0ZSjsuE3dMgC0Wfz0Y74HhabJwDl6MKlAN3YFexNLRtixIHm3hfh/1y48HZ342lqEbViFVDGhM5y24pR2nvyVnfGurqOVtX5+2Y2vlMSvDpCb14wGc8ygSKAIGW70R8dNbY4L5CeNiZhrwF9WbECXeiQurILtXeU5+tr4OMLcIuZPuLPNNTyc/FVSGkPocFdBVfZ1/ChiXEUoRy9yZy3SnGPcVbWIk2BQHsvpDwrVzdZfklF8n9Ii223G+I2Ogh8aHtClxFlZMVFqNGK5Igi6luZFnjepxKbfmzgnPh4DNkXgLnekVWqQ+Ig4Dnq4XiYZMetrquBIp/kj6r2srspTzkRkTmBeS7rhbLOlbV32U4J+qiygOgKZsdru2GC1fRC0UZYMsPY5JmG7Xq+qKixYgMWVTtf0dqe0p8qVOLZ7BbPI6Q+NHX0tzB7Wj3PwgSZspbLlQXpq9o2G0AZxn/4Ml14F0T4eZfYh/T+AT4CKHjiDs3TNfWAp/zjPIlbISMdL7mBXEppQ=="
}

#########################################################
# Build network
#########################################################
resource "aws_vpc" "default" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags {
    Name = "${var.network_name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"

  tags {
    Name = "${var.network_name_prefix}-gateway"
  }
}

resource "aws_subnet" "primary" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}b"

  tags {
    Name = "${var.network_name_prefix}-subnet"
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
# Create a server for icp
##############################################################
resource "aws_instance" "icp_server" {
  depends_on                  = ["aws_route_table_association.primary"]
  instance_type               = "t2.xlarge"
  ami                         = "${data.aws_ami.aws_ami.id}"
  subnet_id                   = "${aws_subnet.primary.id}"
  vpc_security_group_ids      = ["${aws_security_group.application.id}"]
  key_name                    = "${aws_key_pair.temp_public_key.id}"
  associate_public_ip_address = true
  root_block_device {
        volume_size = 150
    }

  tags {
    Name = "${var.icp_instance_name}"
  }

  # Specify the ssh connection
  connection {
    user        = "ubuntu"
    private_key = "${tls_private_key.ssh.private_key_pem}"
    host        = "${self.public_ip}"
  }
## Do the ICP install work here

  provisioner "remote-exec" {
    inline = [
	  "sudo sysctl -w vm.max_map_count=262144",
      "sudo apt-get install libltdl7",
      "sudo apt-get install python2.7 -y",
	  "sudo apt install python-minimal -y",
      "wget https://download.docker.com/linux/ubuntu/dists/xenial/pool/stable/amd64/docker-ce_17.12.1~ce-0~ubuntu_amd64.deb",
      "sudo dpkg -i docker-ce_17.12.1~ce-0~ubuntu_amd64.deb",
	  "sudo systemctl start docker",
	  "sudo snap install kubectl --classic",
	  "sudo docker pull ibmcom/icp-inception:2.1.0.3",
	  "sudo mkdir /opt/ibm-cloud-private-ce-2.1.0.3; cd /opt/ibm-cloud-private-ce-2.1.0.3",
	  "sudo docker run -e LICENSE=accept -v \"$(pwd)\":/data ibmcom/icp-inception:2.1.0.3 cp -r cluster /data",
      "ssh-keygen -b 4096 -f ~/.ssh/id_rsa -N \"\"",
	  "echo '***Keygen ok***'",
      "cat ~/.ssh/id_rsa.pub",
      "cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys",
	  "sudo cp /home/ubuntu/.ssh/id_rsa /root/.ssh/",
	  "sudo cp ~/.ssh/id_rsa /opt/ibm-cloud-private-ce-2.1.0.3/cluster/ssh_key",
	  "sudo chmod +r+w /opt/ibm-cloud-private-ce-2.1.0.3/cluster/ssh_key",
	  "echo '***Key copy to ubuntu ok***'",
      "echo ${var.public_key}",
      "echo ${var.public_key} >> ~/.ssh/authorized_keys",
	  "echo '*** script part 1 done ***'",
    ]
  }
  
  provisioner "file" {
    content = <<EOF
[master]
${aws_instance.icp_server.private_ip}

[worker]
${aws_instance.icp_server.private_ip}

[proxy]
${aws_instance.icp_server.private_ip}

[va]
${aws_instance.icp_server.private_ip}
EOF
	destination = "/tmp/icphosts"
  }
 
  provisioner "file" {
    content = <<EOF
127.0.0.1	localhost
${aws_instance.icp_server.public_ip}	${var.icp_instance_name}
EOF
	destination = "/tmp/etchosts"
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
cluster_lb_address: ${aws_instance.icp_server.public_ip}
proxy_lb_address: ${aws_instance.icp_server.public_ip}
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
  
  # Run ICP installation
  provisioner "remote-exec" {
    inline = [
	"echo '*** script part 2 starting ***'",
	"cd /opt/ibm-cloud-private-ce-2.1.0.3/cluster",
    "sudo cp /tmp/icphosts ./hosts",
	"sudo cp /tmp/config.yaml .",
    "sudo cp /tmp/etchosts /etc/hosts",
	"echo '*** ICP install starting ***'",
	"sudo  cp /home/ubuntu/.ssh/authorized_keys /root/.ssh/authorized_keys",
    "sudo docker run -e LICENSE=accept --net=host -t -v \"$(pwd)\":/installer/cluster ibmcom/icp-inception:2.1.0.3 install",
    ]
  }
 
}

#########################################################
# Output
#########################################################
output "AWS ICP address" {
  value = "https://${aws_instance.icp_server.public_ip}:8443"
}
