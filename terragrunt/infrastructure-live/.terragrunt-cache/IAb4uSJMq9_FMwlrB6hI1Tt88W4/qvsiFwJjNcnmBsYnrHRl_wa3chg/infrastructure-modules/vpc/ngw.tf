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
