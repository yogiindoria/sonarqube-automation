terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  required_version = ">= 1.6.0"

  backend "s3" {
    bucket       = "yogi-sonarqube-terraform-state-2026"
    key          = "sonarqube/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
  
}

provider "aws" {
  region = var.aws_region
}