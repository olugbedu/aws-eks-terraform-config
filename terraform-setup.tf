provider "aws" {
  region = "eu-west-1"
}

provider "aws" {
  region = "us-east-1"
  alias = "us_east"
  
}

#creating vpc
resource "aws_vpc" "culinario-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "culinario-vpc"
  }
}

#Creating public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.culinario-vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-1a"
  tags = {
    Name = "public-subnet"
  }
}

#Creating public2 subnet
resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.culinario-vpc.id
  cidr_block              = "10.0.5.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-1b"
  tags = {
    Name = "public-subnet-2"
  }
}
#creating private subnet

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.culinario-vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-1a"
  tags = {
    Name = "private-subnet"
  }
}

#creating private2 subnet

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.culinario-vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "eu-west-1b"
  tags = {
    Name = "private-subnet2"
  }
}


#crearting internet gateway

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.culinario-vpc.id
  tags = {
    Name = "culinario_internet-gateway"
  }
}

#creating public Routing tableS

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.culinario-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "publicRBT"
  }
}

#creating routing table associaton 

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


#creating routing2 table associaton 

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

#creating NATgateway

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags = {
    Name = "culinario-nat-gateway"
  }
}

#creating elastic ip 

resource "aws_eip" "nat" {
  domain = "vpc"
}

#creating private routing table

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.culinario-vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "privateRTB"
  }
}

#creating routing table associaton

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}


#creating routing table associaton

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private.id
}

#creating security group for the test server

resource "aws_security_group" "server_sg" {
  vpc_id = aws_vpc.culinario-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "server-sg"
  }
}
#creating security group for the cluster

resource "aws_security_group" "eks_sg" {
  vpc_id      = aws_vpc.culinario-vpc.id
  description = "EKS nodes security group"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.1.0/24", "10.0.5.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "culinario_cluster-sg"
  }
}
#creating security group for the load balancer

resource "aws_security_group" "alb_sg" {
  vpc_id      = aws_vpc.culinario-vpc.id
  description = "Security group for ALB"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "culinario-alb-sg"
  }
}

# Target group for the load balancer

resource "aws_lb" "this" {
  name               = "culinario-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public.id, aws_subnet.public2.id]

  enable_deletion_protection = false

  tags = {
    Name = "culinario-alb"
  }
}

resource "aws_lb_target_group" "this" {
  name     = "culinario-alb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.culinario-vpc.id

  health_check {
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "culinario-alb-target-group"
  }
}


resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}


#creating cluster

module "eks" {
  source                          = "terraform-aws-modules/eks/aws"
  version                         = "19.16.0"
  cluster_name                    = "culinario-EKS"
  cluster_version                 = "1.30"
  vpc_id                          = aws_vpc.culinario-vpc.id
  subnet_ids                      = [aws_subnet.private.id, aws_subnet.private2.id]
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_security_group_id       = aws_security_group.eks_sg.id
  eks_managed_node_group_defaults = {
    ami_type                   = "AL2_x86_64"
    instance_types             = ["t3.medium"]
    iam_role_attach_cni_policy = true
  }
  eks_managed_node_groups = {
    eks_nodes = {
      min_size       = 1
      max_size       = 3
      desired_size   = 1
      instance_types = ["t3.medium"]
    }
  }
  tags = {
    Name = "culinario-EKS"
  }
}

# ECR Repository 

resource "aws_ecrpublic_repository" "culinario" {
  provider = aws.us_east

  repository_name = "culinario"

  catalog_data {
    architectures     = ["ARM"]
    description       = "Description"
    operating_systems = ["Linux"]
  }

  tags = {
    env = "production"
  }
}
