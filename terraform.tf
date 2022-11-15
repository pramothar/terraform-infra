terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
#VPC
resource "aws_vpc" "myvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "my-vpc"
  }
}
#pub-subnet
resource "aws_subnet" "public-subnet" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "My-vpc-public-subnet"
  }
}
#pvt-subnet
resource "aws_subnet" "private-subnet" {
  vpc_id     = aws_vpc.myvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "My-vpc-private-subnet"
  }
}
#internet-gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "int.gateway"
  }
}
#route table public
resource "aws_route_table" "rt-public" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}
#sub association pub
resource "aws_route_table_association" "rt-pub-assoc" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_route_table.rt-public.id
}

#route table private
resource "aws_route_table" "rt-private" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.tnat.id
  }
}
#sub association pvt
resource "aws_route_table_association" "rt-pvt-assoc" {
  subnet_id      = aws_subnet.private-subnet.id
  route_table_id = aws_route_table.rt-private.id
}
#security group
resource "aws_security_group" "pub-sg" {
  name        = "pub-sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description      = "ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    #ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
   ingress {
    description      = "http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    #ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}
#EIP
resource "aws_eip" "eip" {
  vpc      = true
}
#nat gateway
resource "aws_nat_gateway" "tnat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public-subnet.id

  tags = {
    Name = "gw NAT"
  }
}
#webserver

resource "aws_instance" "web" {
  ami           = "ami-026b57f3c383c2eec"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  vpc_security_group_ids = ["${aws_security_group.pub-sg.id}"]
  subnet_id = aws_subnet.public-subnet.id
  tags = {
    Name = "webserver"
  }
}

#DB

resource "aws_instance" "db" {
  ami           = "ami-026b57f3c383c2eec"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.pub-sg.id}"]
  subnet_id = aws_subnet.private-subnet.id
  tags = {
    Name = "database"
  }
}

