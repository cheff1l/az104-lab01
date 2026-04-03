variable "access_key" {}
variable "secret_key" {}

provider "aws" {
  region     = "eu-north-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_vpc" "vnet1" {
  cidr_block = "10.60.0.0/22"
  tags = { Name = "az104-06-vnet1" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vnet1.id
  tags = { Name = "az104-igw" }
}

resource "aws_subnet" "subnet0" {
  vpc_id            = aws_vpc.vnet1.id
  cidr_block        = "10.60.0.0/24"
  availability_zone = "eu-north-1a"
  map_public_ip_on_launch = true
  tags = { Name = "Subnet0" }
}

resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.vnet1.id
  cidr_block        = "10.60.1.0/24"
  availability_zone = "eu-north-1b"
  map_public_ip_on_launch = true
  tags = { Name = "Subnet1" }
}

resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.vnet1.id
  cidr_block        = "10.60.2.0/24"
  availability_zone = "eu-north-1a"
  map_public_ip_on_launch = true
  tags = { Name = "Subnet2" }
}

resource "aws_subnet" "subnet_appgw" {
  vpc_id            = aws_vpc.vnet1.id
  cidr_block        = "10.60.3.224/27"
  availability_zone = "eu-north-1a"
  tags = { Name = "subnet-appgw" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vnet1.id
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

resource "aws_route_table_association" "subnet2_assoc" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_instance" "vm0" {
  ami           = "ami-08eb150f611ca277f"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.subnet0.id
  tags = { Name = "az104-06-vm0" }
}

resource "aws_instance" "vm1" {
  ami           = "ami-08eb150f611ca277f"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.subnet1.id
  tags = { Name = "az104-06-vm1" }
}

resource "aws_instance" "vm2" {
  ami           = "ami-08eb150f611ca277f"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.subnet2.id
  tags = { Name = "az104-06-vm2" }
}

resource "aws_lb" "az104_lb" {
  name               = "az104-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.subnet0.id, aws_subnet.subnet1.id]
  tags = { Name = "az104-lb" }
}

resource "aws_lb_target_group" "az104_be" {
  name     = "az104-be"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.vnet1.id

  health_check {
    protocol            = "TCP"
    port                = 80
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "vm0_attach" {
  target_group_arn = aws_lb_target_group.az104_be.arn
  target_id        = aws_instance.vm0.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "vm1_attach" {
  target_group_arn = aws_lb_target_group.az104_be.arn
  target_id        = aws_instance.vm1.id
  port             = 80
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.az104_lb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.az104_be.arn
  }
}

resource "aws_lb" "az104_appgw" {
  name               = "az104-appgw"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  tags = { Name = "az104-appgw" }
}

resource "aws_lb_target_group" "appgw_be" {
  name     = "az104-appgwbe"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vnet1.id
}

resource "aws_lb_target_group" "imagebe" {
  name     = "az104-imagebe"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vnet1.id
}

resource "aws_lb_target_group" "videobe" {
  name     = "az104-videobe"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vnet1.id
}

resource "aws_lb_target_group_attachment" "appgw_vm1" {
  target_group_arn = aws_lb_target_group.appgw_be.arn
  target_id        = aws_instance.vm1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "appgw_vm2" {
  target_group_arn = aws_lb_target_group.appgw_be.arn
  target_id        = aws_instance.vm2.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "image_vm1" {
  target_group_arn = aws_lb_target_group.imagebe.arn
  target_id        = aws_instance.vm1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "video_vm2" {
  target_group_arn = aws_lb_target_group.videobe.arn
  target_id        = aws_instance.vm2.id
  port             = 80
}

resource "aws_lb_listener" "appgw_listener" {
  load_balancer_arn = aws_lb.az104_appgw.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.appgw_be.arn
  }
}

resource "aws_lb_listener_rule" "image_rule" {
  listener_arn = aws_lb_listener.appgw_listener.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.imagebe.arn
  }

  condition {
    path_pattern {
      values = ["/image/*"]
    }
  }
}

resource "aws_lb_listener_rule" "video_rule" {
  listener_arn = aws_lb_listener.appgw_listener.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.videobe.arn
  }

  condition {
    path_pattern {
      values = ["/video/*"]
    }
  }
}