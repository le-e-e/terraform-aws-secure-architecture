import boto3
import json
from datetime import datetime, timezone, timedelta
from botocore.exceptions import ClientError

# AWS 클라이언트 초기화
backup_client = boto3.client('backup')

import os

# 환경 변수에서 설정 읽기
BACKUP_VAULT_NAME = os.environ.get('BACKUP_VAULT_NAME')
ONE_YEAR_DAYS = 365  # 1년 = 365일
SEVEN_YEARS_DAYS = 2555  # 7년 = 2555일


def lambda_handler(event, context):
    """
    Aurora DB 백업 관리:
    1. 1년 이상 된 Glacier 백업을 Deep Archive로 전환
    2. 7년 이상 보관된 백업 삭제
    """
    try:
        # 환경 변수에서 설정 읽기 (우선순위: 환경 변수 > event)
        backup_vault_name = BACKUP_VAULT_NAME or event.get('backup_vault_name')
        
        if not backup_vault_name:
            error_msg = 'backup_vault_name is required. Set it as Lambda environment variable or in the event.'
            print(f"ERROR: {error_msg}")
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': error_msg
                })
            }
        
        print(f"Processing backups in vault: {backup_vault_name}")
        
        # 날짜 계산
        one_year_ago = datetime.now(timezone.utc) - timedelta(days=ONE_YEAR_DAYS)
        seven_years_ago = datetime.now(timezone.utc) - timedelta(days=SEVEN_YEARS_DAYS)
        
        # 백업 목록 조회
        recovery_points = list_recovery_points(backup_vault_name)
        
        # 1. 7년 이상 된 백업 삭제 (우선 처리)
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
        
        # 2. 1년 이상 된 Glacier 백업을 Deep Archive로 전환
        old_glacier_backups = filter_old_glacier_backups(recovery_points, one_year_ago)
        # 7년 이상 된 백업은 이미 삭제했으므로 제외
        old_glacier_backups = [
            rp for rp in old_glacier_backups 
            if rp not in old_backups_to_delete
        ]
        
        print(f"Found {len(old_glacier_backups)} recovery points older than 1 year in Glacier (excluding 7+ years)")
        
        archive_results = []
        for recovery_point in old_glacier_backups:
            try:
                result = process_backup_to_deep_archive(
                    recovery_point, 
                    backup_vault_name
                )
                archive_results.append(result)
            except Exception as e:
                print(f"Error processing recovery point {recovery_point['RecoveryPointArn']}: {str(e)}")
                archive_results.append({
                    'recovery_point_arn': recovery_point['RecoveryPointArn'],
                    'status': 'error',
                    'error': str(e)
                })
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Processed {len(delete_results)} deletions and {len(archive_results)} archive conversions',
                'deletions': delete_results,
                'archives': archive_results
            })
        }
        
    except Exception as e:
        print(f"Lambda execution error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
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


def filter_old_glacier_backups(recovery_points, cutoff_date):
    """
    1년 이상 된 Glacier 백업 필터링
    """
    filtered = []
    
    for rp in recovery_points:
        # StorageClass 확인 (GLACIER 또는 COLD_STORAGE)
        storage_class = rp.get('StorageClass', '')
        
        # CreationDate 확인
        creation_date_str = rp.get('CreationDate')
        if not creation_date_str:
            continue
        
        # 문자열을 datetime으로 변환
        if isinstance(creation_date_str, str):
            creation_date = datetime.fromisoformat(creation_date_str.replace('Z', '+00:00'))
        else:
            creation_date = creation_date_str
        
        # 1년 이상 된 Glacier 백업만 필터링
        if (storage_class in ['GLACIER', 'COLD_STORAGE'] and 
            creation_date < cutoff_date):
            filtered.append(rp)
            print(f"Found old Glacier backup: {rp['RecoveryPointArn']}, "
                  f"Created: {creation_date}, StorageClass: {storage_class}")
    
    return filtered


def process_backup_to_deep_archive(recovery_point, backup_vault_name):
    """
    1년 이상 된 Glacier 백업을 Deep Archive로 전환
    
    주의: AWS Backup의 Recovery Point는 AWS Backup 서비스 내부에 저장되며,
    lifecycle policy를 통해 자동으로 Glacier/Deep Archive로 전환됩니다.
    이 함수는 백업 상태를 확인하고 로그만 기록합니다.
    """
    recovery_point_arn = recovery_point['RecoveryPointArn']
    storage_class = recovery_point.get('StorageClass', '')
    
    print(f"Processing recovery point {recovery_point_arn} (StorageClass: {storage_class})")
    print("NOTE: AWS Backup uses its own storage. Deep Archive conversion is handled by lifecycle policies.")
    
    return {
        'recovery_point_arn': recovery_point_arn,
        'status': 'monitored',
        'storage_class': storage_class,
        'message': 'Backup lifecycle is managed by AWS Backup lifecycle policies'
    }


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

