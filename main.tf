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