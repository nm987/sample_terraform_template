resource "aws_db_instance" "default" {
  allocated_storage      = 20
  db_name                = var.database_name
  db_subnet_group_name   = module.vpc.database_subnet_group
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  username               = data.vault_generic_secret.aws_db.data["username"]
  password               = data.vault_generic_secret.aws_db.data["password"]
  skip_final_snapshot    = true
  vpc_security_group_ids = [resource.aws_security_group.sg_database_server.id]
  tags = {
    "Name"        = var.database_name
    "Environment" = "dev"
  }
}


resource "aws_key_pair" "ssh_key_pair" {
  key_name   = "tf_key_pair"
  public_key = data.vault_generic_secret.aws_ssh_key.data["public_key"]
}


resource "aws_launch_configuration" "web_server_lc" {
  name_prefix                 = "web-server-"
  image_id                    = data.aws_ami.web_server.id
  instance_type               = var.instance_type
  security_groups             = [resource.aws_security_group.sg_web_server.id]
  associate_public_ip_address = true
  key_name                    = resource.aws_key_pair.ssh_key_pair.key_name
  user_data                   = <<EOF
  #!/bin/bash
  echo '<h1>It works!</h1>Hello from the instance '`curl http://169.254.169.254/latest/meta-data/instance-id` > /var/www/html/index.html
  EOF

  root_block_device {
    volume_type = "gp2"
    volume_size = 20
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_autoscaling_group" "web_server_asg" {
  name                      = "web-server-asg"
  launch_configuration      = resource.aws_launch_configuration.web_server_lc.name
  min_size                  = 2
  max_size                  = 4
  desired_capacity          = 3
  health_check_grace_period = 300
  health_check_type         = "ELB"
  target_group_arns         = [resource.aws_lb_target_group.lb_target_group.arn]
  vpc_zone_identifier       = [for subnet in module.vpc.public_subnets : subnet]

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "web-server-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "Group"
    value               = "web-servers"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "dev"
    propagate_at_launch = true
  }
}


resource "random_id" "random_name" {
  byte_length = 8
}


resource "aws_s3_bucket" "alb_access_logs" {
  bucket = "alb-access-log-2002-${random_id.random_name.hex}"

  tags = {
    "Name"        = "ALB access logs"
    "Environment" = "dev"
  }
}


data "aws_elb_service_account" "main" {

}


resource "aws_s3_bucket_acl" "elb_logs_acl" {
  bucket = resource.aws_s3_bucket.alb_access_logs.id
  acl    = "private"
}


resource "aws_s3_bucket_policy" "allow_elb_logging" {
  bucket = resource.aws_s3_bucket.alb_access_logs.id
  policy = <<POLICY
{
  "Id": "Policy",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${resource.aws_s3_bucket.alb_access_logs.bucket}/AWSLogs/*",
      "Principal": {
        "AWS": [
          "${data.aws_elb_service_account.main.arn}"
        ]
      }
    }
  ]
}
POLICY
}


resource "aws_lb_target_group" "lb_target_group" {
  name     = "lb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path = "/index.html"
    port = 80
  }
}


resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = resource.aws_lb.web_server_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = resource.aws_lb_target_group.lb_target_group.arn
    type             = "forward"
  }
}


resource "aws_lb" "web_server_alb" {
  name               = "web-server-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [resource.aws_security_group.sg_alb.id]
  subnets            = [for subnet in module.vpc.public_subnets : subnet]

  access_logs {
    bucket  = resource.aws_s3_bucket.alb_access_logs.bucket
    enabled = true
  }

  tags = {
    "Environment" = "dev"
  }
}