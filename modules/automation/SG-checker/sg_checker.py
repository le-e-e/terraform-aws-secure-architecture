import json
import logging
import os
from ipaddress import ip_network
from typing import Dict, List, Tuple

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client("ec2")

# SSM 사용 권장 포트 (무조건 차단)
BLOCKED_PORTS = {
    22: "SSH - Use SSM Session Manager instead",
    3389: "RDP - Use SSM Session Manager instead"
}

# HTTPS는 허용
ALLOWED_PORTS = {443}

# 예외 처리용 태그 키
EXCEPTION_TAG_KEY = "SGCheckerException"  # 이 태그가 있으면 검사 제외


def is_world_cidr(cidr: str) -> bool:
    """0.0.0.0/0 또는 ::/0인지 확인"""
    try:
        net = ip_network(cidr, strict=False)
        return net.prefixlen == 0
    except Exception:
        return False


def is_exception_security_group(sg: Dict, exception_tag: str) -> bool:
    """예외 처리 대상 보안 그룹인지 확인 (bastion host 등)"""
    if not exception_tag:
        return False
    
    for tag in sg.get("Tags", []):
        if tag.get("Key") == exception_tag:
            return True
    
    # 보안 그룹 이름 패턴으로도 확인 (예: bastion-*)
    sg_name = sg.get("GroupName", "")
    if sg_name.startswith("bastion-") or "bastion" in sg_name.lower():
        return True
    
    return False


def check_vulnerable_ports(sg: Dict, exception_tag: str) -> List[Dict]:
    """0.0.0.0/0로 열린 취약한 포트 검사"""
    findings = []
    
    # 예외 처리 대상은 검사 제외
    if is_exception_security_group(sg, exception_tag):
        logger.info(f"Skipping exception security group: {sg.get('GroupId')} ({sg.get('GroupName')})")
        return findings
    
    # 인바운드 규칙 검사
    for perm in sg.get("IpPermissions", []):
        proto = perm.get("IpProtocol", "-1")
        from_port = perm.get("FromPort")
        to_port = perm.get("ToPort")
        
        # IPv4 CIDR 검사
        for ip_range in perm.get("IpRanges", []):
            cidr = ip_range.get("CidrIp")
            if cidr and is_world_cidr(cidr):
                # 모든 포트/프로토콜
                if proto == "-1" or (from_port is None and to_port is None):
                    findings.append({
                        "group_id": sg.get("GroupId"),
                        "group_name": sg.get("GroupName"),
                        "direction": "ingress",
                        "protocol": proto,
                        "ports": "all",
                        "cidr": cidr,
                        "severity": "critical",
                        "description": "All ports and protocols exposed to internet"
                    })
                # 포트 범위
                elif from_port is not None and to_port is not None:
                    # 범위 내의 각 포트 확인
                    for port in range(from_port, to_port + 1):
                        # HTTPS는 제외
                        if port in ALLOWED_PORTS:
                            continue
                        
                        # SSH/RDP는 critical
                        if port in BLOCKED_PORTS:
                            findings.append({
                                "group_id": sg.get("GroupId"),
                                "group_name": sg.get("GroupName"),
                                "direction": "ingress",
                                "protocol": proto,
                                "ports": str(port),
                                "cidr": cidr,
                                "severity": "critical",
                                "description": f"{BLOCKED_PORTS[port]}",
                                "action": "block"
                            })
                        else:
                            # 기타 포트는 high
                            findings.append({
                                "group_id": sg.get("GroupId"),
                                "group_name": sg.get("GroupName"),
                                "direction": "ingress",
                                "protocol": proto,
                                "ports": str(port),
                                "cidr": cidr,
                                "severity": "high",
                                "description": f"Port {port} exposed to internet"
                            })
        
        # IPv6 CIDR 검사
        for ipv6_range in perm.get("Ipv6Ranges", []):
            cidr = ipv6_range.get("CidrIpv6")
            if cidr and is_world_cidr(cidr):
                if proto == "-1" or (from_port is None and to_port is None):
                    findings.append({
                        "group_id": sg.get("GroupId"),
                        "group_name": sg.get("GroupName"),
                        "direction": "ingress",
                        "protocol": proto,
                        "ports": "all",
                        "cidr": cidr,
                        "severity": "critical",
                        "description": "All ports and protocols exposed to internet (IPv6)"
                    })
                elif from_port is not None and to_port is not None:
                    for port in range(from_port, to_port + 1):
                        if port in ALLOWED_PORTS:
                            continue
                        if port in BLOCKED_PORTS:
                            findings.append({
                                "group_id": sg.get("GroupId"),
                                "group_name": sg.get("GroupName"),
                                "direction": "ingress",
                                "protocol": proto,
                                "ports": str(port),
                                "cidr": cidr,
                                "severity": "critical",
                                "description": f"{BLOCKED_PORTS[port]} (IPv6)",
                                "action": "block"
                            })
    
    return findings


def is_security_group_in_use(sg_id: str) -> Tuple[bool, List[str]]:
    """보안 그룹이 사용 중인지 확인"""
    try:
        instances = ec2.describe_instances(
            Filters=[
                {'Name': 'instance.group-id', 'Values': [sg_id]},
                {'Name': 'instance-state-name', 'Values': ['running', 'stopped', 'pending', 'stopping']}
            ]
        )
        
        instance_ids = []
        for reservation in instances.get('Reservations', []):
            for instance in reservation.get('Instances', []):
                instance_ids.append(instance.get('InstanceId'))
        
        enis = ec2.describe_network_interfaces(
            Filters=[{'Name': 'group-id', 'Values': [sg_id]}]
        )
        eni_ids = [eni.get('NetworkInterfaceId') for eni in enis.get('NetworkInterfaces', [])]
        
        rds = boto3.client('rds')
        rds_resources = []
        try:
            db_instances = rds.describe_db_instances()
            for db in db_instances.get('DBInstances', []):
                for vpc_sg in db.get('VpcSecurityGroups', []):
                    if vpc_sg.get('VpcSecurityGroupId') == sg_id:
                        rds_resources.append(f"RDS:{db.get('DBInstanceIdentifier')}")
            
            db_clusters = rds.describe_db_clusters()
            for cluster in db_clusters.get('DBClusters', []):
                for vpc_sg in cluster.get('VpcSecurityGroups', []):
                    if vpc_sg == sg_id:
                        rds_resources.append(f"RDS-Cluster:{cluster.get('DBClusterIdentifier')}")
        except Exception as e:
            logger.warning(f"Could not check RDS: {str(e)}")
        
        in_use = len(instance_ids) > 0 or len(eni_ids) > 0 or len(rds_resources) > 0
        resources = []
        if instance_ids:
            resources.extend([f"EC2:{iid}" for iid in instance_ids])
        if eni_ids:
            resources.extend([f"ENI:{eid}" for eid in eni_ids])
        if rds_resources:
            resources.extend(rds_resources)
        
        return in_use, resources
    
    except Exception as e:
        logger.error(f"Error checking security group usage: {str(e)}")
        return True, ["Unknown - error checking"]


def delete_security_group(sg_id: str, sg_name: str) -> Dict:
    """보안 그룹 삭제 (사용 중이 아닐 때만)"""
    try:
        in_use, resources = is_security_group_in_use(sg_id)
        
        if in_use:
            return {
                "success": False,
                "reason": "security_group_in_use",
                "resources": resources,
                "message": f"Security group {sg_id} ({sg_name}) is in use"
            }
        
        if sg_name == "default":
            return {
                "success": False,
                "reason": "default_security_group",
                "message": "Default security groups cannot be deleted"
            }
        
        ec2.delete_security_group(GroupId=sg_id)
        logger.warning(f"DELETED security group: {sg_id} ({sg_name})")
        
        return {
            "success": True,
            "security_group_id": sg_id,
            "security_group_name": sg_name,
            "message": f"Successfully deleted {sg_id} ({sg_name})"
        }
    
    except ec2.exceptions.ClientError as e:
        error_code = e.response.get('Error', {}).get('Code', '')
        if error_code == 'DependencyViolation':
            return {
                "success": False,
                "reason": "dependency_violation",
                "message": f"Cannot delete {sg_id}: {str(e)}"
            }
        return {
            "success": False,
            "reason": "client_error",
            "message": f"Error deleting {sg_id}: {str(e)}"
        }
    except Exception as e:
        logger.error(f"Unexpected error deleting {sg_id}: {str(e)}")
        return {
            "success": False,
            "reason": "unexpected_error",
            "message": f"Unexpected error: {str(e)}"
        }


def filter_by_tag(sg: Dict, tag_key: str, tag_value: str) -> bool:
    """태그로 필터링"""
    if not tag_key:
        return True
    for tag in sg.get("Tags", []):
        if tag.get("Key") == tag_key and (
            tag_value == "" or tag.get("Value") == tag_value
        ):
            return True
    return False


def paginate_security_groups(filters=None) -> List[Dict]:
    """보안 그룹 페이징 조회"""
    paginator = ec2.get_paginator("describe_security_groups")
    groups = []
    for page in paginator.paginate(Filters=filters or []):
        groups.extend(page.get("SecurityGroups", []))
    return groups


def extract_security_group_id_from_event(event: Dict) -> str:
    """CloudTrail 이벤트에서 변경된 보안 그룹 ID 추출"""
    try:
        detail = event.get("detail", {})
        event_name = detail.get("eventName", "")
        
        # CreateSecurityGroup: responseElements에서 추출
        if event_name == "CreateSecurityGroup":
            response_elements = detail.get("responseElements", {})
            group_id = response_elements.get("groupId")
            if group_id:
                return group_id
        
        # 나머지 이벤트: requestParameters에서 추출
        request_params = detail.get("requestParameters", {})
        
        # groupId 필드 확인
        if "groupId" in request_params:
            return request_params["groupId"]
        
        # groupId가 없으면 group-name으로 조회 시도
        group_name = request_params.get("groupName")
        if group_name:
            # 이름으로 SG 조회하여 ID 반환
            try:
                sgs = ec2.describe_security_groups(
                    Filters=[{'Name': 'group-name', 'Values': [group_name]}]
                )
                if sgs.get("SecurityGroups"):
                    return sgs["SecurityGroups"][0].get("GroupId")
            except Exception as e:
                logger.warning(f"Could not find SG by name {group_name}: {str(e)}")
        
        return None
    except Exception as e:
        logger.error(f"Error extracting SG ID from event: {str(e)}")
        return None


def lambda_handler(event, context):
    try:
        logger.info("Event: %s", json.dumps(event))
        
        # 환경 변수
        auto_delete = os.getenv("AUTO_DELETE", "false").lower() == "true"
        delete_only_critical = os.getenv("DELETE_ONLY_CRITICAL", "true").lower() == "true"
        exception_tag = os.getenv("EXCEPTION_TAG_KEY", EXCEPTION_TAG_KEY)
        
        # CloudTrail 이벤트에서 변경된 SG ID 추출
        changed_sg_id = extract_security_group_id_from_event(event)
        
        if not changed_sg_id:
            logger.warning("Could not extract security group ID from event. Skipping.")
            return {
                "statusCode": 200,
                "body": json.dumps({
                    "message": "No security group ID found in event",
                    "event": event
                })
            }
        
        logger.info(f"Checking security group: {changed_sg_id}")
        
        # 변경된 보안 그룹만 조회
        try:
            response = ec2.describe_security_groups(GroupIds=[changed_sg_id])
            sgs = response.get("SecurityGroups", [])
        except ec2.exceptions.ClientError as e:
            logger.error(f"Error describing security group {changed_sg_id}: {str(e)}")
            return {
                "statusCode": 200,
                "body": json.dumps({
                    "error": f"Could not describe security group: {str(e)}",
                    "security_group_id": changed_sg_id
                })
            }
        
        if not sgs:
            logger.warning(f"Security group {changed_sg_id} not found")
            return {
                "statusCode": 200,
                "body": json.dumps({
                    "message": f"Security group {changed_sg_id} not found"
                })
            }
        
        sg = sgs[0]
        all_findings = []
        deleted_groups = []
        failed_deletions = []
        
        # 취약 포트 검사
        findings = check_vulnerable_ports(sg, exception_tag)
        all_findings.extend(findings)
        
        # 자동 삭제 옵션
        if auto_delete and findings:
            sg_id = sg.get("GroupId")
            sg_name = sg.get("GroupName")
            
            # Critical만 삭제 옵션
            if delete_only_critical:
                critical_findings = [f for f in findings if f.get("severity") == "critical"]
                if not critical_findings:
                    logger.info(f"No critical findings for {sg_id}, skipping deletion")
                else:
                    # 보안 그룹 삭제 시도
                    result = delete_security_group(sg_id, sg_name)
                    if result.get("success"):
                        deleted_groups.append(result)
                    else:
                        failed_deletions.append(result)
            else:
                # 모든 취약점에 대해 삭제
                result = delete_security_group(sg_id, sg_name)
                if result.get("success"):
                    deleted_groups.append(result)
                else:
                    failed_deletions.append(result)
        
        # 결과 정리
        result = {
            "security_group_id": changed_sg_id,
            "security_group_name": sg.get("GroupName"),
            "findings_count": len(all_findings),
            "findings": all_findings,
            "auto_delete_enabled": auto_delete,
            "deleted_groups": deleted_groups,
            "failed_deletions": failed_deletions,
            "summary": {
                "critical": len([f for f in all_findings if f.get("severity") == "critical"]),
                "high": len([f for f in all_findings if f.get("severity") == "high"]),
            }
        }
        
        logger.info("Security Group Check Results: %s", json.dumps(result, ensure_ascii=False, default=str))
        
        if result["summary"]["critical"] > 0:
            logger.warning(f"CRITICAL: Found {result['summary']['critical']} critical vulnerabilities in {changed_sg_id}!")
            if auto_delete and deleted_groups:
                logger.warning(f"DELETED security group {changed_sg_id} due to critical vulnerabilities")
        
        return {
            "statusCode": 200,
            "body": json.dumps(result, ensure_ascii=False, default=str),
        }
    
    except Exception as e:
        logger.error("Unexpected error: %s", str(e), exc_info=True)
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)}),
        }
