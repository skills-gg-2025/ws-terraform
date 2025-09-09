from flask import Flask, request, Response
import logging
import time
import socket
from datetime import datetime
import random
import string
import sys

app = Flask(__name__)

server_ip = socket.gethostbyname(socket.gethostname())

log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)

access_logger = logging.getLogger("access_logger")
access_logger.setLevel(logging.INFO)
stream_handler = logging.StreamHandler(sys.stdout)
stream_handler.setFormatter(logging.Formatter('%(message)s'))
access_logger.addHandler(stream_handler)

@app.before_request
def start_timer():
    request.start_time = time.time()

@app.after_request
def log_request(response: Response):
    now = datetime.now().strftime('%Y/%m/%d %H:%M:%S')
    src_ip = request.remote_addr or '-'
    dst_ip = server_ip
    method = request.method
    path = request.path
    status = response.status_code
    send_size = len(response.get_data())
    recv_size = request.content_length or 0
    duration = time.time() - request.start_time

    log_line = f"{now} {src_ip} {dst_ip} {method} {path} {status} {send_size} {recv_size} {duration:.4f}s"
    access_logger.info(log_line)

    return response

@app.route('/hello', methods=['GET'])
def get_all_instances():
    random_str = ""
    for i in range(100):
        random_str += str(random.choice(string.ascii_letters))

    return {"msg": "Hello Worldskills", "random": random_str}, 200

@app.route('/healthcheck', methods=['GET'])
def healthcheck():
    return "OK", 200

latency_records = []

@app.route('/test_latency', methods=['GET'])
def test_latency():
    delay = random.uniform(0.01, 1.0)
    time.sleep(delay)

    latency_records.append(delay)

    return {"message": "Latency test completed", "delay_sec": round(delay, 4)}, 200

@app.route('/latency_stats', methods=['GET'])
def latency_stats():
    if not latency_records:
        return {"error": "No latency data available."}, 400

    sorted_latencies = sorted(latency_records)
    count = len(sorted_latencies)

    def get_percentile(p):
        k = int(round(p * count + 0.5)) - 1
        k = max(0, min(k, count - 1))
        return sorted_latencies[k]

    stats = {
        "count": count,
        "min": round(min(sorted_latencies), 4),
        "max": round(max(sorted_latencies), 4),
        "avg": round(sum(sorted_latencies) / count, 4),
        "p90": round(get_percentile(0.90), 4),
        "p95": round(get_percentile(0.95), 4),
        "p99": round(get_percentile(0.99), 4)
    }

    return stats, 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)