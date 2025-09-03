<h1 align="center">Seoul 1ST • Solution Architecture</h1>

<h2 align="center"> ✅ Check list (After Deploy) </h2>

- Terraform 배포 시 3~11, 13 항목이 자동으로 생성되며, 12 항목도 쉬운 설정을 통해 구성 가능

- 비번호 지급 후 `variables.tf`에 본인 비번호 입력

- `rds.tf`, `src/build_and_push.sh`, `src/k8s/deploy.sh` 파일 시퀸스가 **CRLF**인 경우 이를 **LF**로 수정 필요

- ❗ 만약 문제 발생 후 모든 리소스를 지우고 재시도 시, 기존 Terraform 상태 파일 등(`terraform init`으로 생성되는 파일)을 재 생성하지 않으면 remote-exec이 정상적으로 작동하지 않을 가능성이 있음

- ❗ 만약 문제 발생 후 모든 리소스를 지우고 재시도 시, DB_URL이 저장된 Secret Manager를 삭제하지 않는다면 정상 배포 불가

<h3 align="center">RDS</h3>

- ❗ 자동으로 테이블이 생성되지 않기때문에 Bastion Host에 연결하여 직접 MySQL에 접근 후 `day1_table_v1.sql`source 필요

<h3 align="center">EKS</h3>

- ❗ 배포 중 `remote-exec provisioner` 에서 간혹 오류가 발생할 수 있으나, 발생 시 `terraform apply`를 한번 더 실행하면 해결 (마지막 테스트 : 정상)

- 대회 진행 계정이 Root가 아닌 IAM 사용자인 경우, Terraform 배포 후 콘솔 상에서는 **노드 없음** 이라고 표기되지만 실제로 배포된 상태이고 채점하는데 문제가 없으며, 필요시 IAM 액세스 항목에서 `arn:aws:iam::<계정 ID>:user/<계정명>` 에`AmazonEKSClusterAdminPolicy` 정책 부여 시 해결
 
- ❗ 채점은 root에서 실행되기 때문에 채점 전 root에서 EKS 클러스터 관련 환경변수 설정 및 Kubeconfig 업데이트 필요

<h3 align="center">CD Pipeline</h3>

- ❗ CD Part의 경우 ECR에 red 이미지 v1.0.1을 <u>채점 전</u> 업로드 하라고 되어있으며, v1.0.1은 미리 업로드 되기때문에 경기 종료 전 테스트 후 v1.0.1 이미지를 ECR에서 제거해야할 수 있음

<h3 align="center">ArgoCD</h3>

- manifast로 `k8s/green-deploy.yaml`, `k8s/red-deploy.yaml`, `k8s/green-svc.yaml`, `k8s/red-svc.yaml`, `k8s/green-ig.yaml`, `k8s/red-ig.yaml` 사용
- `k8s/green-deploy.yaml` 및 `k8s/red-deploy.yaml` 에서 이미지 태그 부분을 `v1.0.0` -> `v1.0.1`로 변경
- ArgoCD가 Bastion에 설치되어있어 포트포워딩(혹은 로드밸런싱) 및 인증 후 사용
- 문제지에 명시된대로 Github Repo 생성
- ArgoCD 콘솔 혹은 ArgoCD Application을 이용하여 배포(네임스페이스 등 변경 필요)
