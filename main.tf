variable "access_key" {}
variable "secret_key" {}

provider "aws" {
  region     = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

# ====== TASK 1: CoreServicesVnet ======

resource "aws_vpc" "core_services_vnet" {
  cidr_block = "10.20.0.0/16"

  tags = {
    Name = "CoreServicesVnet"
  }
}

resource "aws_subnet" "shared_services_subnet" {
  vpc_id            = aws_vpc.core_services_vnet.id
  cidr_block        = "10.20.10.0/24"

  tags = {
    Name = "SharedServicesSubnet"
  }
}

resource "aws_subnet" "database_subnet" {
  vpc_id            = aws_vpc.core_services_vnet.id
  cidr_block        = "10.20.20.0/24"

  tags = {
    Name = "DatabaseSubnet"
  }
}

# ====== TASK 2: ManufacturingVnet ======

resource "aws_vpc" "manufacturing_vnet" {
  cidr_block = "10.30.0.0/16"

  tags = {
    Name = "ManufacturingVnet"
  }
}

resource "aws_subnet" "sensor_subnet1" {
  vpc_id     = aws_vpc.manufacturing_vnet.id
  cidr_block = "10.30.20.0/24"

  tags = {
    Name = "SensorSubnet1"
  }
}

resource "aws_subnet" "sensor_subnet2" {
  vpc_id     = aws_vpc.manufacturing_vnet.id
  cidr_block = "10.30.21.0/24"

  tags = {
    Name = "SensorSubnet2"
  }
}

# ====== TASK 3: ASG + NSG ======

resource "aws_security_group" "asg_web" {
  name   = "asg-web"
  vpc_id = aws_vpc.core_services_vnet.id

  tags = {
    Name = "asg-web"
  }
}

resource "aws_security_group" "nsg_secure" {
  name   = "myNSGSecure"
  vpc_id = aws_vpc.core_services_vnet.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.asg_web.id]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.asg_web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
  }

  tags = {
    Name = "myNSGSecure"
  }
}

# ====== TASK 4: DNS ======

resource "aws_route53_zone" "public_dns" {
  name = "contoso.com"

  tags = {
    Name = "contoso.com"
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.public_dns.zone_id
  name    = "www.contoso.com"
  type    = "A"
  ttl     = 1

  records = ["10.1.1.4"]
}

resource "aws_route53_zone" "private_dns" {
  name = "private.contoso.com"

  vpc {
    vpc_id = aws_vpc.manufacturing_vnet.id
  }

  tags = {
    Name = "private.contoso.com"
  }
}

resource "aws_route53_record" "sensorvm" {
  zone_id = aws_route53_zone.private_dns.zone_id
  name    = "sensorvm.private.contoso.com"
  type    = "A"
  ttl     = 1

  records = ["10.1.1.4"]
}