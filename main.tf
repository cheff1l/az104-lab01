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
  tags = { Name = "az104-rg11-vpc" }
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
  tags = { Name = "az104-11-vm0" }
}

# ====== TASK 2: CloudWatch Alert (аналог Azure Monitor Alert) ======

resource "aws_cloudwatch_metric_alarm" "vm_terminated" {
  alarm_name          = "VM-was-deleted"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when EC2 instance is terminated"

  dimensions = {
    InstanceId = aws_instance.vm0.id
  }

  alarm_actions = [aws_sns_topic.alert_ops_team.arn]
  tags = { Name = "VM-was-deleted" }
}

# ====== TASK 3: SNS Topic + Email (аналог Action Group) ======

resource "aws_sns_topic" "alert_ops_team" {
  name = "AlertOpsTeam"
  tags = { Name = "AlertOpsTeam" }
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.alert_ops_team.arn
  protocol  = "email"
  endpoint  = "denissemkovich1337@gmail.com"
}

# ====== TASK 4: EventBridge Rule (аналог Activity Log Alert) ======

resource "aws_cloudwatch_event_rule" "ec2_terminated" {
  name        = "EC2-Instance-Terminated"
  description = "Trigger when EC2 instance is terminated"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
    detail = {
      state = ["terminated"]
    }
  })

  tags = { Name = "EC2-Instance-Terminated" }
}

resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.ec2_terminated.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.alert_ops_team.arn
}

# ====== TASK 5: Alert Processing Rule (аналог Maintenance Window) ======

resource "aws_cloudwatch_metric_alarm" "planned_maintenance" {
  alarm_name          = "Planned-Maintenance"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 3600
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Suppress notifications during planned maintenance"

  actions_enabled = false

  dimensions = {
    InstanceId = aws_instance.vm0.id
  }

  tags = { Name = "Planned-Maintenance" }
}

# ====== TASK 6: CloudWatch Log Group (аналог Log Analytics) ======

resource "aws_cloudwatch_log_group" "az104_logs" {
  name              = "/az104/vm-insights"
  retention_in_days = 30
  tags = { Name = "az104-log-analytics" }
}

resource "aws_cloudwatch_log_metric_filter" "cpu_utilization" {
  name           = "CPUUtilization"
  pattern        = "[timestamp, requestid, event]"
  log_group_name = aws_cloudwatch_log_group.az104_logs.name

  metric_transformation {
    name      = "CPUUtilization"
    namespace = "Az104/VMInsights"
    value     = "1"
  }
}
provider "aws" {
  alias      = "region2"
  region     = "eu-west-1"
  access_key = var.access_key
  secret_key = var.secret_key
}