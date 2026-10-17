resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "${var.vpc_name}-${var.vpc_env}-nat-eip"
  }
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.0.id

  tags = {
    Name        = "${var.vpc_name}-${var.vpc_env}-natgateway"
    Environment = var.vpc_env
    ManagedBy   = "Terraform"
  }
}

# Per-AZ NAT gateways for every public-subnet AZ except the first, which keeps aws_nat_gateway.ngw.
# The original single-NAT resources stay as they are, so enabling this never re-creates them.
locals {
  public_azs = distinct(var.public_subnet_availability_zone)
  primary_az = var.public_subnet_availability_zone[0]
  extra_nat_azs = var.nat_gateway_per_az ? {
    for az in local.public_azs : az => index(var.public_subnet_availability_zone, az) if az != local.primary_az
  } : {}
}

resource "aws_eip" "nat_eip_az" {
  for_each = local.extra_nat_azs
  domain   = "vpc"
  tags = {
    Name = "${var.vpc_name}-${var.vpc_env}-nat-eip-${each.key}"
  }
}

resource "aws_nat_gateway" "ngw_az" {
  for_each      = local.extra_nat_azs
  allocation_id = aws_eip.nat_eip_az[each.key].id
  subnet_id     = aws_subnet.public_subnet[each.value].id

  tags = {
    Name        = "${var.vpc_name}-${var.vpc_env}-natgateway-${each.key}"
    Environment = var.vpc_env
    ManagedBy   = "Terraform"
  }
}
