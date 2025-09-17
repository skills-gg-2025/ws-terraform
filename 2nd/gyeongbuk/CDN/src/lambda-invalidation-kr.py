import json
import boto3
import os
import urllib.parse

def lambda_handler(event, context):
    """
    Lambda function for CloudFront invalidation (Korea region)
    Triggered by S3 events to invalidate CloudFront cache
    """
    
    cloudfront = boto3.client('cloudfront')
    distribution_id = os.environ.get('CLOUDFRONT_DISTRIBUTION_ID')
    
    try:
        # Handle S3 event
        if 'Records' in event:
            paths = []
            for record in event['Records']:
                if record['eventSource'] == 'aws:s3':
                    bucket = record['s3']['bucket']['name']
                    key = urllib.parse.unquote_plus(record['s3']['object']['key'])
                    paths.append(f'/{key}')
            
            if not paths:
                return {
                    'statusCode': 200,
                    'body': json.dumps({'message': 'No paths to invalidate'})
                }
        else:
            # Handle direct invocation
            paths = event.get('paths', ['/*'])
            distribution_id = event.get('distribution_id', distribution_id)
        
        if not distribution_id:
            raise ValueError('Distribution ID not provided')
        
        # Create invalidation
        response = cloudfront.create_invalidation(
            DistributionId=distribution_id,
            InvalidationBatch={
                'Paths': {
                    'Quantity': len(paths),
                    'Items': paths
                },
                'CallerReference': context.aws_request_id
            }
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Invalidation created successfully',
                'invalidation_id': response['Invalidation']['Id'],
                'paths': paths
            })
        }
        
    except Exception as e:
        print(f'Error: {str(e)}')
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
