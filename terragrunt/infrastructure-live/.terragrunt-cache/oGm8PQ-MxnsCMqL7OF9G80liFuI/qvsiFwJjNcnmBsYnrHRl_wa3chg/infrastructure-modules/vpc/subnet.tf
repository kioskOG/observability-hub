resource "aws_subnet" "public_subnet" {
  count                   = length(var.public_subnet_cidr_block)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.public_subnet_cidr_block, count.index)
  availability_zone       = element(var.public_subnet_availability_zone, count.index)
  map_public_ip_on_launch = var.map_public_ip_on_launch # Enable public IP assignment
  tags = {
    Name = "${var.vpc_name}-${var.vpc_env}-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnet" {
  count             = length(var.private_subnet_cidr_block)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_subnet_cidr_block, count.index)
  availability_zone = element(var.availability_zone_priavte_subnet, count.index)
  tags = {
    Name = "${var.vpc_name}-${var.vpc_env}-private-subnet-${count.index + 1}"
  }
}

