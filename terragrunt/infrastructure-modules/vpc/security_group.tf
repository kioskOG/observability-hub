resource "aws_security_group" "sg" {
  name        = "${var.vpc_name}-${var.vpc_env}-private-sg"
  description = var.sg_description
  vpc_id      = aws_vpc.main.id
  dynamic "ingress" {
    for_each = var.sg_ingress_rules
    content {
      description      = ingress.value.description
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      cidr_blocks      = ingress.value.cidr_blocks
      ipv6_cidr_blocks = ingress.value.ipv6_cidr_blocks
      security_groups  = lookup(ingress.value, "security_groups", null)
      self             = lookup(ingress.value, "self", null)
    }
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.vpc_name}-${var.vpc_env}-private-sg"
    Environment = var.vpc_env
  }
}