# service-a
from flask import Flask, jsonify
import requests

app = Flask(__name__)

# 환경 변수에서 서비스 B의 URL을 가져옵니다.
import os
LATTICE_SERVICE_B_URL = os.environ.get('LATTICE_SERVICE_B_URL', 'http://localhost/api')

@app.route("/hello")
def hello():
    try:
        res = requests.get(LATTICE_SERVICE_B_URL, timeout=2)
        return res.text, res.status_code
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
