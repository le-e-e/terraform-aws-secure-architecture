# 보안 그룹 생성 (선택적)
resource "aws_security_group" "aurora" {
  count = var.create_security_group ? 1 : 0

  name        = "${var.name}-sg"
  description = "Security group for Aurora DB"
  vpc_id      = var.vpc_id

  # 인바운드: MySQL/Aurora 포트 (3306) - VPC 내부에서만 접근
  ingress {
    description = "MySQL/Aurora from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # 아웃바운드: 모든 트래픽 허용
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-sg"
    }
  )
}

# EKS 노드 보안 그룹에서 접근 허용 (선택적)
resource "aws_security_group_rule" "aurora_from_eks" {
  count = var.create_security_group && length(var.allowed_security_group_ids) > 0 ? length(var.allowed_security_group_ids) : 0

  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_group_ids[count.index]
  security_group_id        = aws_security_group.aurora[0].id
  description              = "MySQL/Aurora access from allowed security group"
}

# 사용자명 자동 생성 (선택적)
resource "random_string" "master_username" {
  count = var.enable_auto_password && var.master_username == null ? 1 : 0

  length  = 16
  special = false
  upper   = true
  lower   = true
  numeric = true
}

# 비밀번호 자동 생성 (선택적)
resource "random_password" "master_password" {
  count = var.enable_auto_password && var.master_password == null ? 1 : 0

  length  = 32
  special = true
  # Aurora MySQL 비밀번호 제약사항: 특수문자 일부 제외
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# AWS Secrets Manager에 사용자명/비밀번호 저장 (선택적)
resource "aws_secretsmanager_secret" "master_password" {
  count = var.enable_auto_password && (var.master_password == null || var.master_username == null) ? 1 : 0

  name                    = "${var.name}/master-credentials"
  description             = "Aurora DB master username and password"
  recovery_window_in_days = 7

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "master_password" {
  count = var.enable_auto_password && (var.master_password == null || var.master_username == null) ? 1 : 0

  secret_id = aws_secretsmanager_secret.master_password[0].id
  secret_string = jsonencode({
    username = local.final_username
    password = local.final_password
  })
}

# 로컬 변수: 사용할 사용자명과 비밀번호 결정
locals {
  final_username = var.master_username != null ? var.master_username : (var.enable_auto_password ? random_string.master_username[0].result : "admin")
  final_password = var.master_password != null ? var.master_password : (var.enable_auto_password ? nonsensitive(random_password.master_password[0].result) : null)
  security_group_ids = var.create_security_group ? concat([aws_security_group.aurora[0].id], var.vpc_security_group_ids) : var.vpc_security_group_ids
}

# Aurora Cluster 생성
resource "aws_rds_cluster" "main" {
  cluster_identifier        = lower(var.name)
  engine                    = var.engine
  engine_version            = var.engine_version
  database_name             = var.database_name
  master_username           = local.final_username
  master_password           = local.final_password
  backup_retention_period   = var.backup_retention_period
  preferred_backup_window   = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window

  # 서브넷 그룹 설정
  db_subnet_group_name = aws_db_subnet_group.main.name

  # 보안 그룹 설정
  vpc_security_group_ids = local.security_group_ids

  # 암호화 및 성능 모니터링
  storage_encrypted                = true
  performance_insights_enabled     = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id = var.performance_insights_kms_key_id

  # 삭제 보호
  deletion_protection = true

  # 감사 로그 활성화
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]

  tags = merge(
    var.tags,
    {
      Backup = "true"  # AWS Backup 선택을 위한 태그
    }
  )
}

# DB Subnet Group 생성
resource "aws_db_subnet_group" "main" {
  name       = lower("${var.name}-subnet-group")
  subnet_ids = var.subnet_ids

  tags = var.tags
}

# Aurora Cluster Instance 생성
resource "aws_rds_cluster_instance" "main" {
  count = var.instance_count

  cluster_identifier = aws_rds_cluster.main.id
  instance_class    = var.instance_class
  engine            = var.engine
  engine_version    = var.engine_version

  tags = var.tags
}