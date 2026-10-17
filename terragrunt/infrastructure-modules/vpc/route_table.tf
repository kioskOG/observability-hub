resource "aws_route_table" "pub_sub_route" {
  vpc_id     = aws_vpc.main.id
  depends_on = [aws_internet_gateway.igw]
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.vpc_name}-${var.vpc_env}-public_rt"
  }
}

resource "aws_route_table" "pri_sub_route" {
  vpc_id     = aws_vpc.main.id
  depends_on = [aws_nat_gateway.ngw]
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }
  tags = {
    Name = "${var.vpc_name}-${var.vpc_env}-private-rt"
  }
}

resource "aws_route_table" "pri_sub_route_az" {
  for_each = local.extra_nat_azs
  vpc_id   = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw_az[each.key].id
  }
  tags = {
    Name = "${var.vpc_name}-${var.vpc_env}-private-rt-${each.key}"
  }
}

locals {
  # Private route table per AZ: the AZ's own NAT when nat_gateway_per_az, else the primary one.
  private_route_table_by_az = merge(
    { for az in distinct(var.availability_zone_priavte_subnet) : az => aws_route_table.pri_sub_route.id },
    { for az, rt in aws_route_table.pri_sub_route_az : az => rt.id },
  )
}
