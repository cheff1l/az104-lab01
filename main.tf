variable "access_key" {}
variable "secret_key" {}

provider "aws" {
  region     = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_iam_user" "user1" {
  name = "az104-user1"

  tags = {
    Department = "IT"
    JobTitle   = "IT Lab Administrator"
    Location   = "United States"
  }
}

resource "aws_iam_user" "guest_user" {
  name = "az104-guest-user"

  tags = {
    Department = "IT"
    JobTitle   = "IT Lab Administrator"
    Type       = "Guest"
  }
}

resource "aws_iam_group" "it_lab_admins" {
  name = "IT-Lab-Administrators"
}

resource "aws_iam_group_membership" "lab_membership" {
  name  = "it-lab-membership"
  group = aws_iam_group.it_lab_admins.name

  users = [
    aws_iam_user.user1.name,
    aws_iam_user.guest_user.name,
  ]
}