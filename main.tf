variable "access_key" {}
variable "secret_key" {}

provider "aws" {
  region     = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

# ====== TASK 1: VPC та підмережі ======

resource "aws_vpc" "az104_vpc" {
  cidr_block = "10.82.0.0/20"
  tags = { Name = "vmss-vnet" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.az104_vpc.id
  tags = { Name = "az104-igw" }
}

resource "aws_subnet" "subnet0" {
  vpc_id                  = aws_vpc.az104_vpc.id
  cidr_block              = "10.82.0.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true
  tags = { Name = "subnet0" }
}

resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.az104_vpc.id
  cidr_block              = "10.82.1.0/24"
  availability_zone       = "eu-north-1b"
  map_public_ip_on_launch = true
  tags = { Name = "subnet1" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.az104_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "subnet0_assoc" {
  subnet_id      = aws_subnet.subnet0.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "subnet1_assoc" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.public_rt.id
}

# ====== TASK 1: Security Group ======

resource "aws_security_group" "vmss_nsg" {
  name   = "vmss1-nsg"
  vpc_id = aws_vpc.az104_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "allow-http"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "vmss1-nsg" }
}

# ====== TASK 1: EC2 інстанси в різних зонах ======

resource "aws_instance" "vm1" {
  ami               = "ami-08eb150f611ca277f"
  instance_type     = "t3.micro"
  subnet_id         = aws_subnet.subnet0.id
  availability_zone = "eu-north-1a"
  vpc_security_group_ids = [aws_security_group.vmss_nsg.id]

  tags = { Name = "az104-vm1" }
}

resource "aws_instance" "vm2" {
  ami               = "ami-08eb150f611ca277f"
  instance_type     = "t3.micro"
  subnet_id         = aws_subnet.subnet1.id
  availability_zone = "eu-north-1b"
  vpc_security_group_ids = [aws_security_group.vmss_nsg.id]

  tags = { Name = "az104-vm2" }
}

# ====== TASK 2: EBS диск ======

resource "aws_ebs_volume" "vm1_disk1" {
  availability_zone = "eu-north-1a"
  size              = 32
  type              = "standard"
  tags = { Name = "vm1-disk1" }
}

resource "aws_volume_attachment" "vm1_disk1_attach" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.vm1_disk1.id
  instance_id = aws_instance.vm1.id
}

# ====== TASK 3: Load Balancer ======

resource "aws_lb" "vmss_lb" {
  name               = "vmss-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.vmss_nsg.id]
  subnets            = [aws_subnet.subnet0.id, aws_subnet.subnet1.id]
  tags = { Name = "vmss-lb" }
}

resource "aws_lb_target_group" "vmss_tg" {
  name     = "vmss-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.az104_vpc.id
}

resource "aws_lb_listener" "vmss_listener" {
  load_balancer_arn = aws_lb.vmss_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vmss_tg.arn
  }
}

# ====== TASK 3: Auto Scaling Group (аналог VMSS) ======

resource "aws_launch_template" "vmss1" {
  name          = "vmss1-template"
  image_id      = "ami-08eb150f611ca277f"
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.vmss_nsg.id]
  }

  tags = { Name = "vmss1" }
}

resource "aws_autoscaling_group" "vmss1" {
  name                = "vmss1"
  min_size            = 2
  max_size            = 10
  desired_capacity    = 2
  vpc_zone_identifier = [aws_subnet.subnet0.id, aws_subnet.subnet1.id]

  launch_template {
    id      = aws_launch_template.vmss1.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.vmss_tg.arn]

  tag {
    key                 = "Name"
    value               = "vmss1-instance"
    propagate_at_launch = true
  }
}

# ====== TASK 4: Auto Scaling Policy (scale out) ======

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out"
  autoscaling_group_name = aws_autoscaling_group.vmss1.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "PercentChangeInCapacity"
  scaling_adjustment     = 50
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.vmss1.name
  }
}

# ====== TASK 4: Auto Scaling Policy (scale in) ======

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "scale-in"
  autoscaling_group_name = aws_autoscaling_group.vmss1.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "PercentChangeInCapacity"
  scaling_adjustment     = -20
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 30
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.vmss1.name
  }
}