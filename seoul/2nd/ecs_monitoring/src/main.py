from flask import Flask
import time

app = Flask(__name__)

@app.route('/')
def index():
    return "Hello from ECS with CloudWatch Logging!"

@app.route('/cpu')
def cpu_stress():
    end_time = time.time() + 60
    while time.time() < end_time:
        _ = 123456 ** 123456
    return "CPU stress done."

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)