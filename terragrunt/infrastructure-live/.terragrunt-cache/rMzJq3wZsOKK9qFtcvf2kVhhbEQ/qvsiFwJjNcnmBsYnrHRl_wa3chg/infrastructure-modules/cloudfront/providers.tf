terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "< 5.70"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.region
}
