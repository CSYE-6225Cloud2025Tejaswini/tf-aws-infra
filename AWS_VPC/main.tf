provider "aws" {
  region  = var.region
  profile = var.profile
}

# Fetch available AZs dynamically
data "aws_availability_zones" "zones" {
  state = "available"
}

# Create custom VPC
resource "aws_vpc" "network" {
  cidr_block = var.network_cidr

  tags = {
    Name = "Custom-Network"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.network.id

  tags = {
    Name = "Custom-IGW"
  }
}

# Create Public Subnets Dynamically
resource "aws_subnet" "accessible" {
  count = var.subnet_count

  vpc_id                  = aws_vpc.network.id
  cidr_block              = cidrsubnet(var.network_cidr, 8, count.index) # Auto-calculates CIDR blocks
  availability_zone       = element(data.aws_availability_zones.zones.names, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "Accessible-Subnet-${count.index + 1}"
  }
}

# Create Private Subnets Dynamically
resource "aws_subnet" "restricted" {
  count = var.subnet_count

  vpc_id            = aws_vpc.network.id
  cidr_block        = cidrsubnet(var.network_cidr, 8, count.index + var.subnet_count) # Different range from public
  availability_zone = element(data.aws_availability_zones.zones.names, count.index)

  tags = {
    Name = "Restricted-Subnet-${count.index + 1}"
  }
}

# Create Public Route Table
resource "aws_route_table" "accessible_rt" {
  vpc_id = aws_vpc.network.id

  tags = {
    Name = "Accessible-Route-Table"
  }
}

# Add Internet Access Route
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.accessible_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "accessible_rta" {
  count          = var.subnet_count
  subnet_id      = element(aws_subnet.accessible[*].id, count.index)
  route_table_id = aws_route_table.accessible_rt.id
}

# Create Private Route Table
resource "aws_route_table" "restricted_rt" {
  vpc_id = aws_vpc.network.id

  tags = {
    Name = "Restricted-Route-Table"
  }
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "restricted_rta" {
  count          = var.subnet_count
  subnet_id      = element(aws_subnet.restricted[*].id, count.index)
  route_table_id = aws_route_table.restricted_rt.id
}


# Application Security Group
resource "aws_security_group" "application_sg" {
  vpc_id = aws_vpc.network.id

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

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
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
    Name = "Custom-Network-Application-SG"
  }
}

# EC2 Instance
resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.accessible[0].id
  vpc_security_group_ids = [aws_security_group.application_sg.id]
  key_name               = var.key_name

  root_block_device {
    volume_size           = 25
    volume_type           = "gp2"
    delete_on_termination = true
  }

  disable_api_termination = false

  tags = {
    Name = "Custom-Network-Web-Instance"
  }
}