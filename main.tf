variable "access_key" {}
variable "secret_key" {}

provider "aws" {
  region     = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

# ====== TASK 1: EC2 інстанс ======

resource "aws_vpc" "az104_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "az104-rg-region1-vpc" }
}

resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.az104_vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "eu-north-1a"
  tags = { Name = "az104-subnet1" }
}

resource "aws_instance" "vm0" {
  ami           = "ami-08eb150f611ca277f"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.subnet1.id
  tags = { Name = "az104-10-vm0" }
}

# ====== TASK 2: Recovery Services vault (AWS Backup Vault) ======

resource "aws_backup_vault" "region1" {
  name = "az104-rsv-region1"
  tags = { Name = "az104-rsv-region1" }
}

resource "aws_backup_vault" "region2" {
  provider = aws.region2
  name     = "az104-rsv-region2"
  tags = { Name = "az104-rsv-region2" }
}

# ====== TASK 3: Backup Policy ======

resource "aws_backup_plan" "az104_backup" {
  name = "az104-backup"

  rule {
    rule_name         = "az104-policy"
    target_vault_name = aws_backup_vault.region1.name
    schedule          = "cron(0 0 * * ? *)"

    lifecycle {
      delete_after = 30
    }
  }

  tags = { Name = "az104-backup" }
}

resource "aws_backup_selection" "vm0_backup" {
  name         = "az104-vm0-backup"
  plan_id      = aws_backup_plan.az104_backup.id
  iam_role_arn = aws_iam_role.backup_role.arn

  resources = [
    aws_instance.vm0.arn
  ]
}

resource "aws_iam_role" "backup_role" {
  name = "az104-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# ====== TASK 4: Monitoring (CloudWatch) ======

resource "aws_cloudwatch_metric_alarm" "backup_failed" {
  alarm_name          = "az104-backup-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "NumberOfBackupJobsFailed"
  namespace           = "AWS/Backup"
  period              = 86400
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when backup job fails"

  dimensions = {
    BackupVaultName = aws_backup_vault.region1.name
  }
}

# ====== TASK 5: Replication (S3 cross-region) ======

provider "aws" {
  alias      = "region2"
  region     = "eu-west-1"
  access_key = var.access_key
  secret_key = var.secret_key
}