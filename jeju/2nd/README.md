# Terraform AWS 파일 처리 워크플로우

## 개요
이 Terraform 구성은 AWS에서 파일 처리 워크플로우를 구축합니다.

## 구성 요소

### S3 버킷
- 이름: `save-file-s3-bucket-<4자리숫자>-<선수번호>`
- KMS 암호화 적용
- 외부 접근 차단
- `file/` 디렉토리 생성

### DynamoDB 테이블
1. **application-table**: py, json, go 파일 정보 저장
2. **data-table**: csv 파일 정보 저장

### Lambda 함수
- 이름: `work-lambda-functions`
- 런타임: Python 3.9
- S3 파일 업로드 시 자동 실행

### Step Functions
- 이름: `step-workflow`
- Lambda 함수 호출 워크플로우

## 배포 방법

1. AWS CLI 설정 확인
2. `deploy.bat` 실행 (4자리 숫자와 선수 번호 입력)
3. 또는 수동으로:
   ```
   # terraform.tfvars 파일 생성
   bucket_random_number = "1234"
   player_number = "01"
   
   terraform init
   terraform plan
   terraform apply
   ```

## 파일 처리 규칙

- **py, json, go**: application-table에 저장
- **csv**: data-table에 저장 (id, name, age, birthday, gender 필드 처리)
- **png**: 자동 삭제
- **기타**: 무시

## 시간 형식
업로드 시간은 한국 시간 기준으로 `YYYY-MM/DD-MM/SS` 형식으로 저장됩니다.