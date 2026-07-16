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
  public_subnet_cidr_block = ["10.36.0.0/20","10.36.16.0/20"]
  public_subnet_availability_zone = ["us-east-2a", "us-east-2b"]
  map_public_ip_on_launch = true
  private_subnet_cidr_block = ["10.36.32.0/20","10.36.48.0/20","10.36.64.0/19","10.36.96.0/19"]
  availability_zone_priavte_subnet = ["us-east-2a", "us-east-2b"]
  sg_ingress_rules = []
}

# https://www.davidc.net/sites/default/subnets/subnets.html
