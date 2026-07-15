resource "aws_route_table_association" "pub_route_association" {
  count          = length(var.public_subnet_cidr_block)
  depends_on     = [aws_subnet.public_subnet, aws_route_table.pub_sub_route]
  subnet_id      = element(aws_subnet.public_subnet[*].id, count.index)
  route_table_id = aws_route_table.pub_sub_route.id
}


resource "aws_route_table_association" "pri_route_association" {
  count          = length(var.private_subnet_cidr_block)
  depends_on     = [aws_subnet.private_subnet, aws_route_table.pri_sub_route]
  subnet_id      = element(aws_subnet.private_subnet[*].id, count.index)
  route_table_id = aws_route_table.pri_sub_route.id
}

