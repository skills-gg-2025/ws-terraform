import boto3
import pandas as pd
from io import StringIO

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    dynamodb = boto3.resource('dynamodb')
    
    bucket_name = "ws-day2-workflow-108-s3"
    table = dynamodb.Table('Consumer_id')
    
    # Read result.csv from S3
    response = s3.get_object(Bucket=bucket_name, Key='result.csv')
    csv_content = response['Body'].read().decode('utf-8')
    
    # Load into DataFrame
    df = pd.read_csv(StringIO(csv_content))
    
    # Insert data into DynamoDB
    with table.batch_writer() as batch:
        for _, row in df.iterrows():
            item = {col: str(row[col]) for col in df.columns}
            batch.put_item(Item=item)
    
    return {
        'statusCode': 200,
        'message': f'Loaded {len(df)} records to DynamoDB'
    }