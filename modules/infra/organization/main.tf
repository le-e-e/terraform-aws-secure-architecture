resource "aws_organizations_organization" "main" {
  aws_service_access_principals = ["cloudtrail.amazonaws.com"]

  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]

  feature_set = "ALL"
}

resource "aws_organizations_policy" "main" {
  name = "organization-policy"
  description = "Organization policy"
  depends_on = [aws_organizations_organization.main]
  content = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "FullAWSAccess",
            "Effect": "Allow",
            "Action": "*",
            "Resource": "*"
        },
        {
            # cloudtrail ec2 모니터링 비활성화를 비활성화
            "Sid": "DenyEC2Unmonitor",
            "Effect": "Deny",
            "Action": "ec2:UnmonitorInstances",
            "Resource": "*"
      }
    ]
}
)
}