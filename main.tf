terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

  }


## 나중에 환경변수로 설정할 예정
##provider "aws" {
##  region     = var.aws_region
##  access_key = var.aws_access_key
##  secret_key = var.aws_secret_key 
##}

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

module "cloudwatch" {
    source = "./modules/cloudwatch"

    project_name         = var.project_name
    log_group_name       = var.log_group_name
    retention_in_days    = var.retention_in_days
    tags                 = var.tags
}