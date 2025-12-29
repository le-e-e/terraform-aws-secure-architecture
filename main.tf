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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
  }
}

# 엑세스는 aws configure로 이용
provider "aws" {
  region = var.aws_region
}

# Kubernetes Provider 설정 (EKS 클러스터 생성 후)
# 주의: provider 블록에서 모듈 output을 참조하지만, Terraform이 apply 시점에 처리
provider "kubernetes" {
  host                   = try(module.EKS.cluster_endpoint, "")
  cluster_ca_certificate = try(base64decode(module.EKS.cluster_certificate_authority_data), "")
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      try(module.EKS.cluster_name, "")
    ]
  }
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

  # ArgoCD 설정
  enable_argocd = true
  argocd_server_service_type = "LoadBalancer"
  
  # ArgoCD Git 레포지토리 등록 (자동화)
  argocd_repositories = [
    {
      name = "gitops-repo"
      url  = "https://github.com/your-org/gitops-repo.git"  # 실제 GitOps 저장소 URL로 변경
      type = "git"
      # username = "git"  # Private 레포지토리인 경우
      # password = var.gitops_repo_token  # Personal Access Token 등
      # 또는 SSH 사용 시:
      # ssh_private_key = var.gitops_repo_ssh_key
    }
  ]

  # External Secrets Operator 설정
  enable_external_secrets = true

  # Aurora DB 정보 (Kubernetes Secret/ConfigMap 생성용)
  # Aurora DB 모듈이 생성된 후에 전달됨
  aurora_db_config = {
    cluster_endpoint           = module.auroraDB.cluster_endpoint
    cluster_reader_endpoint    = module.auroraDB.cluster_reader_endpoint
    cluster_port               = module.auroraDB.cluster_port
    cluster_database_name      = module.auroraDB.cluster_database_name
    master_password_secret_arn = module.auroraDB.master_password_secret_arn
  }

  tags = var.tags
}

module "security-hub" {
  source = "./modules/security/security-hub"
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

module "iam-fire" {
  source = "./modules/automation/iam-fire"

  project_name = var.project_name
  tags         = var.tags
}

module "sg-checker" {
  source = "./modules/automation/SG-checker"

  project_name = var.project_name
  tags         = var.tags
}

################################################################################
# External Secrets Operator - SecretStore & ExternalSecret
################################################################################

# SecretStore 및 ExternalSecret 배포
# 주의: kubernetes_manifest는 plan 시점에 provider 초기화를 시도하므로
# null_resource와 kubectl을 사용하여 apply 시점에만 배포
locals {
  secretstore_yaml = <<-YAML
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: default
spec:
  provider:
    aws:
      service: SecretsManager
      region: ${var.aws_region}
      auth:
        jwt:
          serviceAccountRef:
            name: ${module.EKS.external_secrets_service_account_name}
            namespace: ${module.EKS.external_secrets_namespace}
YAML

  externalsecret_yaml = module.auroraDB.master_password_secret_arn != null ? (
    <<-YAML
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: aurora-db-credentials
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: aurora-db-credentials
    creationPolicy: Owner
  data:
    - secretKey: DB_USER
      remoteRef:
        key: ${module.auroraDB.master_password_secret_arn}
        property: username
    - secretKey: DB_PASSWORD
      remoteRef:
        key: ${module.auroraDB.master_password_secret_arn}
        property: password
YAML
  ) : ""
}

# SecretStore 배포
resource "null_resource" "external_secrets_secret_store" {
  count = module.EKS.external_secrets_namespace != null ? 1 : 0

  triggers = {
    yaml = local.secretstore_yaml
    cluster_name = module.EKS.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig --name ${module.EKS.cluster_name} --region ${var.aws_region}
      kubectl apply -f - <<EOF
${local.secretstore_yaml}
EOF
    EOT
  }

  depends_on = [module.EKS]
}

# ExternalSecret 배포
# 주의: master_password_secret_arn이 apply 시점에 결정되므로 조건 단순화
resource "null_resource" "external_secret_aurora_db" {
  count = module.EKS.external_secrets_namespace != null ? 1 : 0

  triggers = {
    yaml = local.externalsecret_yaml
    cluster_name = module.EKS.cluster_name
    # secret_arn은 apply 시점에 결정되므로 triggers에서 제외
  }

  provisioner "local-exec" {
    command = local.externalsecret_yaml != "" ? (
      <<-EOT
        aws eks update-kubeconfig --name ${module.EKS.cluster_name} --region ${var.aws_region}
        kubectl apply -f - <<EOF
${local.externalsecret_yaml}
EOF
      EOT
    ) : "echo 'Skipping ExternalSecret: master_password_secret_arn is null'"
  }

  depends_on = [
    null_resource.external_secrets_secret_store,
    module.EKS,
    module.auroraDB
  ]
}