
provider "aws" {
  access_key = "###################"      #Give your access_key 
  secret_key = "###################"      #Give your secret_key 
  region     = "ap-south-1"
}



# Generate and download key pair
resource "tls_private_key" "my_keypair" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "private_key" {
  content  = tls_private_key.my_keypair.private_key_pem
  filename = "C:/Users/my-pem.pem"  # Update with your desired path
}

# VPC Creation
resource "aws_vpc" "my_demo_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "my-demo-vpc"
  }
}

# Public and Private Subnets
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.my_demo_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.my_demo_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.my_demo_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-south-1a"
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.my_demo_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-south-1b"
}

# Internet Gateway and NAT Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_demo_vpc.id
}

resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.my_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
}

resource "aws_eip" "my_eip" {
  domain = "vpc" # Use domain attribute instead of vpc
}

# Route Tables
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.my_nat_gateway.id
  }
}

resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnet_1_association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_subnet_2_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

# Security Group
resource "aws_security_group" "my_security_group" {
  vpc_id = aws_vpc.my_demo_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Private Instances
resource "aws_instance" "private_instance_1" {
  subnet_id        = aws_subnet.private_subnet_1.id
  instance_type    = "t2.micro"
  ami              = "ami-03f4878755434977f" // Your AMI ID
  security_groups  = [aws_security_group.my_security_group.id]
   
 user_data = <<-EOF
              #!/bin/bash
              sudo apt update
              sudo apt install apache2 -y
              sudo systemctl enable apache2
              sudo systemctl start apache2
              echo "this is my 1st instance" | sudo tee /var/www/html/index.html > /dev/null
  EOF
}

resource "aws_instance" "private_instance_2" {
  subnet_id        = aws_subnet.private_subnet_2.id
  instance_type    = "t2.micro"
  ami              = "ami-03f4878755434977f" // Your AMI ID
  security_groups  = [aws_security_group.my_security_group.id]
   
   user_data = <<-EOF
              #!/bin/bash
              sudo apt update
              sudo apt install apache2 -y
              sudo systemctl enable apache2
              sudo systemctl start apache2
              echo "this is my 2nd instance" | sudo tee /var/www/html/index.html > /dev/null
  EOF

}

# Application Load Balancer (ALB)
resource "aws_lb" "my_load_balancer" {
  name               = "my-load-balancer"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  security_groups    = [aws_security_group.lb_security_group.id]

  enable_deletion_protection = false

  tags = {
    Name = "my-load-balancer"
  }
}

resource "aws_security_group" "lb_security_group" {
  vpc_id = aws_vpc.my_demo_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "my_target_group" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_demo_vpc.id
}

resource "aws_lb_target_group_attachment" "instance_1_attachment" {
  target_group_arn = aws_lb_target_group.my_target_group.arn
  target_id        = aws_instance.private_instance_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "instance_2_attachment" {
  target_group_arn = aws_lb_target_group.my_target_group.arn
  target_id        = aws_instance.private_instance_2.id
  port             = 80
}

# Update Security Groups for Instances
resource "aws_security_group_rule" "allow_lb_traffic" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.my_security_group.id
  source_security_group_id = aws_security_group.lb_security_group.id
}



# Listener for ALB
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.my_load_balancer.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}



# Output
output "load_balancer_dns_name" {
  value = aws_lb.my_load_balancer.dns_name
}


