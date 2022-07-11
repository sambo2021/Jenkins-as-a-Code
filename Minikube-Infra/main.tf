#Configure the AWS Provider
provider "aws" {
  region = "us-west-2"
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  backend "s3" {
    bucket         = "jcasc-demo"
    key            = "terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "JCASC"
  }
}

#creating public ec2 instance 
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "TF_key" {
  key_name = "TF_key"
  public_key = tls_private_key.rsa.public_key_openssh
    provisioner "local-exec" { 
    #Create "TF_key.pem" to your computer!!
    command = <<-EOT
     echo '${tls_private_key.rsa.private_key_pem}' > ${path.cwd}/TF_key.pem
     chmod 400 ${path.cwd}/TF_key.pem 
     EOT
  }
}
resource "aws_instance" "publicinstance" {
  instance_type = "t2.large"
  ami = "ami-0d70546e43a941d70" #https://cloud-images.ubuntu.com/locator/ec2/ (Ubuntu)
  subnet_id = aws_subnet.public-subnet-1.id
  security_groups = [aws_security_group.publicsecuritygroup.id]
  #keypair created in the region an i downloaded the private 
  key_name = "TF_key"
  disable_api_termination = false
  ebs_optimized = false
  root_block_device {
    volume_size = "20"
  }
  tags = {

    "Name" = "Minikube-Cluster"
  }
  depends_on = [
    tls_private_key.rsa,
    aws_key_pair.TF_key,

  ]
  provisioner "remote-exec" {
    inline = [
      
      "curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl",
      "sudo chmod +x ./kubectl",
      "sudo mv ./kubectl /usr/local/bin/kubectl",
      

      "sudo apt-get update -y",
      "sudo apt-get install -y ca-certificates curl gnupg lsb-release",
      "sudo mkdir -p /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
      "echo deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update -y",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin",

      "sudo wget https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64",
      "sudo chmod +x /home/ubuntu/minikube-linux-amd64",
      "sudo cp minikube-linux-amd64 /usr/local/bin/minikube",
      "sudo minikube start --memory 7500 --cpus 2 --disk-size 15GB --apiserver-ips=${self.public_ip} --listen-address=0.0.0.0 --kubernetes-version 1.23.8 --driver=docker --force",
      
      "sudo kubectl get pods",
      "sudo usermod -aG docker ubuntu",
      "sudo apt-get update -y",
      "sudo apt-get install nginx -y",
      "sudo unlink /etc/nginx/sites-enabled/default",
      "sudo touch /etc/nginx/sites-available/reverse-proxy.conf",
      "sudo chmod 777 /etc/nginx/sites-available/reverse-proxy.conf",
      "sudo echo 'server { \n  listen 80; \n \n location  / { \n   proxy_pass http://192.168.49.2:32000/ ; \n } \n \n location ^~ /nexus/ { \n   proxy_pass http://192.168.49.2:32001/ ;  \n } \n \n location ^~ /app/ { \n   proxy_pass http://192.168.49.2:32002/ ;  \n } \n \n }' > /etc/nginx/sites-available/reverse-proxy.conf",
      "sudo ln -s /etc/nginx/sites-available/reverse-proxy.conf /etc/nginx/sites-enabled/reverse-proxy.conf",
      "sudo service nginx configtest",
      "sudo service nginx restart",

      
    ]

 
    connection {
      type        = "ssh"
      host        = self.public_ip
      user        = "ubuntu"
      private_key = file("./TF_key.pem")
    }
  }
 
}

#networking 
# Create a VPC
resource "aws_vpc" "iti_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "Minikube-Cluster"
    Env  = "devops"
  }
}
#internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.iti_vpc.id
  tags = {
    Name = "iti-getway"
  }
}
#public subnet 
resource "aws_subnet" "public-subnet-1" {
  vpc_id     = aws_vpc.iti_vpc.id
  cidr_block = "10.0.0.0/24" 
  availability_zone = "us-west-2a"  
  # to assign public ip to included instances
  map_public_ip_on_launch = true   
  tags = {
    Name = "public-subnet-1"
  }
}
#public route table
resource "aws_route_table" "public-route-table" {
  vpc_id     = aws_vpc.iti_vpc.id
 route {
     cidr_block = "0.0.0.0/0"
     gateway_id = aws_internet_gateway.gw.id
 } 
  tags = {
    Name = "public-route-table"
  }
}
#associate routing to internet gatway
resource "aws_route_table_association" "public-subnet-1-route-table-association" {
  subnet_id = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.public-route-table.id
}
#public security group
resource "aws_security_group" "publicsecuritygroup" {
  name = "PublicSecurityGroup"
  description = "PublicSecurityGroup"
  vpc_id = aws_vpc.iti_vpc.id
  #allowing only ssh from outside
  # ingress {
  #   description="ssh"
  #   cidr_blocks = ["0.0.0.0/0"]
  #   from_port = 22
  #   to_port = 22
  #   protocol = "tcp"
  # }
  #   ingress {
  #    description="http"
  #    cidr_blocks = ["0.0.0.0/0"]
  #    from_port = 80
  #    to_port = 80
  #    protocol = "tcp"
  # }
  #   ingress {
  #    description="https"
  #    cidr_blocks = ["0.0.0.0/0"]
  #    from_port = 443
  #    to_port = 443
  #    protocol = "tcp"
  # }
  #    ingress {
  #   description = "jenkins-node-port"
  #   cidr_blocks = ["0.0.0.0/0"]
  #   from_port = 31000
  #   to_port =  31000
  #   protocol = "tcp"
  # }
  #    ingress {
  #   description = "nexus-node-port"
  #   cidr_blocks = ["0.0.0.0/0"]
  #   from_port = 32000
  #   to_port =  32000
  #   protocol = "tcp"
  # }
 ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port = 0
    protocol = "-1"
  }
  #allowing going to outside
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port = 0
    protocol = "-1"
  }
  tags = {
    "Name" = "PublicSecurityGroup"
  }
}
#end of networking 
#-------------------------------------------------------












