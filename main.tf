variable "access_key" {}
variable "secret_key" {}

provider "aws" {
  region     = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_vpc" "core_services_vnet" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "CoreServicesVnet" }
}

resource "aws_subnet" "core_subnet" {
  vpc_id     = aws_vpc.core_services_vnet.id
  cidr_block = "10.0.0.0/24"
  tags = { Name = "Core" }
}

resource "aws_subnet" "perimeter_subnet" {
  vpc_id     = aws_vpc.core_services_vnet.id
  cidr_block = "10.0.1.0/24"
  tags = { Name = "Perimeter" }
}

resource "aws_instance" "core_services_vm" {
  ami           = "ami-08eb150f611ca277f"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.core_subnet.id
  tags = { Name = "CoreServicesVM" }
}

resource "aws_vpc" "manufacturing_vnet" {
  cidr_block = "172.16.0.0/16"
  tags = { Name = "ManufacturingVnet" }
}

resource "aws_subnet" "manufacturing_subnet" {
  vpc_id     = aws_vpc.manufacturing_vnet.id
  cidr_block = "172.16.0.0/24"
  tags = { Name = "Manufacturing" }
}

resource "aws_instance" "manufacturing_vm" {
  ami           = "ami-08eb150f611ca277f"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.manufacturing_subnet.id
  tags = { Name = "ManufacturingVM" }
}

resource "aws_vpc_peering_connection" "core_to_manufacturing" {
  vpc_id      = aws_vpc.core_services_vnet.id
  peer_vpc_id = aws_vpc.manufacturing_vnet.id
  auto_accept = true
  tags = { Name = "CoreServicesVnet-to-ManufacturingVnet" }
}

resource "aws_route_table" "rt_core_services" {
  vpc_id = aws_vpc.core_services_vnet.id

  route {
    cidr_block                = "172.16.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.core_to_manufacturing.id
  }

  tags = { Name = "rt-CoreServices" }
}

resource "aws_route_table_association" "core_subnet_assoc" {
  subnet_id      = aws_subnet.core_subnet.id
  route_table_id = aws_route_table.rt_core_services.id
}