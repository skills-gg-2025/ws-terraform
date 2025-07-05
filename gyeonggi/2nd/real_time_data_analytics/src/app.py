from flask import Flask, request
import logging

app = Flask(__name__)

logging.getLogger('werkzeug').disabled = True
logging.basicConfig(
    level=logging.DEBUG,
    format='[%(asctime)s] %(levelname)s %(message)s',
    handlers=[
        logging.StreamHandler()
    ],
    datefmt="%Y-%m-%dT%H:%M:%S"
)

@app.route("/info")
def log_info():
    app.logger.info(f'{request.method} {request.path} 200')
    return "Logged an INFO message.", 200

@app.route("/warn")
def log_warn():
    app.logger.warning(f'{request.method} {request.path} 200')
    return "Logged a WARNING message.", 200

@app.route("/error")
def log_error():
    app.logger.error(f'{request.method} {request.path} 200')
    return "Logged an ERROR message.", 200

@app.route('/health')
def healthcheck():
    return '', 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)