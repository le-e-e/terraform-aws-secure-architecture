import json
import logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

iam = boto3.client('iam')

# 모든 권한을 거부하는 정책
DENY_ALL_POLICY = {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Deny",
            "Action": "*",
            "Resource": "*"
        }
    ]
}

POLICY_NAME = "bad-iam"

def extract_iam_user(event):
    """
    GuardDuty 이벤트에서 IAM 사용자 이름을 추출합니다.
    EventBridge를 통해 전달되는 경우와 직접 GuardDuty Finding인 경우를 모두 처리합니다.
    """
    # 경로 1: EventBridge 구조 (detail.resource.accessKeyDetails.userName)
    detail = event.get('detail', {})
    if detail:
        resource = detail.get('resource', {})
        if resource:
            access_key_details = resource.get('accessKeyDetails', {})
            if access_key_details:
                user_name = access_key_details.get('userName')
                if user_name:
                    return user_name
    
    # 경로 2: 직접 GuardDuty Finding 구조 (resource.accessKeyDetails.userName)
    resource = event.get('resource', {})
    if resource:
        access_key_details = resource.get('accessKeyDetails', {})
        if access_key_details:
            user_name = access_key_details.get('userName')
            if user_name:
                return user_name
    
    # 경로 3: 대소문자 변형 시도 (Resource.AccessKeyDetails.UserName)
    resource = event.get('Resource', {})
    if resource:
        access_key_details = resource.get('AccessKeyDetails', {})
        if access_key_details:
            user_name = access_key_details.get('UserName')
            if user_name:
                return user_name
    
    return None

def apply_bad_iam_policy(user_name):
    """
    IAM 사용자에게 'bad-iam' 정책을 추가하여 모든 권한을 거부합니다.
    """
    try:
        # 사용자 존재 확인
        iam.get_user(UserName=user_name)
        logger.info(f"User {user_name} exists, proceeding with policy application")
    except iam.exceptions.NoSuchEntityException:
        logger.error(f"User {user_name} does not exist")
        raise
    except Exception as e:
        logger.error(f"Error checking user {user_name}: {str(e)}")
        raise
    
    try:
        # 기존 bad-iam 정책이 있는지 확인하고 삭제 (덮어쓰기)
        try:
            iam.delete_user_policy(
                UserName=user_name,
                PolicyName=POLICY_NAME
            )
            logger.info(f"Deleted existing '{POLICY_NAME}' policy for user {user_name}")
        except iam.exceptions.NoSuchEntityException:
            logger.info(f"No existing '{POLICY_NAME}' policy found for user {user_name}")
        except Exception as e:
            logger.warning(f"Error deleting existing policy for user {user_name}: {str(e)}")
        
        # 새로운 거부 정책 추가
        iam.put_user_policy(
            UserName=user_name,
            PolicyName=POLICY_NAME,
            PolicyDocument=json.dumps(DENY_ALL_POLICY)
        )
        logger.info(f"Successfully applied '{POLICY_NAME}' policy to user {user_name}")
        
        # 관리형 정책도 분리 (선택적 - 모든 관리형 정책 제거)
        try:
            attached_policies = iam.list_attached_user_policies(UserName=user_name)
            for policy in attached_policies.get('AttachedPolicies', []):
                try:
                    iam.detach_user_policy(
                        UserName=user_name,
                        PolicyArn=policy['PolicyArn']
                    )
                    logger.info(f"Detached policy {policy['PolicyArn']} from user {user_name}")
                except Exception as e:
                    logger.warning(f"Error detaching policy {policy['PolicyArn']} from user {user_name}: {str(e)}")
        except Exception as e:
            logger.warning(f"Error listing attached policies for user {user_name}: {str(e)}")
        
        # 액세스 키 삭제
        try:
            access_keys = iam.list_access_keys(UserName=user_name)
            for key in access_keys.get('AccessKeyMetadata', []):
                try:
                    iam.delete_access_key(
                        UserName=user_name,
                        AccessKeyId=key['AccessKeyId']
                    )
                    logger.info(f"Deleted access key {key['AccessKeyId']} for user {user_name}")
                except Exception as e:
                    logger.warning(f"Error deleting access key {key['AccessKeyId']} for user {user_name}: {str(e)}")
        except Exception as e:
            logger.warning(f"Error listing access keys for user {user_name}: {str(e)}")
        
    except Exception as e:
        logger.error(f"Error applying policy to user {user_name}: {str(e)}")
        raise

def lambda_handler(event, context):
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        user_name = extract_iam_user(event)
        
        if not user_name:
            logger.error(f"IAM user name not found in event. Event structure: {json.dumps(event, default=str)}")
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'IAM user name not found in event'})
            }
        
        logger.info(f"Applying 'bad-iam' policy to IAM user: {user_name}")
        apply_bad_iam_policy(user_name)
        
        logger.info(f"Successfully applied 'bad-iam' policy to user: {user_name}")
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'IAM user successfully restricted',
                'user_name': user_name,
                'policy_name': POLICY_NAME
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

