import json
import os
import logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

QUARANTINE_SG_ID = os.environ.get('QUARANTINE_SECURITY_GROUP_ID')

ec2 = boto3.client('ec2')
iam = boto3.client('iam')

def extract_instance_id(event):
    """
    GuardDuty 이벤트에서 EC2 인스턴스 ID를 추출합니다.
    EventBridge를 통해 전달되는 경우와 직접 GuardDuty Finding인 경우를 모두 처리합니다.
    """
    # 경로 1: EventBridge 구조 (detail.resource.instanceDetails.instanceId)
    detail = event.get('detail', {})
    if detail:
        resource = detail.get('resource', {})
        if resource:
            instance_details = resource.get('instanceDetails', {})
            if instance_details:
                instance_id = instance_details.get('instanceId')
                if instance_id:
                    return instance_id
    
    # 경로 2: 직접 GuardDuty Finding 구조 (resource.instanceDetails.instanceId)
    resource = event.get('resource', {})
    if resource:
        instance_details = resource.get('instanceDetails', {})
        if instance_details:
            instance_id = instance_details.get('instanceId')
            if instance_id:
                return instance_id
    
    # 경로 3: 대소문자 변형 시도 (Resource.InstanceDetails.InstanceId)
    resource = event.get('Resource', {})
    if resource:
        instance_details = resource.get('InstanceDetails', {})
        if instance_details:
            instance_id = instance_details.get('InstanceId')
            if instance_id:
                return instance_id
    
    return None

def lambda_handler(event, context):
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        instance_id = extract_instance_id(event)
        
        if not instance_id:
            logger.error(f"Instance ID not found in event. Event structure: {json.dumps(event, default=str)}")
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Instance ID not found in event'})
            }
        
        if not QUARANTINE_SG_ID:
            logger.error("QUARANTINE_SECURITY_GROUP_ID environment variable is not set")
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'QUARANTINE_SECURITY_GROUP_ID environment variable is not set'})
            }
        
        logger.info(f"Quarantining instance: {instance_id} with security group: {QUARANTINE_SG_ID}")
        ec2.modify_instance_attribute(
            InstanceId=instance_id,
            Groups=[QUARANTINE_SG_ID]
        )
        logger.info(f"Successfully updated security group for instance: {instance_id}")
        
        try:
            associations = ec2.describe_iam_instance_profile_associations(
                Filters=[
                    {
                        'Name': 'instance-id',
                        'Values': [instance_id]
                    }
                ]
            )
            
            if associations['IamInstanceProfileAssociations']:
                association_id = associations['IamInstanceProfileAssociations'][0]['AssociationId']
                logger.info(f"Disassociating IAM instance profile: {association_id} from instance: {instance_id}")
                iam.disassociate_iam_instance_profile(
                    AssociationId=association_id
                )
                logger.info(f"Successfully disassociated IAM instance profile from instance: {instance_id}")
            else:
                logger.info(f"No IAM instance profile association found for instance: {instance_id}")
        except Exception as e:
            logger.warning(f"Failed to disassociate IAM instance profile for instance {instance_id}: {str(e)}")
        
        logger.info(f"Successfully quarantined instance: {instance_id}")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'EC2 instance successfully quarantined',
                'instance_id': instance_id
            })
        }
        
    except KeyError as e:
        logger.error(f"Invalid event structure: {str(e)}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': f'Invalid event structure: {str(e)}'})
        }
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }