//*******************************************
// SUBNETS
//*******************************************

// Public — ALB and NAT Gateway
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "${var.vpc_cidr}.0.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${var.aws_region}a"
  tags = { Name = "${var.client_name}_public_a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "${var.vpc_cidr}.1.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${var.aws_region}b"
  tags = { Name = "${var.client_name}_public_b" }
}

resource "aws_subnet" "public_c" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "${var.vpc_cidr}.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${var.aws_region}c"
  tags = { Name = "${var.client_name}_public_c" }
}

// Private — ECS Fargate tasks
resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "${var.vpc_cidr}.3.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${var.aws_region}a"
  tags = { Name = "${var.client_name}_private_a" }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "${var.vpc_cidr}.4.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${var.aws_region}b"
  tags = { Name = "${var.client_name}_private_b" }
}

resource "aws_subnet" "private_c" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "${var.vpc_cidr}.5.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${var.aws_region}c"
  tags = { Name = "${var.client_name}_private_c" }
}

// Database — RDS only, no internet route
resource "aws_subnet" "database_a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "${var.vpc_cidr}.6.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${var.aws_region}a"
  tags = { Name = "${var.client_name}_database_a" }
}

resource "aws_subnet" "database_b" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "${var.vpc_cidr}.7.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${var.aws_region}b"
  tags = { Name = "${var.client_name}_database_b" }
}

resource "aws_subnet" "database_c" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "${var.vpc_cidr}.8.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${var.aws_region}c"
  tags = { Name = "${var.client_name}_database_c" }
}
