# EKS CI/CD Pipeline 배포 가이드
## 1. GitHub Repository 설정

### Repository 생성
1. values/dev.values.yaml과 values/prod.values.yaml에서 image.repository와 image.tag 업데이트
2. GitHub에서 `day2-product` 이름의 Public Repository 생성
3. 다음 파일들을 Repository에 업로드:
  - `src/app.py`
  - `src/requirements.txt`
  - `src/Dockerfile`
  - `src/charts/` 디렉토리 전체
  - `src/values/` 디렉토리 전체
  - `.github/workflows/dev.yml`
  - `.github/workflows/prod.yml`

### Branches 생성
1. `dev` 브랜치 생성 (기본 브랜치)
2. `prod` 브랜치 생성

### Secrets 설정
1. Repository Settings > Secrets and variables > Actions
2. 다음 Secret 추가:
  - `AWS_ROLE_ARN`: Terraform output에서 나온 github_actions_role_arn 값
  - `ARGOCD_SERVER`: http://{BASTION_IPv4}:8080
  - `ARGOCD_USERNAME`: admin
  - `ARGOCD_PASSWORD`: {PASSWORD}

### Labels 생성
1. Repository Issues > Labels
2. `approval` 라벨 생성

### Github Pages
1. Repository Settings > Pages
2. Source: `prod` 브랜치, `/ (root)` 선택
3. Save 클릭

## 2. CLI 환경 설정

### Bastion 호스트 접속
```bash
ssh -i src/bastion-key ec2-user@<BASTION_PUBLIC_IP>
```

### Github CLI 로그인
```bash
gh auth login
```

### 클러스터 연결 확인
```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
kubectl get nodes --context=arn:aws:eks:eu-central-1:$AWS_ACCOUNT_ID:cluster/dev-cluster
kubectl get nodes --context=arn:aws:eks:eu-central-1:$AWS_ACCOUNT_ID:cluster/prod-cluster
kubectx arn:aws:eks:eu-central-1:$AWS_ACCOUNT_ID:cluster/dev-cluster
```

## 3. ArgoCD 설치
``` yaml
configs:
  cm:
    timeout.reconciliation: 30s
  params:
    server.insecure: true
```
``` bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update argo

helm install argocd argo/argo-cd \
    --create-namespace \
    --namespace argocd \
    --values values.yaml
helm install rollouts argo/argo-rollouts -n argocd

kubectx arn:aws:eks:eu-central-1:$AWS_ACCOUNT_ID:cluster/prod-cluster
helm install rollouts argo/argo-rollouts -n argocd --create-namespace
```

## 4. Actions Runner Controller 설치
### Dev, Prod 클러스터 모두 설치
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.2/cert-manager.yaml
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm upgrade --install --namespace actions-runner-system --create-namespace --set=authSecret.create=true --set=authSecret.github_token="REPLACE_YOUR_TOKEN_HERE" --wait actions-runner-controller actions-runner-controller/actions-runner-controller
```

### Runner 배포
```bash
# src/k8s/github-runners.yaml 파일을 수정하여 YOUR_USERNAME을 실제 GitHub 사용자명으로 변경
# dev-cluster - dev-runner, prod-cluster - prod-runner
kubectl create namespace app
kubectl apply -f github-runners.yaml
```

## 5. AWS Load Balancer Controller 설치
``` bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.13.4/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

eksctl create iamserviceaccount \
  --cluster=dev-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole-dev \
  --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

eksctl create iamserviceaccount \
  --cluster=prod-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole-prod \
  --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=dev-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=eu-central-1 \
  --set vpcId=<dev-vpc-id>

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=prod-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=eu-central-1 \
  --set vpcId=<prod-vpc-id>
```

## 6. ArgoCD Application 생성

### src/argocd-applications.yaml 파일 수정
1. `YOUR_USERNAME`을 실제 GitHub 사용자명으로 변경
2. `PROD_CLUSTER_ENDPOINT`를 실제 Prod 클러스터 엔드포인트로 변경

### Application 생성
```bash
argocd cluster add arn:aws:eks:eu-central-1:$AWS_ACCOUNT_ID:cluster/prod-cluster --name prod-cluster
kubectl apply -f src/argocd-applications.yaml
```

## 7. 테스트

### Feature 브랜치에서 Dev로 PR 생성 테스트
1. feature/test 브랜치 생성
2. 코드 변경 후 커밋
3. dev 브랜치로 PR 생성
4. 자동 머지 및 배포 확인

### Dev에서 Prod로 PR 생성 테스트
1. dev 브랜치에서 prod 브랜치로 PR 생성
2. `approval` 라벨 추가
3. 자동 머지 및 배포 확인