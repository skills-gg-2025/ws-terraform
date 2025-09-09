# AWS WAF를 이용한 XXE 공격 방어 시스템

## 개요
이 프로젝트는 AWS WAF를 사용하여 XXE(XML External Entity) 공격을 방어하는 시스템을 구성합니다.

## 아키텍처
- **EC2 Instance**: xxe-server (t3.micro)
- **Application Load Balancer**: xxe-alb
- **AWS WAF**: XXE 공격 패턴 차단
- **Region**: us-west-1
- **VPC**: Default VPC 사용

## WAF 방어 규칙

### 1. XXE 공격 차단 규칙
다음 패턴들을 감지하여 차단:
- `<!ENTITY` - XML 외부 엔티티 선언
- `<!DOCTYPE` - DTD 선언
- `file://` - 로컬 파일 접근 시도
- `http://169.254.169.254` - AWS 메타데이터 서비스 접근 시도

### 2. Rate Limiting 규칙
- IP당 분당 100회 요청 제한
- DoS 공격 방어

## 배포 방법

```bash
# Terraform 초기화
terraform init

# 계획 확인
terraform plan

# 배포 실행
terraform apply
```

## 테스트 방법

### 정상 요청 테스트
```bash
curl -X POST http://<ALB_DNS_NAME>/parse \
  -d "xml=<note><msg>Hello World</msg></note>"
```

### XXE 공격 테스트 (차단되어야 함)

#### 1. 로컬 파일 읽기 시도
```bash
curl -X POST http://<ALB_DNS_NAME>/parse \
  -d 'xml=<?xml version="1.0"?><!DOCTYPE root [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><root>&xxe;</root>'
```

#### 2. SSRF 공격 시도
```bash
curl -X POST http://<ALB_DNS_NAME>/parse \
  -d 'xml=<?xml version="1.0"?><!DOCTYPE root [<!ENTITY xxe SYSTEM "http://169.254.169.254/latest/meta-data/">]><root>&xxe;</root>'
```

#### 3. Billion Laughs 공격 시도
```bash
curl -X POST http://<ALB_DNS_NAME>/parse \
  -d 'xml=<?xml version="1.0"?><!DOCTYPE lolz [<!ENTITY lol "lol"><!ENTITY lol2 "&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;&lol;">]><lolz>&lol2;</lolz>'
```

## 모니터링
- CloudWatch에서 WAF 메트릭 확인
- 차단된 요청 수 모니터링
- Rate limiting 적용 현황 확인

## 정리
```bash
terraform destroy
```