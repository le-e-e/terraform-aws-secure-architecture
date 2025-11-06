terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

  }
}

# 엑세스는 aws configure로 이용
provider "aws" {
  region     = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = var.tags
}

module "guardduty" {
  source = "./modules/gurdduty"

  project_name         = var.project_name
  enable               = var.enable
  finding_publishing_frequency = var.finding_publishing_frequency
  tags                 = var.tags
}

module "cloudwatch_to_s3" {
  source = "./modules/cloudwatch_to_s3"

  project_name         = var.project_name
  log_group_name       = var.log_group_name
  retention_in_days    = var.retention_in_days
  tags                 = var.tags
}