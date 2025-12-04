output "vpc_info" {
  value = {
    vpc_id           = module.vpc.vpc_id
    vpc_cidr         = module.vpc.vpc_cidr_block
    public_subnets   = module.vpc.public_subnet_ids
    private_subnets  = module.vpc.private_subnet_ids
    internet_gateway = module.vpc.igw_id
    #nat_gateways     = module.vpc.nat_gateway_ids
  }
}

output "guardduty_info" {
  value = {
    guardduty_detector_id = module.guardduty.guardduty_detector_id
    guardduty_publishing_destination_id = module.guardduty.guardduty_publishing_destination_id
    s3_bucket_id = module.guardduty.s3_bucket_id
    s3_bucket_arn = module.guardduty.s3_bucket_arn
    s3_bucket_name = module.guardduty.s3_bucket_name
    kms_key_id = module.guardduty.kms_key_id
    kms_key_arn = module.guardduty.kms_key_arn
  }
}

output "cloudwatch_to_s3_info" {
  value = {
    log_group_id = module.cloudwatch_to_s3.log_group_id
    log_group_arn = module.cloudwatch_to_s3.log_group_arn
    s3_bucket_id = module.cloudwatch_to_s3.s3_bucket_id
    s3_bucket_arn = module.cloudwatch_to_s3.s3_bucket_arn
    delivery_stream_name = module.cloudwatch_to_s3.delivery_stream_name
    delivery_stream_arn = module.cloudwatch_to_s3.delivery_stream_arn
    kms_key_id = module.cloudwatch_to_s3.kms_key_id
    kms_key_arn = module.cloudwatch_to_s3.kms_key_arn
  }
}

output "cloudtrail_info" {
  value = {
    cloudtrail_id = module.cloudtrail.cloudtrail_id
    cloudtrail_arn = module.cloudtrail.cloudtrail_arn
    cloudtrail_name = module.cloudtrail.cloudtrail_name
    cloudtrail_home_region = module.cloudtrail.cloudtrail_home_region
    s3_bucket_id = module.cloudtrail.s3_bucket_id
    s3_bucket_arn = module.cloudtrail.s3_bucket_arn
    s3_bucket_name = module.cloudtrail.s3_bucket_name
    kms_key_id = module.cloudtrail.kms_key_id
    kms_key_arn = module.cloudtrail.kms_key_arn
  }
}

output "config_info" {
  value = {
    config_configuration_recorder_id = module.config.config_configuration_recorder_id
    config_configuration_recorder_name = module.config.config_configuration_recorder_name
    config_delivery_channel_id = module.config.config_delivery_channel_id
    config_delivery_channel_name = module.config.config_delivery_channel_name
    s3_bucket_id = module.config.s3_bucket_id
    s3_bucket_arn = module.config.s3_bucket_arn
    s3_bucket_name = module.config.s3_bucket_name
    iam_role_id = module.config.iam_role_id
    iam_role_arn = module.config.iam_role_arn
    iam_role_name = module.config.iam_role_name
    kms_key_id = module.config.kms_key_id
    kms_key_arn = module.config.kms_key_arn
  }
}

output "eks_info" {
  value = {
    cluster_id = module.EKS.cluster_id
    cluster_arn = module.EKS.cluster_arn
    cluster_name = module.EKS.cluster_name
    cluster_endpoint = module.EKS.cluster_endpoint
    cluster_version = module.EKS.cluster_version
    cluster_status = module.EKS.cluster_status
    cluster_oidc_issuer_url = module.EKS.cluster_oidc_issuer_url
    cluster_primary_security_group_id = module.EKS.cluster_primary_security_group_id
    cluster_security_group_id = module.EKS.cluster_security_group_id
    node_security_group_id = module.EKS.node_security_group_id
    cluster_iam_role_arn = module.EKS.cluster_iam_role_arn
    eks_managed_node_groups = module.EKS.eks_managed_node_groups
  }
}

# 주석 처리된 모듈이므로 output도 주석 처리
#output "ec2-monitoring-heal-info" {
#  value = {
#    lambda_function_arn = module.ec2-monitoring-heal.lambda_function_arn
#    lambda_function_name = module.ec2-monitoring-heal.lambda_function_name
#    event_rule_arn = module.ec2-monitoring-heal.event_rule_arn
#    event_rule_name = module.ec2-monitoring-heal.event_rule_name
#    iam_role_arn = module.ec2-monitoring-heal.iam_role_arn
#    iam_role_name = module.ec2-monitoring-heal.iam_role_name
#  }
#}

output "s3-public-block-info" {
  value = {
    lambda_function_arn = module.s3-public-block.lambda_function_arn
    lambda_function_name = module.s3-public-block.lambda_function_name
    event_rule_arn = module.s3-public-block.event_rule_arn
    event_rule_name = module.s3-public-block.event_rule_name
    iam_role_arn = module.s3-public-block.iam_role_arn
    iam_role_name = module.s3-public-block.iam_role_name
  }
}

output "bad-ec2-isol-info" {
  value = {
    lambda_function_arn = module.bad-ec2-isol.lambda_function_arn
    lambda_function_name = module.bad-ec2-isol.lambda_function_name
    event_rule_arn = module.bad-ec2-isol.event_rule_arn
    event_rule_name = module.bad-ec2-isol.event_rule_name
    iam_role_arn = module.bad-ec2-isol.iam_role_arn
    iam_role_name = module.bad-ec2-isol.iam_role_name
  }
}

output "auroraDB-info" {
  value = {
    cluster_id = module.auroraDB.cluster_id
    cluster_arn = module.auroraDB.cluster_arn
    cluster_endpoint = module.auroraDB.cluster_endpoint
    cluster_reader_endpoint = module.auroraDB.cluster_reader_endpoint
    cluster_database_name = module.auroraDB.cluster_database_name
  }
}

output "go-to-deep-info" {
  value = {
    lambda_function_arn = module.go-to-deep.lambda_function_arn
    lambda_function_name = module.go-to-deep.lambda_function_name
    lambda_role_arn = module.go-to-deep.lambda_role_arn
    event_rule_arn = module.go-to-deep.event_rule_arn
    s3_bucket_name = module.go-to-deep.s3_bucket_name
    s3_bucket_arn = module.go-to-deep.s3_bucket_arn
    aurora_export_role_arn = module.go-to-deep.aurora_export_role_arn
  }
}

output "iam-access-analyzer-info" {
  value = {
    analyzer_name = module.iam-access-analyzer.analyzer_name
    analyzer_arn  = module.iam-access-analyzer.analyzer_arn
  }
}