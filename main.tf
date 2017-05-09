# Setup Terraform to work with AWS.
provider "aws" {
  region = "us-east-1"
}

# Getting all availability zones
data "aws_availability_zones" "all" {}

# Last AMI image
data "aws_ami" "image" {
  most_recent = true
  owners = ["self"]
  filter {
    name = "tag:app"
    values = ["social_network_stalker"]
  }
}

# Our ASG for our app.
resource "aws_autoscaling_group" "stalker" {
  launch_configuration = "${aws_launch_configuration.stalker.id}" # On our app lauch config
  availability_zones = ["${data.aws_availability_zones.all.names}"] # Available everywhere

  min_size = 2
  max_size = 10

  load_balancers = ["${aws_elb.stalker.name}"] # Link it to our ELB
  health_check_type = "ELB" # The ELB will do the health check

  tag {
    key = "Name"
    value = "terraform-asg-stalker"
    propagate_at_launch = true
  }
}

# Our app launch configuration
resource "aws_launch_configuration" "stalker" {

  image_id = "${data.aws_ami.image.id}"
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.instance.id}"]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  # Create ressources before destroying it.
  lifecycle {
    create_before_destroy = true
  }
}

# Our instance security group.
resource "aws_security_group" "instance" {
  name = "terraform-stalker-instance"

  ingress {
    from_port = "${var.server_port}"
    to_port = "${var.server_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Our ELB attached to our ASG
resource "aws_elb" "stalker" {
  name = "terraform-asg-stalker"
  security_groups = ["${aws_security_group.elb.id}"] # We link it to our ELB security group
  availability_zones = ["${data.aws_availability_zones.all.names}"] # Available everywhere

  # ELB Health check rules
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:${var.server_port}/"
  }

  # Listen for web traffic and forward it to instances
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "${var.server_port}"
    instance_protocol = "http"
  }
}

# Our ELB security group. Accept web traffic, and any outgoing traffic
resource "aws_security_group" "elb" {
  name = "terraform-stalker-elb"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
