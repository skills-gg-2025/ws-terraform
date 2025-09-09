# ECS FireLens 배포 가이드

이 프로젝트는 AWS ECS에서 FireLens를 활용한 로그 수집 시스템을 구성합니다.

## 배포 순서

1. **Terraform 초기화 및 배포**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

2. **Docker 이미지 빌드 및 ECR 푸시**
   ```bash
   cd src
   ./build_and_push.sh
   ```

3. **ECS 서비스 업데이트**
   - 이미지 푸시 후 ECS 서비스가 자동으로 새 태스크 정의를 사용하여 업데이트됩니다.

## 주요 구성 요소

- **VPC**: 10.1.0.0/16 CIDR 블록
- **서브넷**: Public/Private 서브넷 각각 2개씩
- **Bastion**: Public 서브넷의 관리용 EC2 인스턴스
- **ALB**: Public 서브넷의 로드 밸런서
- **ECS**: Private 서브넷의 Fargate 서비스
- **ECR**: 컨테이너 이미지 저장소
- **CloudWatch**: 로그 수집 및 모니터링

## 접속 정보

배포 완료 후 다음 정보를 확인할 수 있습니다:
- Bastion Server IP
- ALB DNS Name
- ECR Repository URLs

## 로그 확인

CloudWatch Logs에서 `/skills/app` 로그 그룹을 통해 구조화된 JSON 로그를 확인할 수 있습니다.

## 정리

```bash
terraform destroy
```
