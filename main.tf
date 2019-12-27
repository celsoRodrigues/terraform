provider "aws" {
  region = "eu-west-1"
  profile = "t"    
}

resource "aws_security_group" "instance_sg" {
  name = "interview_example"
}

resource "aws_security_group_rule" "sg_rule_allow_ssh" {
  type = "ingress"
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.instance_sg.id
}

resource "aws_security_group_rule" "sg_rule_allow_http" {
  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.instance_sg.id
}

resource "aws_security_group_rule" "sg_rule_allow_egress" {
  type = "egress"
  from_port = 1024
  to_port = 65535
  protocol = -1
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.instance_sg.id
}


resource "aws_key_pair" "deployer" {
  key_name   = "bast"
  public_key = var.pkey
}

resource "aws_instance" "interview" {
  ami = "ami-028188d9b49b32a80"
  instance_type = "t2.micro"    
  key_name = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y && yum install nginx -y
              sudo service nginx start
              chkconfig nginx on
              EOF
}

output "instance_public_ip" {
  value = aws_instance.interview.public_ip
}

output "instance_private_ip" {
  value = aws_instance.interview.private_ip
}

output "instance_private_dns" {
  value = aws_instance.interview.private_dns
}

