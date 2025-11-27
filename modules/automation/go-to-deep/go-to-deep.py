import boto3
import json
from datetime import datetime, timezone, timedelta
from botocore.exceptions import ClientError

# AWS 클라이언트 초기화
backup_client = boto3.client('backup')
rds_client = boto3.client('rds')
s3_client = boto3.client('s3')

import os

# 환경 변수에서 설정 읽기
BACKUP_VAULT_NAME = os.environ.get('BACKUP_VAULT_NAME')
AURORA_CLUSTER_ID = os.environ.get('AURORA_CLUSTER_ID')
S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')
WARM_STORAGE_DAYS = int(os.environ.get('WARM_STORAGE_DAYS', '30'))
ONE_YEAR_DAYS = 365  # 1년 = 365일
SEVEN_YEARS_DAYS = 2555  # 7년 = 2555일


def lambda_handler(event, context):
    """
    Aurora DB 백업 관리:
    1. 백업 완료 이벤트 감지 시 즉시 S3 Glacier로 export
    2. 정기 스케줄: 7년 이상 보관된 백업 삭제
    """
    try:
        # 환경 변수에서 설정 읽기
        backup_vault_name = BACKUP_VAULT_NAME
        aurora_cluster_id = AURORA_CLUSTER_ID
        s3_bucket_name = S3_BUCKET_NAME
        
        if not all([backup_vault_name, aurora_cluster_id, s3_bucket_name]):
            error_msg = 'backup_vault_name, aurora_cluster_id, and s3_bucket_name are required.'
            print(f"ERROR: {error_msg}")
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': error_msg
                })
            }
        
        # EventBridge 이벤트인지 확인 (백업 완료 이벤트)
        if 'source' in event and event.get('source') == 'aws.backup':
            # 백업 완료 이벤트 처리
            return handle_backup_completed_event(event, backup_vault_name, aurora_cluster_id, s3_bucket_name)
        else:
            # 정기 스케줄 실행 (7년 이상 된 백업 정리)
            return handle_scheduled_cleanup(backup_vault_name)
        
    except Exception as e:
        print(f"Lambda execution error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }


def handle_backup_completed_event(event, backup_vault_name, aurora_cluster_id, s3_bucket_name):
    """
    백업 완료 이벤트 처리: 백업 완료 즉시 S3 Glacier로 export
    """
    print(f"Backup completed event received: {json.dumps(event)}")
    
    try:
        # EventBridge 이벤트에서 Recovery Point 정보 추출
        detail = event.get('detail', {})
        backup_job_id = detail.get('backupJobId')
        recovery_point_arn = detail.get('recoveryPointArn')
        
        if not recovery_point_arn:
            print("ERROR: recoveryPointArn not found in event")
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'recoveryPointArn not found in event'
                })
            }
        
        print(f"Processing backup job: {backup_job_id}, Recovery Point: {recovery_point_arn}")
        
        # Recovery Point 정보 조회
        try:
            recovery_point_response = backup_client.describe_recovery_point(
                BackupVaultName=backup_vault_name,
                RecoveryPointArn=recovery_point_arn
            )
            recovery_point = recovery_point_response.get('RecoveryPoint', {})
        except ClientError as e:
            print(f"Error describing recovery point: {str(e)}")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': f'Failed to describe recovery point: {str(e)}'
                })
            }
        
        # 즉시 S3로 export
        try:
            result = export_recovery_point_to_s3(
                recovery_point,
                backup_vault_name,
                aurora_cluster_id,
                s3_bucket_name
            )
            
            # Export 성공: AWS Backup은 7일 동안 warm storage로 유지 (빠른 복원용)
            # 7일 후 AWS Backup lifecycle 정책에 의해 자동 삭제됨
            # 이 기간 동안 warm storage와 S3 Glacier 둘 다 존재 (중복 보관)
            if result.get('status') == 'export_started':
                print(f"Export started. Recovery point will remain in warm storage for 7 days (AWS Backup lifecycle)")
                result['backup_retention'] = '7 days in warm storage (auto-deleted by lifecycle)'
                result['backup_deleted'] = False
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Backup exported to S3 Glacier successfully',
                    'backup_job_id': backup_job_id,
                    'recovery_point_arn': recovery_point_arn,
                    'export_result': result
                })
            }
            
        except Exception as e:
            print(f"Error exporting recovery point: {str(e)}")
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': f'Failed to export recovery point: {str(e)}'
                })
            }
            
    except Exception as e:
        print(f"Error handling backup completed event: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }


def handle_scheduled_cleanup(backup_vault_name):
    """
    정기 스케줄 실행: 7년 이상 된 백업 삭제
    """
    print(f"Running scheduled cleanup for vault: {backup_vault_name}")
    
    seven_years_ago = datetime.now(timezone.utc) - timedelta(days=SEVEN_YEARS_DAYS)
    
    # 백업 목록 조회
    recovery_points = list_recovery_points(backup_vault_name)
    
    # 7년 이상 된 백업 삭제
    old_backups_to_delete = filter_old_backups(recovery_points, seven_years_ago)
    print(f"Found {len(old_backups_to_delete)} recovery points older than 7 years to delete")
    
    delete_results = []
    for recovery_point in old_backups_to_delete:
        try:
            result = delete_recovery_point(recovery_point, backup_vault_name)
            delete_results.append(result)
        except Exception as e:
            print(f"Error deleting recovery point {recovery_point['RecoveryPointArn']}: {str(e)}")
            delete_results.append({
                'recovery_point_arn': recovery_point['RecoveryPointArn'],
                'status': 'error',
                'error': str(e)
            })
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': f'Cleanup completed: {len(delete_results)} deletions',
            'deletions': delete_results
        })
    }


def list_recovery_points(backup_vault_name):
    """
    Backup Vault에서 모든 Recovery Points 조회
    """
    recovery_points = []
    next_token = None
    
    while True:
        try:
            if next_token:
                response = backup_client.list_recovery_points_by_backup_vault(
                    BackupVaultName=backup_vault_name,
                    NextToken=next_token
                )
            else:
                response = backup_client.list_recovery_points_by_backup_vault(
                    BackupVaultName=backup_vault_name
                )
            
            recovery_points.extend(response.get('RecoveryPoints', []))
            
            next_token = response.get('NextToken')
            if not next_token:
                break
                
        except ClientError as e:
            print(f"Error listing recovery points: {str(e)}")
            raise
    
    return recovery_points


def filter_warm_backups_to_export(recovery_points, cutoff_date):
    """
    Warm storage 기간이 끝난 백업 필터링 (S3로 export 대상)
    """
    filtered = []
    
    for rp in recovery_points:
        # StorageClass 확인 (WARM_STORAGE 또는 빈 값)
        storage_class = rp.get('StorageClass', 'WARM_STORAGE')
        
        # CreationDate 확인
        creation_date_str = rp.get('CreationDate')
        if not creation_date_str:
            continue
        
        # 문자열을 datetime으로 변환
        if isinstance(creation_date_str, str):
            creation_date = datetime.fromisoformat(creation_date_str.replace('Z', '+00:00'))
        else:
            creation_date = creation_date_str
        
        # Warm storage 기간이 끝난 백업만 필터링 (WARM_STORAGE 또는 빈 값)
        if (storage_class in ['WARM_STORAGE', ''] and 
            creation_date < cutoff_date):
            filtered.append(rp)
            print(f"Found warm backup ready for export: {rp['RecoveryPointArn']}, "
                  f"Created: {creation_date}, StorageClass: {storage_class}")
    
    return filtered


def export_recovery_point_to_s3(recovery_point, backup_vault_name, aurora_cluster_id, s3_bucket_name):
    """
    Recovery Point를 S3로 export
    Recovery Point의 메타데이터에서 스냅샷 정보를 추출하고,
    해당 스냅샷을 S3로 export합니다.
    """
    recovery_point_arn = recovery_point['RecoveryPointArn']
    creation_date = recovery_point.get('CreationDate')
    
    print(f"Exporting recovery point {recovery_point_arn} to S3")
    
    try:
        # Recovery Point의 메타데이터 조회
        metadata = backup_client.get_recovery_point_restore_metadata(
            BackupVaultName=backup_vault_name,
            RecoveryPointArn=recovery_point_arn
        )
        
        # Aurora 스냅샷 찾기 (Recovery Point 생성 시간과 가장 가까운 스냅샷)
        if isinstance(creation_date, str):
            creation_dt = datetime.fromisoformat(creation_date.replace('Z', '+00:00'))
        else:
            creation_dt = creation_date
        
        # 클러스터 스냅샷 목록 조회
        snapshots = rds_client.describe_db_cluster_snapshots(
            DBClusterIdentifier=aurora_cluster_id,
            SnapshotType='automated'
        )
        
        # Recovery Point 생성 시간과 가장 가까운 스냅샷 찾기
        matching_snapshot = None
        min_time_diff = None
        
        for snapshot in snapshots.get('DBClusterSnapshots', []):
            snapshot_time = snapshot['SnapshotCreateTime']
            if snapshot_time.tzinfo is None:
                snapshot_time = snapshot_time.replace(tzinfo=timezone.utc)
            
            time_diff = abs((creation_dt - snapshot_time).total_seconds())
            if min_time_diff is None or time_diff < min_time_diff:
                min_time_diff = time_diff
                matching_snapshot = snapshot
        
        if not matching_snapshot:
            # 스냅샷을 찾을 수 없으면 수동 스냅샷 생성 필요
            print(f"Warning: No matching snapshot found for recovery point {recovery_point_arn}")
            return {
                'recovery_point_arn': recovery_point_arn,
                'status': 'skipped',
                'message': 'No matching snapshot found'
            }
        
        snapshot_arn = matching_snapshot['DBClusterSnapshotArn']
        snapshot_id = matching_snapshot['DBClusterSnapshotIdentifier']
        
        # S3 export 경로 생성
        export_prefix = f"aurora-backups/{aurora_cluster_id}/{creation_dt.strftime('%Y/%m/%d')}"
        export_id = f"{snapshot_id}-{int(creation_dt.timestamp())}"
        
        # IAM Role ARN (Lambda 환경 변수에서 가져오거나 하드코딩)
        # 실제로는 Terraform에서 export role ARN을 환경 변수로 전달해야 함
        export_role_arn = os.environ.get('AURORA_EXPORT_ROLE_ARN')
        if not export_role_arn:
            # Lambda 실행 역할에서 export role을 찾거나 생성해야 함
            print("Warning: AURORA_EXPORT_ROLE_ARN not set, skipping export")
            return {
                'recovery_point_arn': recovery_point_arn,
                'status': 'skipped',
                'message': 'Export role ARN not configured'
            }
        
        # Aurora 스냅샷을 S3로 export
        print(f"Starting export task for snapshot {snapshot_id} to s3://{s3_bucket_name}/{export_prefix}/")
        
        export_response = rds_client.start_export_task(
            ExportTaskIdentifier=export_id,
            SourceArn=snapshot_arn,
            S3BucketName=s3_bucket_name,
            IamRoleArn=export_role_arn,
            KmsKeyId=None,  # 기본 KMS 키 사용
            S3Prefix=export_prefix
        )
        
        export_task_arn = export_response['ExportTaskArn']
        
        print(f"Export task started: {export_task_arn}")
        
        # Recovery Point 삭제 (S3로 export 완료 후)
        # 실제로는 export 완료를 기다려야 하지만, 여기서는 즉시 삭제하지 않음
        # 별도의 Lambda나 Step Functions로 export 완료를 모니터링해야 함
        
        return {
            'recovery_point_arn': recovery_point_arn,
            'snapshot_id': snapshot_id,
            'export_task_arn': export_task_arn,
            's3_path': f"s3://{s3_bucket_name}/{export_prefix}/",
            'status': 'export_started'
        }
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == 'ExportTaskAlreadyExists':
            print(f"Export task already exists for recovery point {recovery_point_arn}")
            return {
                'recovery_point_arn': recovery_point_arn,
                'status': 'already_exported',
                'message': 'Export task already exists'
            }
        else:
            print(f"Error exporting recovery point: {str(e)}")
            raise


def filter_old_backups(recovery_points, cutoff_date):
    """
    7년 이상 된 모든 백업 필터링 (삭제 대상)
    """
    filtered = []
    
    for rp in recovery_points:
        creation_date_str = rp.get('CreationDate')
        if not creation_date_str:
            continue
        
        # 문자열을 datetime으로 변환
        if isinstance(creation_date_str, str):
            creation_date = datetime.fromisoformat(creation_date_str.replace('Z', '+00:00'))
        else:
            creation_date = creation_date_str
        
        # 7년 이상 된 백업 필터링
        if creation_date < cutoff_date:
            filtered.append(rp)
            print(f"Found old backup to delete: {rp['RecoveryPointArn']}, "
                  f"Created: {creation_date}, Age: {(datetime.now(timezone.utc) - creation_date).days} days")
    
    return filtered


def delete_recovery_point(recovery_point, backup_vault_name):
    """
    7년 이상 된 백업 삭제
    
    AWS Backup Recovery Point는 AWS Backup 서비스 내부에 저장되므로,
    AWS Backup에서만 삭제하면 됩니다.
    """
    recovery_point_arn = recovery_point['RecoveryPointArn']
    
    print(f"Deleting recovery point: {recovery_point_arn}")
    
    try:
        # AWS Backup에서 Recovery Point 삭제
        backup_client.delete_recovery_point(
            BackupVaultName=backup_vault_name,
            RecoveryPointArn=recovery_point_arn
        )
        
        print(f"Successfully deleted recovery point: {recovery_point_arn}")
        
        return {
            'recovery_point_arn': recovery_point_arn,
            'status': 'deleted'
        }
        
    except ClientError as e:
        if e.response['Error']['Code'] == 'InvalidRequestException':
            # 이미 삭제되었거나 삭제 불가능한 상태
            print(f"Recovery point cannot be deleted: {str(e)}")
            return {
                'recovery_point_arn': recovery_point_arn,
                'status': 'delete_failed',
                'error': str(e)
            }
        else:
            raise


def start_copy_job_to_s3(recovery_point_arn, backup_vault_name, destination_vault_name):
    """
    Recovery Point를 다른 Backup Vault로 복사
    주의: AWS Backup은 S3로 직접 복사 불가, 다른 Backup Vault로만 복사 가능
    """
    try:
        response = backup_client.start_copy_job(
            RecoveryPointArn=recovery_point_arn,
            SourceBackupVaultName=backup_vault_name,
            DestinationBackupVaultName=destination_vault_name
        )
        
        return response.get('CopyJobId')
    except ClientError as e:
        print(f"Error starting copy job: {str(e)}")
        raise

