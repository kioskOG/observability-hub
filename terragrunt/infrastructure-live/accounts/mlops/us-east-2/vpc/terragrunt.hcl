include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../..//infrastructure-modules/vpc/"
}

locals {
  common_vars = yamldecode(file("${get_terragrunt_dir()}/../common.yaml"))
}

inputs = {
  region      = local.common_vars["aws_region"]
  cidr_block = "10.36.0.0/16"
  vpc_name = "millenniumFalcon"
  vpc_env = local.common_vars["env_name"] #"dev"
  enable_dns_hostnames = true
  enable_dns_support = true
  # Three AZs. The module maps subnet i to AZ list entry i (element()), so both lists below are
  # written out per subnet: appending "us-east-2c" to a 2-entry AZ list would move existing
  # subnets 3/4 from a/b to c and re-create them. Only append; never reorder.
  #
  #   10.36.0.0/20   public  a      10.36.32.0/20  private a         10.36.64.0/19  private a
  #   10.36.16.0/20  public  b      10.36.48.0/20  private b         10.36.96.0/19  private b
  #   10.36.128.0/20 public  c      10.36.144.0/20 private c (EKS observability-c)   10.36.160.0/19+ free
  public_subnet_cidr_block = ["10.36.0.0/20","10.36.16.0/20","10.36.128.0/20"]
  public_subnet_availability_zone = ["us-east-2a", "us-east-2b", "us-east-2c"]
  map_public_ip_on_launch = true
  private_subnet_cidr_block = ["10.36.32.0/20","10.36.48.0/20","10.36.64.0/19","10.36.96.0/19","10.36.144.0/20"]
  availability_zone_priavte_subnet = ["us-east-2a", "us-east-2b", "us-east-2a", "us-east-2b", "us-east-2c"]
  # NAT gateway per AZ (the existing one stays in a): private subnets keep egress (ECR, STS, S3, AWS APIs)
  # when another AZ is down. Adds 2 NAT gateways + EIPs.
  nat_gateway_per_az = true
  sg_ingress_rules = []
}

# https://www.davidc.net/sites/default/subnets/subnets.html
