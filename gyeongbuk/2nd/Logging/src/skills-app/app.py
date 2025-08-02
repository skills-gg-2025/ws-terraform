import sys
import logging
from datetime import datetime
from flask import Flask, request

app = Flask(__name__)

# Configure logging to stdout for container environment
logging.basicConfig(
    level=logging.INFO,
    format='%(message)s',
    stream=sys.stdout
)

logger = logging.getLogger(__name__)

@app.after_request
def log_request(response):
    # Create log entry in format expected by Fluent Bit parser
    client_ip = request.environ.get('HTTP_X_FORWARDED_FOR', request.environ.get('REMOTE_ADDR', '172.17.0.1'))
    timestamp = datetime.now().strftime('%d/%b/%Y %H:%M:%S')
    method = request.method
    path = request.path
    status_code = response.status_code
    
    log_message = f'{client_ip} - - [{timestamp}] "{method} {path} HTTP/1.1" {status_code} -'
    logger.info(log_message)
    
    return response

@app.route('/check')
def check():
    return {"data": "hello"}

@app.route('/health')
def health():
    return {"status": "ok"}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)