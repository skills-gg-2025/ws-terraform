import boto3
import pandas as pd
import base64
from io import StringIO

def lambda_handler(event, context):
    s3 = boto3.client('s3')
    bucket_name = "ws-day2-workflow-108-s3"
    
    # Read creditcard.csv from S3
    response = s3.get_object(Bucket=bucket_name, Key='creditcard.csv')
    csv_content = response['Body'].read().decode('utf-8')
    
    # Load into DataFrame
    df = pd.read_csv(StringIO(csv_content))
    
    # Sort A-Z by all columns
    df = df.sort_values(by=list(df.columns))
    
    # Create id column by base64 encoding full_name
    df['id'] = df['full_name'].apply(lambda x: base64.b64encode(x.encode()).decode())
    
    # Convert to CSV
    result_csv = df.to_csv(index=False)
    
    # Upload result.csv to S3
    s3.put_object(Bucket=bucket_name, Key='result.csv', Body=result_csv)
    
    return {
        'statusCode': 200,
        'bucket_name': bucket_name
    }