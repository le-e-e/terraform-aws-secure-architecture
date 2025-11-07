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

data "aws_caller_identity" "current" {}

module "vpc" {
  source = "./modules/networking/vpc"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = var.tags
}

module "guardduty" {
  source = "./modules/security/guardduty"

  project_name         = var.project_name
  enable               = var.enable
  finding_publishing_frequency = var.finding_publishing_frequency
  tags                 = var.tags
}

module "cloudwatch_to_s3" {
  source = "./modules/monitoring/cloudwatch-to-s3"

  project_name                        = var.project_name
  log_group_name                      = var.log_group_name
  retention_in_days                   = var.retention_in_days
  cloudwatch_to_s3_kms_key_account_id = var.cloudwatch_to_s3_account_id != "" ? var.cloudwatch_to_s3_account_id : data.aws_caller_identity.current.account_id
  tags                                = var.tags
}

module "cloudtrail" {
  source = "./modules/security/cloudtrail"

  cloudtrail_name                     = var.cloudtrail_name
  cloudtrail_bucket_name              = var.cloudtrail_bucket_name
  cloudtrail_s3_key_prefix            = var.cloudtrail_s3_key_prefix
  cloudtrail_bucket_kms_key_arn        = var.cloudtrail_bucket_kms_key_arn
  cloudtrail_bucket_kms_key_account_id = var.cloudwatch_to_s3_account_id != "" ? var.cloudwatch_to_s3_account_id : data.aws_caller_identity.current.account_id
  tags                                = var.tags
}

module "config" {
  source = "./modules/security/config"

  config_delivery_channel_s3_bucket_name = var.config_delivery_channel_s3_bucket_name
  config_delivery_channel_s3_bucket_kms_key_account_id = var.config_delivery_channel_s3_bucket_kms_key_account_id != "" ? var.config_delivery_channel_s3_bucket_kms_key_account_id : data.aws_caller_identity.current.account_id
  tags = var.tags
}