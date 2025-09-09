# 광주 1과제 배포
## 데이터베이스
1. 프록시 엔드포인트로 접속해 `src/day1_table_v1.sql`을 사용하여 테이블 생성

## Kubernetes
1. EKS연결 및 환경변수 설정
2. skills 네임스페이스를 생성합니다.
3. AWS Load Balancer Controller, External Secrets, ArgoCD, ArgoCD Rollouts, Fluent-bit(Daemonset)을설치합니다.
## App
1. deployment.yaml, service.yaml, ingress.yaml를 배포합니다.
2. app-vpc에 gj2025-app-internal-nlb를 생성합니다.
3. gj2025-app-internal-nlb에 대한 엔드포인트 서비스를 생성합니다.
4. 유형 : NLB 및 GWLB를 사용하는 엔드포인트 서비스 <br />서비스 이름: 3번에서 만들었던 서비스 <br />서브넷 : public subnet <br /> 보안그룹: nlb보안그룹 (80번 anywhere) <br />
위의 조건대로 엔드포인트 생성 후 gj2025-app-external-nlb를 생성합니다.

## Github
1. gj2025-repository를 생성합니다. 
2. gj2025-github-token이라는 secret manager를 아래의 json을 참고하여 생성합니다. <br />
repo, workflow, read:org, admin:repo_hook 권한을 연결해야합니다.
```
{
  "ServerType": "GitHub",
  "AccessToken": "ghp_xxxxxxxxxxxxx"
}
```
3. ec2-user권한으로 변경 후 `gh auth login`을 통해 깃허브 로그인을 합니다.
4. `/home/ec2-user/` 경로에 gj2025-repository를 클론합니다.
5. `app-green`, `app-red`, `gitops-green`, `gitops-red` 브랜치를 생성한 뒤 `src/argocd/green`, `src/argocd/red` 경로에 있는 파일들을 브랜치에 맞게 푸시합니다. 

## argocd
1. gj2025-argo-external-nlb를 생성합니다.
2. 아래의 명령어를 입력하여 비밀번호를 변경합니다.
```
kubectl -n argocd patch secret argocd-secret \
  --type merge \
  -p "$(echo -n '{"data":{"admin.password":"' ; htpasswd -nbBC 10 "" 'Skills53' | tr -d ':\n' | base64 -w0 ; echo '"}}')" \
&& kubectl -n argocd rollout restart deployment argocd-server
```
3. green, red 앱을 생성합니다.

## Codebuild, pipeline
1. 도커 권한 활성화 & Code build에 환경변수 <br />이름 : GITHUB_TOKEN <br />값 : gj2025-github-token:AccessToken <br />형식 : Secrets manager <br />
추가
2. codebuild에 github-token-arn을 연결합니다. `username`, `gj2025-github-token-arn`을 변경합니다.
```
aws codebuild update-project \
  --name gj2025-app-red-build \
  --source "type=GITHUB,location=https://github.com/username/gj2025-repository,auth={type=SECRETS_MANAGER,resource=gj2025-github-token-arn}"
```