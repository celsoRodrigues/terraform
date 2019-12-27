provider "aws" {
  region = "eu-west-1"
  profile = "t"    
}

data "aws_ami" "amazon" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amazon1*"]
  }
}

resource "aws_launch_configuration" "interv" {
  image_id = 

}
