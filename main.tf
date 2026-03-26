variable "access_key" {}
variable "secret_key" {}

provider "aws" {
  region     = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_iam_group" "helpdesk" {
  name = "HelpDesk"
}

resource "aws_iam_policy" "vm_contributor" {
  name = "VMContributor"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "cloudwatch:*",
          "autoscaling:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "custom_support_request" {
  name = "CustomSupportRequest"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "support:CreateCase",
          "support:DescribeCases",
          "support:DescribeServices",
          "support:DescribeSeverityLevels",
          "support:AddCommunicationToCase"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_group_policy_attachment" "helpdesk_vm" {
  group      = aws_iam_group.helpdesk.name
  policy_arn = aws_iam_policy.vm_contributor.arn
}

resource "aws_iam_group_policy_attachment" "helpdesk_support" {
  group      = aws_iam_group.helpdesk.name
  policy_arn = aws_iam_policy.custom_support_request.arn
}