terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.15"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# 엑세스는 aws configure로 이용
provider "aws" {
  region     = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  # marked value 문제를 피하기 위해 account_id를 로컬 변수로 분리
  account_id = data.aws_caller_identity.current.account_id
}

module "vpc" {
  source = "./modules/networking/vpc"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = var.tags
}

module "EKS" {
  source = "./modules/infra/EKS"

  name = "${var.project_name}-eks"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  
  # 엔드포인트 설정
  endpoint_private_access = true
  endpoint_public_access  = false
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    example = {
      kubernetes_version = null  # 명시적으로 null 설정하여 클러스터 버전 사용
      instance_types = ["t3.small"]
      capacity_type = "SPOT"
      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }

  tags = var.tags
}

module "guardduty" {
  source = "./modules/security/guardduty"

  project_name         = var.project_name
  enable               = var.enable
  finding_publishing_frequency = var.finding_publishing_frequency
  guardduty_s3_bucket_name = var.guardduty_s3_bucket_name
  guardduty_kms_key_account_id = var.guardduty_kms_key_account_id != "" ? var.guardduty_kms_key_account_id : local.account_id
  tags                 = var.tags
}

module "cloudwatch_to_s3" {
  source = "./modules/monitoring/cloudwatch-to-s3"

  project_name                        = var.project_name
  log_group_name                      = var.log_group_name
  retention_in_days                   = var.retention_in_days
  cloudwatch_to_s3_kms_key_account_id = var.cloudwatch_to_s3_account_id != "" ? var.cloudwatch_to_s3_account_id : local.account_id
  tags                                = var.tags
}

module "cloudtrail" {
  source = "./modules/security/cloudtrail"

  cloudtrail_name                     = var.cloudtrail_name
  cloudtrail_bucket_name              = var.cloudtrail_bucket_name
  cloudtrail_s3_key_prefix            = var.cloudtrail_s3_key_prefix
  cloudtrail_bucket_kms_key_arn        = var.cloudtrail_bucket_kms_key_arn
  cloudtrail_bucket_kms_key_account_id = var.cloudwatch_to_s3_account_id != "" ? var.cloudwatch_to_s3_account_id : local.account_id
  tags                                = var.tags
}

module "config" {
  source = "./modules/security/config"

  config_delivery_channel_s3_bucket_name = var.config_delivery_channel_s3_bucket_name
  config_delivery_channel_s3_bucket_kms_key_account_id = var.config_delivery_channel_s3_bucket_kms_key_account_id != "" ? var.config_delivery_channel_s3_bucket_kms_key_account_id : local.account_id
  tags = var.tags
}


# 정말 중요한 서비스에 대한 자동 복구 기능을 추가하고 싶다면 사용
# 기본 모니터링은 비활성화가 불가능하므로 불필요한 요금 발생 가능
#module "ec2-monitoring-heal" {
#  source = "./modules/automation/ec2-monitoring-heal"
#
#  project_name = var.project_name
#  tags         = var.tags
#}

module "s3-public-block" {
  source = "./modules/automation/s3-public-block"

  project_name = var.project_name
  tags = var.tags
}

module "bad-ec2-isol" {
  source = "./modules/automation/bad-ec2-isol"

  project_name = var.project_name
  tags = var.tags
  vpc_id = module.vpc.vpc_id
}

module "auroraDB" {
  source = "./modules/infra/auroraDB"

  name                      = "${var.project_name}-auroraDB"
  engine                    = "aurora-mysql"
  engine_version            = "8.0.mysql_aurora.3.02.2"
  database_name             = "auroraDB"
  backup_retention_period   = 30
  preferred_backup_window   = "03:00-04:00"
  
  # 네트워크 설정
  vpc_id                    = module.vpc.vpc_id
  vpc_cidr                  = var.vpc_cidr
  subnet_ids                = module.vpc.private_subnet_ids
  
  # EKS 접근 허용
  allowed_security_group_ids = [module.EKS.node_security_group_id]
  
  # 인스턴스 설정
  instance_class            = "db.t3.medium"
  instance_count            = 2
  
  tags = var.tags
}

module "go-to-deep" {
  source = "./modules/automation/go-to-deep"

  backup_vault_name = module.auroraDB.backup_vault_name
  backup_vault_arn  = module.auroraDB.backup_vault_arn
  aurora_cluster_id = module.auroraDB.cluster_id
  project_name = var.project_name
  tags = var.tags
}

module "vpc_flow_logs" {
  source = "./modules/monitoring/vpc-flow-logs"

  project_name = var.project_name
  vpc_id = module.vpc.vpc_id
  tags = var.tags
}

module "iam-access-analyzer" {
  source = "./modules/security/iam-access-analyzer"
  tags = var.tags
}