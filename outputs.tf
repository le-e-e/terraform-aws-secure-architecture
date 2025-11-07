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