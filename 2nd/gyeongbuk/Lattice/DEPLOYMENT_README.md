# VPC Lattice Infrastructure with Terraform

이 프로젝트는 AWS VPC Lattice를 사용하여 두 개의 분리된 VPC 간 통신을 구현하는 고가용성 웹 애플리케이션 인프라를 구축합니다.

## 아키텍처 개요

### 네트워크 구성
- **Consumer VPC**: 172.168.0.0/16 (외부 트래픽 수신)
- **Service VPC**: 10.0.0.0/16 (애플리케이션 로직 처리)
- **VPC Lattice**: 두 VPC 간 안전한 통신 채널

### 주요 구성 요소
1. **Bastion Host**: 관리 및 SSH 접속용 (고정 IP)
2. **Consumer Server**: 외부 요청을 받아 VPC Lattice로 전달
3. **App Server**: DynamoDB와 연동하여 비즈니스 로직 처리
4. **DynamoDB**: 사용자 데이터 저장 (PAY_PER_REQUEST, PITR 활성화)
5. **Application Load Balancers**: 고가용성 로드 밸런싱

## 파일 구조

```
├── providers.tf           # Terraform 및 AWS 프로바이더 설정
├── vpc.tf                 # VPC, 서브넷, 라우팅 테이블 구성
├── bastion.tf             # Bastion 호스트 및 보안 그룹
├── lattice.tf             # VPC Lattice 서비스 및 네트워크
├── alb.tf                 # Application Load Balancers
├── asg.tf                 # Auto Scaling Groups 및 Launch Templates
├── dynamodb.tf            # DynamoDB 테이블 및 IAM 역할
├── outputs.tf             # Terraform 출력값
└── src/
    ├── app.py             # FastAPI 애플리케이션 코드
    ├── requirements.txt   # Python 의존성
    ├── bastion_key        # SSH 프라이빗 키
    ├── bastion_key.pub    # SSH 퍼블릭 키
    ├── consumer_userdata.sh # Consumer 서버 부트스트랩
    └── service_userdata.sh  # Service 서버 부트스트랩
```

## 배포 방법

### 1. 사전 요구사항
- Terraform >= 1.0
- AWS CLI 설정 완료
- 적절한 AWS IAM 권한

### 2. 초기화 및 배포
```bash
# Terraform 초기화
terraform init

# 계획 확인
terraform plan

# 인프라 배포
terraform apply
```

### 3. 주요 출력값
배포 완료 후 다음 정보들이 출력됩니다:
- Consumer ALB DNS 이름
- Bastion Host 공개 IP
- VPC Lattice 서비스 ID
- DynamoDB 테이블 이름

## 애플리케이션 API

### Consumer 서비스 (외부 접근)
- **GET** `/` - 서비스 정보
- **GET** `/health` - 헬스 체크
- **GET** `/users` - 사용자 목록 조회
- **GET** `/users/{user_id}` - 특정 사용자 조회
- **POST** `/users` - 사용자 생성
- **PUT** `/users/{user_id}` - 사용자 수정
- **DELETE** `/users/{user_id}` - 사용자 삭제

### App 서비스 (내부 - VPC Lattice를 통해 접근)
- DynamoDB와 직접 연동하여 CRUD 작업 수행
- Consumer 서비스의 요청을 VPC Lattice를 통해 처리

## 보안 구성

### Security Groups
- **Bastion**: SSH(22) 포트만 허용
- **Consumer ALB**: HTTP(80), HTTPS(443) 허용
- **Consumer Server**: ALB와 Bastion에서만 접근 허용
- **Service ALB**: VPC Lattice 트래픽만 허용
- **App Server**: Service ALB와 Bastion에서만 접근 허용

### IAM 역할
- **Bastion Role**: EC2, DynamoDB, ELB, VPC Lattice 조회 권한
- **EC2 DynamoDB Role**: DynamoDB 테이블 CRUD 권한

## 고가용성 설계

### Multi-AZ 배포
- 각 VPC는 2개의 가용영역(AZ)에 걸쳐 구성
- Public/Private 서브넷 각각 2개씩 생성
- NAT Gateway 각 AZ별로 배치

### Auto Scaling
- Consumer 서버: 최소 2개, 최대 6개 인스턴스
- App 서버: 최소 2개, 최대 6개 인스턴스
- ELB 헬스 체크 기반 자동 스케일링

### 데이터베이스
- DynamoDB PAY_PER_REQUEST 모드로 자동 스케일링
- Point-in-Time Recovery(PITR) 활성화
- 삭제 방지 설정

## 모니터링 및 로그

### 헬스 체크
- ALB 레벨: `/health` 엔드포인트 모니터링
- VPC Lattice 레벨: 타겟 그룹 헬스 체크

### 애플리케이션 로그
- 각 서버의 systemd 서비스로 관리
- `/var/log/` 디렉토리에서 로그 확인 가능

## 비용 최적화

- t3.micro 인스턴스 사용 (프리티어 적용 가능)
- DynamoDB PAY_PER_REQUEST 모드
- 불필요한 NAT Gateway 트래픽 최소화

## 확장 방안

1. **보안 강화**: WAF, Shield 추가
2. **성능 최적화**: CloudFront CDN 연동
3. **모니터링**: CloudWatch 대시보드 및 알람
4. **백업**: 자동화된 백업 스케줄
5. **CI/CD**: CodePipeline을 통한 자동 배포

## 트러블슈팅

### 일반적인 문제
1. **VPC Lattice 연결 실패**: 보안 그룹 및 라우팅 테이블 확인
2. **DynamoDB 권한 오류**: IAM 역할 및 정책 검토
3. **ALB 헬스 체크 실패**: 애플리케이션 상태 및 포트 확인

### 로그 확인
```bash
# Consumer 서비스 로그
sudo journalctl -u consumer-app -f

# App 서비스 로그
sudo journalctl -u app-server -f
```

## 정리

인프라를 삭제하려면:
```bash
terraform destroy
```

⚠️ **주의**: 이 명령은 모든 리소스를 삭제하며, DynamoDB 테이블의 데이터도 함께 삭제됩니다.
