variable "access_key" {}
variable "secret_key" {}

provider "aws" {
  region     = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "az104_storage" {
  bucket = "az104-rg7-storage-${random_id.suffix.hex}"
  tags = { Name = "az104-storage" }
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.az104_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "block_public" {
  bucket                  = aws_s3_bucket.az104_storage.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "data_folder" {
  bucket = aws_s3_bucket.az104_storage.id
  key    = "data/securitytest/"
}

resource "aws_efs_file_system" "share1" {
  tags = { Name = "share1" }
}

resource "aws_vpc" "vnet1" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "vnet1" }
}

resource "aws_subnet" "default_subnet" {
  vpc_id     = aws_vpc.vnet1.id
  cidr_block = "10.0.0.0/24"
  tags = { Name = "default" }
}

resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id       = aws_vpc.vnet1.id
  service_name = "com.amazonaws.eu-north-1.s3"
  tags = { Name = "s3-endpoint" }
}