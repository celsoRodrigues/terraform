provider "aws" {
  region = "eu-west-1"
  profile = "t"    
}

resource "aws_security_group" "interv" {
  name = "interv_sg"    
}

resource "aws_security_group_rule" "allow_http" {
  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  security_group_id = aws_security_group.interv.id
}

resource "aws_security_group_rule" "allow_ssh" {
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["213.205.194.202/32"]
  security_group_id = aws_security_group.interv.id
}

resource "aws_security_group_rule" "allow_egress_all" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.interv.id
}

resource "aws_key_pair" "pubkey" {
  key_name   = "bas"
  public_key = ""
}

data "aws_ami" "amazon" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-*"]
  }
}

 resource "aws_launch_configuration" "interv" {
  name_prefix = "interv_"   
  image_id = data.aws_ami.amazon.id
  instance_type = "t2.micro"
  key_name = aws_key_pair.pubkey.key_name
  iam_instance_profile = aws_iam_instance_profile.test_profile.name 
  security_groups = [aws_security_group.interv.id] 

  user_data = file("./scripts/install_nginx.sh")

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "interv_subnets" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_autoscaling_group" "interv_asg" {
  name = "interv_asg"
  max_size = 2
  min_size = 1
  desired_capacity = 1
  health_check_type = "ELB"
  vpc_zone_identifier = data.aws_subnet_ids.interv_subnets.ids
  launch_configuration = aws_launch_configuration.interv.name
  target_group_arns = [aws_lb_target_group.interv_tg.arn]
  
 initial_lifecycle_hook {
    name                 = "instancehook"
    default_result       = "CONTINUE"
    heartbeat_timeout    = 120
    lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
  }
 

  tag {
    key = "Name"
    value = "interv"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "alb_sg" {
  name = "edge_alb_sg"
}

resource "aws_security_group_rule" "alb_allow_http" {
  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["213.205.194.202/32"]
  security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "alb_allow_egress_all" {
  type = "egress"
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}


resource "aws_alb" "edge_alb1" {
  name = "edge-alb1"
  internal = false
  security_groups = [aws_security_group.alb_sg.id]
  subnets = data.aws_subnet_ids.interv_subnets.ids

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "interv_tg" {
  name = "interv-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = data.aws_vpc.default.id

  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 5

  }
}

resource "aws_lb_listener" "interv_ls" {
  load_balancer_arn = "${aws_alb.edge_alb1.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404 - page not found"
      status_code = "404"
    }    
  }
}

resource "aws_alb_listener_rule" "interv_ls_rule" {
  listener_arn = aws_lb_listener.interv_ls.arn
  priority = 100
  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.interv_tg.arn    
  }
}

output "the_ami" {
  value = data.aws_ami.amazon.id
}

output "the_sg" {
  value = aws_security_group.interv.id
}


output "alb_dns" {
  value = aws_alb.edge_alb1.dns_name
}

#permissions

resource "aws_iam_role" "role" {
  name = "test-role"

  assume_role_policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
           "Service": "ec2.amazonaws.com"
          },
          "Effect": "Allow",
          "Sid": "myrule"
        }
      ]
    }
    EOF
}

resource "aws_iam_policy" "policy" {
  name        = "test-policy"
  description = "A test policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = "${aws_iam_role.role.name}"
  policy_arn = "${aws_iam_policy.policy.arn}"
}

resource "aws_iam_instance_profile" "test_profile" {
  name = "test_profile"
  role = "${aws_iam_role.role.name}"
}
