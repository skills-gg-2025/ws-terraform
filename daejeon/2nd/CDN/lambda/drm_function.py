def handler(event, context):
    request = event['Records'][0]['cf']['request']
    headers = request['headers']
    
    # Check for X-DRM-Token header
    drm_token = None
    if 'x-drm-token' in headers:
        drm_token = headers['x-drm-token'][0]['value']
    
    # Validate DRM token
    if drm_token != 'drm-cloud':
        return {
            'status': '403',
            'statusDescription': 'Forbidden',
            'headers': {
                'content-type': [{
                    'key': 'Content-Type',
                    'value': 'text/plain'
                }]
            },
            'body': 'Access Denied: Invalid DRM Token'
        }
    
    return request