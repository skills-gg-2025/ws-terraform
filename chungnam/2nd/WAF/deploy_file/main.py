from flask import Flask, request, jsonify
from utils.query_builder import obscure_query
import sqlite3
import os

app = Flask(__name__)
DB_FILE = "challenge.db"

def get_db():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    return conn

def init():
    if os.path.exists(DB_FILE):
        os.remove(DB_FILE)
    conn = get_db()
    cur = conn.cursor()
    cur.execute("CREATE TABLE secret_users (id INTEGER, name TEXT, secret TEXT)")
    cur.executemany("INSERT INTO secret_users VALUES (?, ?, ?)", [
        (1, 'admin', 'supersecret'),
        (2, 'alice', 'flag{alice_flag}'),
        (3, 'bob', 'flag{bob_flag}')
    ])
    conn.commit()

@app.route("/", methods=["GET"])
def index():
    return '''
    <h2>유저관리 시스템</h2>

    <form action="/login" method="get">
        <h4>로그인</h4>
        이름: <input type="text" name="name"><br>
        비밀번호: <input type="text" name="secret"><br>
        <input type="submit" value="로그인">
    </form><hr>

    <form action="/lookup" method="get">
        <h4>ID 조회</h4>
        ID: <input type="text" name="id">
        <input type="submit" value="조회">
    </form><hr>
    '''

@app.route("/login", methods=["GET"])
def login():
    name = request.args.get("name", "")
    passwd = request.args.get("secret", "")
    q = obscure_query("login", name=name, secret=passwd)
    conn = get_db()
    try:
        res = conn.execute(q).fetchone()
        if res:
            return f"✅ 환영합니다, {res['name']} 님!"
        else:
            return "❌ 로그인 실패"
    except Exception as e:
        return f"❗ 오류 발생: {str(e)}"

@app.route("/lookup", methods=["GET"])
def lookup():
    id = request.args.get("id", "")
    q = obscure_query("lookup", id=id)
    conn = get_db()
    try:
        res = conn.execute(q).fetchall()
        return jsonify([dict(row) for row in res])
    except Exception as e:
        return jsonify(error=str(e))

if __name__ == "__main__":
    init()
    app.run(host="0.0.0.0", port=5000, debug=True)