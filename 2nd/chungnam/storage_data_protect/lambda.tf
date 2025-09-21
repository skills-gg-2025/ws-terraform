resource "aws_iam_role" "lambda_role" {
  name = "wsc2025-lambda-masking-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "wsc2025-lambda-masking-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.sensitive_data.arn}/*"
      }
    ]
  })
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "lambda_function.zip"
  source {
    content = <<EOF
import json
import boto3
import re
from urllib.parse import unquote_plus

s3 = boto3.client('s3')

def lambda_handler(event, context):
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = unquote_plus(record['s3']['object']['key'])
        
        if not key.startswith('incoming/'):
            continue
            
        try:
            response = s3.get_object(Bucket=bucket, Key=key)
            content = response['Body'].read().decode('utf-8')
            
            # Mask sensitive data
            masked_content = mask_sensitive_data(content)
            
            # Save to masked/ prefix
            new_key = key.replace('incoming/', 'masked/')
            s3.put_object(
                Bucket=bucket, 
                Key=new_key, 
                Body=masked_content,
                ContentType='text/plain'
            )
            
            print(f"Successfully processed {key} -> {new_key}")
            
        except Exception as e:
            print(f"Error processing {key}: {str(e)}")
            import traceback
            traceback.print_exc()
    
    return {'statusCode': 200}

def mask_sensitive_data(content):
    lines = content.split('\n')
    masked_lines = []
    
    for line in lines:
        line = line.strip()
        if not line:
            continue
            
        # Names - mask last name only (keeping prefixes like Mr., Mrs., Dr.)
        if re.match(r'^[A-Za-z. ]+$', line) and len(line.split()) >= 2:
            parts = line.split()
            # 마지막 단어만 ***** 처리
            parts[-1] = "*****"
            masked_lines.append(" ".join(parts))
        
        # Emails - mask username part (davisjesus@example.org -> d*********@example.org)
        elif '@' in line:
            match = re.match(r'^([a-zA-Z])[^@]*(@.+)$', line)
            if match:
                masked_lines.append(f"{match.group(1)}*********{match.group(2)}")
            else:
                masked_lines.append(line)
        
        # Phone numbers - mask last 4 digits (010-7658-5153 -> 010-7658-****)
        elif re.match(r'^\d{3}-\d{4}-\d{4}$', line):
            masked_lines.append(re.sub(r'(\d{3}-\d{4}-)(\d{4})', r'\1****', line))
        
        # SSNs - mask last 4 digits (887-07-7325 -> 887-07-****)
        elif re.match(r'^\d{3}-\d{2}-\d{4}$', line):
            masked_lines.append(re.sub(r'(\d{3}-\d{2}-)(\d{4})', r'\1****', line))
        
        # Credit cards - mask last 4 digits (4468-6779-7028-4776 -> 4468-6779-7028-****)
        elif re.match(r'^\d{4}-\d{4}-\d{4}-\d{4}$', line):
            masked_lines.append(re.sub(r'(\d{4}-\d{4}-\d{4}-)(\d{4})', r'\1****', line))
        
        # UUIDs - mask last 12 characters
        elif re.match(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', line):
            masked_lines.append(re.sub(r'([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-)([0-9a-f]{12})', r'\1************', line))
        
        else:
            masked_lines.append(line)
    
    return '\n'.join(masked_lines)
EOF
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "masking_function" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "wsc2025-masking-start"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.masking_function.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.sensitive_data.arn
}
