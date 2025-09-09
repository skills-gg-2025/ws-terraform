import json
import boto3

def lambda_handler(event, context):
    """
    Lambda function for CloudFront invalidation (Korea region)
    """
    
    cloudfront = boto3.client('cloudfront')
    
    try:
        # Create invalidation
        response = cloudfront.create_invalidation(
            DistributionId=event.get('distribution_id'),
            InvalidationBatch={
                'Paths': {
                    'Quantity': len(event.get('paths', ['/*'])),
                    'Items': event.get('paths', ['/*'])
                },
                'CallerReference': context.aws_request_id
            }
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Invalidation created successfully',
                'invalidation_id': response['Invalidation']['Id']
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
