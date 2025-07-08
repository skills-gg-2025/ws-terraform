function handler(event) {
    var request = event.request;
    var querystring = request.querystring;
    
    // Extract DRM token from query string
    if (querystring.token && querystring.token.value) {
        // Add X-DRM-Token header
        request.headers['x-drm-token'] = {
            value: querystring.token.value
        };
        
        // Remove token from query string to clean URL
        delete querystring.token;
    }
    
    return request;
}