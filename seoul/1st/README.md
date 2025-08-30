<h1 align="center">Seoul 1ND • Solution Architecture</h1>

<h2 align="center"> ✅ Check list (After Deploy) </h2>

- Terraform 배포 시 3~11, 13 항목이 자동으로 생성되며, 12 항목도 쉬운 설정을 통해 구성 가능

- 비번호 지급 후 `variables.tf`에 본인 비번호 입력

- `rds.tf`, `src/build_and_push.sh`, `src/k8s/deploy.sh` 파일 시퀸스가 **CRLF**인 경우 이를 **LF**로 수정 필요

<h3 align="center">EKS</h3>

- ❗ 배포 중 `remote-exec provisioner` 에서 간혹 오류가 발생할 수 있으나, 발생 시 `terraform apply`를 한번 더 실행하면 해결 (마지막 테스트 : 정상)

- 대회 진행 계정이 Root가 아닌 IAM 사용자인 경우, Terraform 배포 후 콘솔 상에서는 **노드 없음** 이라고 표기되지만 실제로 배포된 상태이고 채점하는데 문제가 없으며, 필요시 IAM 액세스 항목에서 `arn:aws:iam::<계정 ID>:user/<계정명>` 에`AmazonEKSClusterAdminPolicy` 정책 부여 시 해결
 - ❗`day1_table.sql`을 통해 자동으로 테이블이 생성되지 않기때문에 Bastion Host에 연결하여 직접 mysql에 접근 후 source 필요
- ❗ 채점은 root에서 실행되기 때문에 채점 전 root에서 EKS 클러스터 관련 환경변수 설정 및 Kubeconfig 업데이트 필요

<h3 align="center">CD Pipeline</h3>

- ❗ CD Part의 경우 ECR에 red 이미지 v1.0.1을 <u>채점 전</u> 업로드 하라고 되어있으며, v1.0.1은 미리 업로드 되기때문에 경기 종료 전 테스트 후 v1.0.1 이미지를 ECR에서 제거해야할 수 있음