{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:ap-northeast-2:${account_id}:secret:rds!db-*",
        "arn:aws:secretsmanager:ap-northeast-2:${account_id}:secret:wsk-db-url-*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Resource": "${kms_key_arn}"
    }
  ]
}