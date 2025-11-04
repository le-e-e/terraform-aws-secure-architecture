output "vpc_info" {
  value = {
    vpc_id           = module.vpc.vpc_id
    vpc_cidr         = module.vpc.vpc_cidr_block
    public_subnets   = module.vpc.public_subnet_ids
    private_subnets  = module.vpc.private_subnet_ids
    internet_gateway = module.vpc.internet_gateway_id
    nat_gateways     = module.vpc.nat_gateway_ids
  }
}

output "guardduty_info" {
  value = {
    guardduty_detector_id = module.guardduty.guardduty_detector_id
  }
}