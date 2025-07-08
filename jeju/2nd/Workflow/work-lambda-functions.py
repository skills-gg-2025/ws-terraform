import boto3
import os
import csv
import json
import io
from datetime import datetime, timezone, timedelta

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

APPLICATION_EXTENSIONS = ['.py', '.json', '.go']
DATA_EXTENSION = '.csv'
PNG_EXTENSION = '.png'

APPLICATION_TABLE = 'application-table'
DATA_TABLE = 'data-table'

def lambda_handler(event, context):
    print(f"Received event: {json.dumps(event)}")
    
    if 'Records' not in event:
        print("Invalid event: 'Records' key not found")
        return {"statusCode": 400, "body": "Invalid event structure"}

    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        filename = key.split('/')[-1]
        extension = os.path.splitext(filename)[1].lower()

        KST = timezone(timedelta(hours=9))
        now_kst = datetime.now(KST)
        upload_time = now_kst.strftime("%Y-%m/%d-%M/%S")

        if extension in APPLICATION_EXTENSIONS:
            insert_to_dynamodb(APPLICATION_TABLE, extension, filename, upload_time)

        elif extension == DATA_EXTENSION:
            try:
                obj = s3.get_object(Bucket=bucket, Key=key)
                content = obj['Body'].read().decode('utf-8')
                csv_reader = csv.DictReader(io.StringIO(content))

                required_fields = {'id', 'name', 'age', 'birthday', 'gender'}

                # CSV 파일의 기본 정보를 data-table에 저장
                insert_to_dynamodb(DATA_TABLE, extension, filename, upload_time)
                
                # CSV 내용 처리 - 각 행을 하나의 아이템으로 저장
                for idx, row in enumerate(csv_reader):
                    row_keys = set(row.keys())
                    
                    # 필수 필드 확인
                    if not required_fields.issubset(row_keys):
                        print(f"[Row {idx}] Missing required fields: {required_fields - row_keys}. Skipping.")
                        continue

                    # 주요 필드와 추가 필드 분리
                    main_data = {k: row[k] for k in required_fields}
                    extra_fields = {k: row[k] for k in row_keys - required_fields}

                    # 하나의 아이템으로 저장 (주요 필드 + extra 필드)
                    item = {
                        'file-type': extension,
                        'file-name': f"{filename}-row-{idx}",
                        'upload-time': upload_time,
                        'id': main_data['id'],
                        'name': main_data['name'],
                        'age': main_data['age'],
                        'birthday': main_data['birthday'],
                        'gender': main_data['gender']
                    }

                    # extra 필드가 있으면 추가
                    if extra_fields:
                        item['extra'] = json.dumps(extra_fields)
                    
                    table = dynamodb.Table(DATA_TABLE)
                    table.put_item(Item=item)
                    print(f"[Row {idx}] Data inserted to {DATA_TABLE}: {item}")
            except Exception as e:
                print(f"CSV 처리 중 오류 발생: {str(e)}")

        elif extension == PNG_EXTENSION:
            s3.delete_object(Bucket=bucket, Key=key)
            print(f"Deleted PNG file: {key}")
        
        else:
            print(f"Ignored file type: {filename}")

def insert_to_dynamodb(table_name, file_type, file_name, upload_time):
    table = dynamodb.Table(table_name)
    item = {
        'file-type': file_type,
        'file-name': file_name,
        'upload-time': upload_time
    }
    table.put_item(Item=item)
    print(f"Inserted to {table_name}: {item}")
