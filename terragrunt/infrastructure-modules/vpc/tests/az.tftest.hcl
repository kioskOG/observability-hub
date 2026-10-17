mock_provider "aws" {}

variables {
  region                           = "us-east-2"
  cidr_block                       = "10.36.0.0/16"
  vpc_name                         = "millenniumFalcon"
  vpc_env                          = "dev"
  enable_dns_hostnames             = true
  enable_dns_support               = true
  public_subnet_cidr_block         = ["10.36.0.0/20", "10.36.16.0/20", "10.36.128.0/20"]
  public_subnet_availability_zone  = ["us-east-2a", "us-east-2b", "us-east-2c"]
  map_public_ip_on_launch          = true
  private_subnet_cidr_block        = ["10.36.32.0/20", "10.36.48.0/20", "10.36.64.0/19", "10.36.96.0/19", "10.36.144.0/20"]
  availability_zone_priavte_subnet = ["us-east-2a", "us-east-2b", "us-east-2a", "us-east-2b", "us-east-2c"]
  sg_ingress_rules                 = []
  nat_gateway_per_az               = true
}

run "existing_subnets_keep_their_az" {
  command = plan
  assert {
    condition     = [for s in aws_subnet.private_subnet : s.availability_zone] == ["us-east-2a", "us-east-2b", "us-east-2a", "us-east-2b", "us-east-2c"]
    error_message = "private subnet AZ mapping changed"
  }
  assert {
    condition     = [for s in aws_subnet.private_subnet : s.cidr_block] == ["10.36.32.0/20", "10.36.48.0/20", "10.36.64.0/19", "10.36.96.0/19", "10.36.144.0/20"]
    error_message = "private subnet CIDRs changed"
  }
  assert {
    condition     = [for s in aws_subnet.public_subnet : s.availability_zone] == ["us-east-2a", "us-east-2b", "us-east-2c"]
    error_message = "public subnet AZ mapping changed"
  }
}

run "nat_per_az_routing" {
  command = apply
  assert {
    condition     = length(aws_nat_gateway.ngw_az) == 2 && contains(keys(aws_nat_gateway.ngw_az), "us-east-2b") && contains(keys(aws_nat_gateway.ngw_az), "us-east-2c")
    error_message = "expected extra NAT gateways in b and c"
  }
  assert {
    condition     = aws_nat_gateway.ngw.subnet_id == aws_subnet.public_subnet[0].id
    error_message = "primary NAT moved"
  }
  assert {
    condition = (
      aws_route_table_association.pri_route_association[0].route_table_id == aws_route_table.pri_sub_route.id &&
      aws_route_table_association.pri_route_association[2].route_table_id == aws_route_table.pri_sub_route.id &&
      aws_route_table_association.pri_route_association[1].route_table_id == aws_route_table.pri_sub_route_az["us-east-2b"].id &&
      aws_route_table_association.pri_route_association[3].route_table_id == aws_route_table.pri_sub_route_az["us-east-2b"].id &&
      aws_route_table_association.pri_route_association[4].route_table_id == aws_route_table.pri_sub_route_az["us-east-2c"].id
    )
    error_message = "private subnets not routed via their own AZ's NAT"
  }
  assert {
    condition     = output.private_subnet_ids_by_az["us-east-2c"] == [aws_subnet.private_subnet[4].id]
    error_message = "by-AZ output wrong"
  }
}

run "single_nat_default_unchanged" {
  command = apply
  variables {
    nat_gateway_per_az = false
  }
  assert {
    condition     = length(aws_nat_gateway.ngw_az) == 0 && alltrue([for a in aws_route_table_association.pri_route_association : a.route_table_id == aws_route_table.pri_sub_route.id])
    error_message = "default must keep one NAT for all private subnets"
  }
}
