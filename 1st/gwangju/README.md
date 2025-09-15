<h1 align="center">Deploying Gwangju 1st task</h1>

## A. 유의 사항
1. Host 환경에 Docker 설치가 필요하지 않으며, `src/day1_table.sql`을 이용한 테이블 삽입이 필요하지 않습니다.
2. remote-exec 작업에서 `i/o time out`오류 발생 시, 다시 한번 `terraform apply`를 이용하여 배포하면 됩니다.
3. 전체 재 배포가 필요한 경우, 모든 리소스를 삭제합니다.<br>모든 로그 그룹 및 `terraform init` 시 생성된 파일들은 <u>수동으로</u> 삭제 후, 재 배포해야 합니다.<br>RDS는 삭제 방지가 활성화 되어있어 잘 삭제되지 않으니 참고해야합니다.
4. 채점 시 KeyPair를 통해 접근할 것입니다. 채점 전 키페어의 권한이 적절한지 확인해야 합니다.

## B. EKS(K8S)
1. ⚠️ **반드시 배포 후** 고객 관리형 정책, `secretsmanager-policy`의 Resources Value를 `gj2025-eks-cluster-catalog-secret`의 ARN으로 설정해야 합니다. (8-2-A에서 감점될 수 있습니다)
2. 모든 구성이 끝난 후, `kubectl delete pods proxy-test` 명령을 통해 채점이 원활하게 진행될 수 있도록 합니다.

## C. GitHub
1. `gj2025-repository`를 생성합니다. `main` Branch가 필요하므로, README.md 등을 생성 시 추가하여 Branch가 쉽게 생성될 수 있도록 합니다.
2. `gj2025-github-token` Secret을 아래의 Json을 참고하여 생성합니다. <br />
`repo`, `workflow`, `read:org`, `admin:repo_hook` 권한을 연결해야합니다.
```
{
  "ServerType": "GitHub",
  "AccessToken": "ghp_xxxxxxxxxxxxx"
}
```
3. `GH CLI`를 별도로 설치합니다. 그런 다음 `gh auth login`을 통해 Token을 이용하여 로그인 합니다. (ec2-user)
4. ⚠️ **시작 전** CI/CD 관련 파일 중, `buildspec.yaml`과 `rollout.yaml`을 수정해야 합니다.<br>buildspec.yaml : 계정 ID 및 <username> 부분<br>rollouts.yaml : 계정 ID 부분
5. `/home/ec2-user/` 경로에 `gj2025-repository`를 Clone합니다.
6.  호스트에 `./src/auto.sh`가 존재합니다. 이 파일을 Bastion의 `/home/ec2-user` 로 복사하고, 실행하면 GitHub Setting이 자동으로 완료됩니다.


## D. CI
1. Docker 권한 승격 및 아래를 참고하여 CodeBuild에 환경변수를 설정합니다.
```
KEY : GITHUB_TOKEN
Value : gj2025-github-token:AccessToken
Type : Secrets Manager
```
2. CodeBuild에 github-token-arn을 연결합니다. `username`, `gj2025-github-token-arn`을 변경합니다.
```
aws codebuild update-project \
  --name gj2025-app-red-build \
  --source "type=GITHUB,location=https://github.com/username/gj2025-repository,auth={type=SECRETS_MANAGER,resource=gj2025-github-token-arn}"
```
```
aws codebuild update-project \
  --name gj2025-app-green-build \
  --source "type=GITHUB,location=https://github.com/username/gj2025-repository,auth={type=SECRETS_MANAGER,resource=gj2025-github-token-arn}"
```

## E. CD
- ArgoCD 콘솔에 NLB를 통해 접근하여 배포합니다.