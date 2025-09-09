function handler(event) {
    var request = event.request;
    var headers = request.headers;
    
    // Get country code from CloudFront headers
    var countryCode = headers['cloudfront-viewer-country'] ? headers['cloudfront-viewer-country'].value : 'UNKNOWN';
    
    // Get user-agent
    var userAgent = headers['user-agent'] ? headers['user-agent'].value.toLowerCase() : '';
    
    // Check for allowed countries (KR, US)
    var allowedCountries = ['KR', 'US'];
    if (!allowedCountries.includes(countryCode)) {
        return {
            statusCode: 403,
            statusDescription: 'Forbidden',
            body: 'Access denied: unsupported country'
        };
    }
    
    // Check for suspicious user-agents
    var suspiciousUserAgents = ['bot', 'crawler', 'spider'];
    for (var i = 0; i < suspiciousUserAgents.length; i++) {
        if (userAgent.includes(suspiciousUserAgents[i])) {
            return {
                statusCode: 403,
                statusDescription: 'Forbidden',
                body: 'Request blocked due to suspicious User-Agent'
            };
        }
    }
    
    // Allow the request
    return request;
}
