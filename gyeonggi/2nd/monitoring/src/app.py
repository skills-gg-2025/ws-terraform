from flask import Flask, request, jsonify, render_template_string
import random

app = Flask(__name__)

@app.route('/')
def home():
    name = request.args.get('name', 'guest')
    user_agent = request.headers.get('User-Agent', '').lower()

    if 'curl' in user_agent:
        return jsonify(name=name, status="OK")
    
    return render_template_string(f"""
        <p>Hello, {name}!</p>
    """)

@app.route('/healthz')
def healthcheck():
    return jsonify(app="monitoring", status="OK"), 200

@app.route('/test')
def random_response():
    responses = [
        (jsonify(message="Status OK!"), 200),
        (jsonify(error="400 Bad Request"), 400),
        (jsonify(error="Internal Server Error"), 500)
    ]
    response, status_code = random.choice(responses)
    return response, status_code

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)