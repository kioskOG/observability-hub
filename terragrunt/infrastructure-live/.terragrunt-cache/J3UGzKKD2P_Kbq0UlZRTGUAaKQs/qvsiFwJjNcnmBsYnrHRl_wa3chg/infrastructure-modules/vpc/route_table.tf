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
