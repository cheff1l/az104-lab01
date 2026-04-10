variable "access_key" {}
variable "secret_key" {}

provider "aws" {
  region     = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_elastic_beanstalk_application" "az104_app" {
  name        = "az104-webapp"
  description = "Az104 Web Application"
}

resource "aws_elastic_beanstalk_environment" "production" {
  name                = "az104-production"
  application         = aws_elastic_beanstalk_application.az104_app.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.4.0 running PHP 8.3"

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "1"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "2"
  }

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "MeasureName"
    value     = "CPUUtilization"
  }

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "Unit"
    value     = "Percent"
  }

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "UpperThreshold"
    value     = "70"
  }

  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "LowerThreshold"
    value     = "30"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }

  tags = { Name = "az104-production" }
}

resource "aws_elastic_beanstalk_environment" "staging" {
  name                = "az104-staging"
  application         = aws_elastic_beanstalk_application.az104_app.name
  solution_stack_name = "64bit Amazon Linux 2 v3.9.0 running PHP 8.1"

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "SingleInstance"
  }

  tags = { Name = "az104-staging" }
}