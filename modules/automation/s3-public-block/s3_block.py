import json
import boto3
from botocore.exceptions import ClientError

s3 = boto3.client('s3')

def lambda_handler(event, context):
    try:
        detail = event["detail"]
        event_name = detail.get("eventName")
        
        # 다양한 이벤트 타입에 대해 버킷 이름 추출 시도
        bucket_name = None
        request_params = detail.get("requestParameters", {})
        response_elements = detail.get("responseElements", {})
        
        # 1. requestParameters.bucketName (대부분의 이벤트)
        if "bucketName" in request_params:
            bucket_name = request_params["bucketName"]
        # 2. requestParameters.bucket (일부 이벤트)
        elif "bucket" in request_params:
            bucket_name = request_params["bucket"]
        # 3. responseElements.bucketName (CreateBucket의 경우)
        elif "bucketName" in response_elements:
            bucket_name = response_elements["bucketName"]
        
        if not bucket_name:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Bucket name not found in event'})
            }
        
        # PutBucketPublicAccessBlock 이벤트인 경우, 현재 설정 확인
        if event_name == "PutBucketPublicAccessBlock":
            # 이벤트에서 변경하려는 설정 확인
            new_config = request_params.get("PublicAccessBlockConfiguration", {})
            block_public_acls = new_config.get("BlockPublicAcls", False)
            ignore_public_acls = new_config.get("IgnorePublicAcls", False)
            block_public_policy = new_config.get("BlockPublicPolicy", False)
            restrict_public_buckets = new_config.get("RestrictPublicBuckets", False)
            
            # 이미 모든 설정이 True인 경우 무한 루프 방지를 위해 스킵
            if block_public_acls and ignore_public_acls and block_public_policy and restrict_public_buckets:
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'message': 'Public Access Block already properly configured, skipping',
                        'bucket': bucket_name,
                        'event': event_name
                    })
                }
            
            # 현재 버킷의 실제 설정 확인
            try:
                current_config = s3.get_public_access_block(Bucket=bucket_name)
                current_pab = current_config.get("PublicAccessBlockConfiguration", {})
                
                # 이미 모든 설정이 True인 경우 스킵
                if (current_pab.get("BlockPublicAcls") and 
                    current_pab.get("IgnorePublicAcls") and 
                    current_pab.get("BlockPublicPolicy") and 
                    current_pab.get("RestrictPublicBuckets")):
                    return {
                        'statusCode': 200,
                        'body': json.dumps({
                            'message': 'Public Access Block already properly configured, skipping',
                            'bucket': bucket_name,
                            'event': event_name
                        })
                    }
            except ClientError as e:
                # Public Access Block이 설정되지 않은 경우 또는 다른 오류
                error_code = e.response.get('Error', {}).get('Code', '')
                if error_code == 'NoSuchPublicAccessBlockConfiguration':
                    # Public Access Block이 설정되지 않은 경우 계속 진행
                    pass
                else:
                    # 다른 오류인 경우 다시 발생시킴
                    raise
        
        # Public Access Block 설정 적용
        s3.put_public_access_block(
            Bucket=bucket_name,
            PublicAccessBlockConfiguration={
                'BlockPublicAcls': True,
                'IgnorePublicAcls': True,
                'BlockPublicPolicy': True,
                'RestrictPublicBuckets': True
            }
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Public Access Block configured successfully',
                'bucket': bucket_name,
                'event': event_name
            })
        }
        
    except KeyError as e:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': f'Invalid event structure: {str(e)}'})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
