import boto3
import json

ec2_client = boto3.client('ec2')

def lambda_handler(event, context):
    try:
        # 1. 이벤트에서 EC2 인스턴스 ID 추출
        instance_ids = []
        

        items = event['detail']['requestParameters']['instancesSet']['items']
        
        for item in items:
            instance_ids.append(item['instanceId'])
            
        if not instance_ids:
            return {
                'statusCode': 200,
                'body': 'No instance IDs found.'
            }
        
        # 2. EC2 모니터링 재활성화 (MonitorInstances API 호출)
        response = ec2_client.monitor_instances(
            InstanceIds=instance_ids
        )
            
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'EC2 monitoring re-enabled successfully', 'instance_ids': instance_ids})
        }

    except KeyError as e:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': f'Invalid event structure: {e}'})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }