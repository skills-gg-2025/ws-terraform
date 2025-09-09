from flask import Flask, request, jsonify, abort
from datetime import datetime, timezone
import boto3

dynamodb = boto3.client('dynamodb', region_name='ap-northeast-2')
TABLE_NAME = "account-table"

app = Flask(__name__)

@app.route('/create_account', methods=['POST'])
def create_account():
    data = request.json
    account_id = data.get("account_id")
    balance = data.get("balance")
    currency = data.get("currency", "USD")

    now = datetime.now(timezone.utc).isoformat()

    try:
        dynamodb.put_item(
            TableName=TABLE_NAME,
            Item={
                'account_id': {'S': account_id},
                'balance': {'N': str(balance)},
                'currency': {'S': currency},
                'last_updated': {'S': now}
            },
            ConditionExpression='attribute_not_exists(account_id)'
        )
        return jsonify({"message": f"Account {account_id} created."}), 201
    except dynamodb.exceptions.ConditionalCheckFailedException:
        return jsonify({"error": f"Account {account_id} already exists."}), 400
    except Exception as e:
        app.logger.error(e)
        abort(500)

@app.route('/transfer', methods=['POST'])
def transfer():
    data = request.json
    from_account = data.get("from_account")
    to_account = data.get("to_account")
    amount = data.get("amount")

    now = datetime.now(timezone.utc).isoformat()

    try:
        dynamodb.transact_write_items(
            TransactItems=[
                {
                    'Update': {
                        'TableName': TABLE_NAME,
                        'Key': {'account_id': {'S': from_account}},
                        'UpdateExpression': 'SET balance = balance - :amt, last_updated = :ts',
                        'ConditionExpression': 'balance >= :amt',
                        'ExpressionAttributeValues': {
                            ':amt': {'N': str(amount)},
                            ':ts': {'S': now}
                        }
                    }
                },
                {
                    'Update': {
                        'TableName': TABLE_NAME,
                        'Key': {'account_id': {'S': to_account}},
                        'UpdateExpression': 'SET balance = balance + :amt, last_updated = :ts',
                        'ExpressionAttributeValues': {
                            ':amt': {'N': str(amount)},
                            ':ts': {'S': now}
                        }
                    }
                }
            ]
        )
        return jsonify({"message": "Transfer successful."}), 200
    except dynamodb.exceptions.TransactionCanceledException as e:
        return jsonify({
            "error": "Transaction failed. Possible insufficient balance or condition failed.",
            "details": str(e)
        }), 400
    except Exception as e:
        app.logger.error(e)
        abort(500)

@app.route('/healthcheck', methods=['GET'])
def healthcheck():
    try:
        return jsonify({"status": "ok"}), 200
    except Exception as e:
        app.logger.error(e)
        abort(500)

if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0', port=8080)
