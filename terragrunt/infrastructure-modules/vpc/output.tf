output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnet[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private_subnet[*].id
}

output "private_subnet_ids_by_az" {
  description = "Private subnet IDs grouped by availability zone"
  value = {
    for az in distinct(aws_subnet.private_subnet[*].availability_zone) :
    az => [for s in aws_subnet.private_subnet : s.id if s.availability_zone == az]
  }
}

output "nat_gateway_ids" {
  value = concat([aws_nat_gateway.ngw.id], [for n in aws_nat_gateway.ngw_az : n.id])
}
