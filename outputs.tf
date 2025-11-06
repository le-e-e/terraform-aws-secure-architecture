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
  }
}

