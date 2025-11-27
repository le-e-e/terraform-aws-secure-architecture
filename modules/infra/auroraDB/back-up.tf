resource "aws_backup_vault" "aurora_backup" {
  name        = "${var.name}-backup-vault"
  kms_key_arn = aws_kms_key.backup_vault.arn

  tags = var.tags
}

# 2. KMS Key (백업 암호화용)
resource "aws_kms_key" "backup_vault" {
  description = "KMS key for Aurora backup vault"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowBackupUseKey"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# 3. Backup Plan 생성
resource "aws_backup_plan" "aurora_backup" {
  name = "${var.name}-backup-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.aurora_backup.name
    schedule          = "cron(0 3 * * ? *)"  # 매일 새벽 3시 (UTC)

    # 라이프사이클: 7일 warm storage 유지
    # 백업 완료 즉시 Lambda가 S3 Glacier로 export
    # 7일 동안은 warm storage와 S3 Glacier 둘 다 존재 (중복 보관)
    # 7일 후 AWS Backup에서 자동 삭제 (S3 Glacier만 유지)
    lifecycle {
      delete_after = 7  # 7일 warm storage 유지 후 자동 삭제
    }

    recovery_point_tags = var.tags
  }

  tags = var.tags
}

# 4. Backup Selection (Aurora 클러스터 선택)
resource "aws_backup_selection" "aurora_backup" {
  iam_role_arn = aws_iam_role.backup_role.arn
  name         = "${var.name}-backup-selection"
  plan_id      = aws_backup_plan.aurora_backup.id

  resources = [
    aws_aurora_cluster.main.arn
  ]

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "true"
  }
}

# 5. IAM Role (Backup 서비스용)
resource "aws_iam_role" "backup_role" {
  name = "${var.name}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "backup_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup_role.name
}

resource "aws_iam_role_policy_attachment" "backup_restore_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
  role       = aws_iam_role.backup_role.name
}

# Data source for account ID
data "aws_caller_identity" "current" {}