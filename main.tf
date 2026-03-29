variable "access_key" {}
variable "secret_key" {}

provider "aws" {
  region     = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_ebs_volume" "disk1" {
  availability_zone = "eu-north-1a"
  size              = 32
  type              = "standard"

  tags = {
    Name = "az104-disk1"
  }
}

resource "aws_ebs_volume" "disk2" {
  availability_zone = "eu-north-1a"
  size              = 32
  type              = "standard"

  tags = {
    Name = "az104-disk2"
  }
}

resource "aws_ebs_volume" "disk3" {
  availability_zone = "eu-north-1a"
  size              = 32
  type              = "standard"

  tags = {
    Name = "az104-disk3"
  }
}

resource "aws_ebs_volume" "disk4" {
  availability_zone = "eu-north-1a"
  size              = 32
  type              = "standard"

  tags = {
    Name = "az104-disk4"
  }
}

resource "aws_ebs_volume" "disk5" {
  availability_zone = "eu-north-1a"
  size              = 32
  type              = "gp2"

  tags = {
    Name = "az104-disk5"
  }
}