# 경북 1과제 배포
## 데이터베이스
1. `src/day1_table_v1.sql`을 사용하여 테이블 생성

## Github
1. `gh auth login`을 통해 깃허브 로그인을 합니다.
2. day1-values라는 이름의 Public Repository를 생성합니다.
3. green.values.yaml, red.values.yaml을 업로드합니다.

## Kubernetes
1. EKS 연결 및 환경변수 설정을 합니다.
2. CoreDNS를 재시작합니다. (Fargate Node 미사용 시)
```
kubectl delete pods -n kube-system -l k8s-app=kube-dns
```
3. skills Namespace를 생성합니다.
4. Container Insights, AWS Load Balancer Controller, External Secrets Operator를 설치합니다.
5. ArgoCD 등 애플리케이션 배포가 끝난 후 Fluent Bit 설정을 합니다.
6. 채점을 위해 v1.0.1 binary를 사용하는 Dockerfile을 /home/ec2-user/images 폴더 아래의 green, red 폴더 하위에 각각 위치하도록 합니다.

### ArgoCD
1. ServiceAccount를 생성합니다.
``` bash
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=argocd \
  --name=argocd-repo-server \
  --role-name ArgocdRepoServerRole \
  --attach-policy-arn=arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --approve
```
2. values.yaml을 참고하여 설치합니다.
3. EKS Cluster 보안그룹에 "모든 TCP, ALB 보안그룹 대상"으로 추가합니다.
4. green.yaml, red.yaml application을 배포합니다.

## Opensearch
1. 권한 설정을 통해 Fluent Bit가 Log를 넣을 수 있도록 합니다. (IAM_ROLE_ARN 환경변수를 설정합니다.)
``` bash
ENDPOINT_URL=https://$(aws opensearch describe-domain --domain-name skills-opensearch --output text --query "DomainStatus.Endpoint")
curl -sS -u "admin:Skill53##" -X PATCH $ENDPOINT_URL/_opendistro/_security/api/rolesmapping/all_access?pretty -H 'Content-Type: application/json' -d '[{"op": "add", "path": "/backend_roles", "value": ["'$IAM_ROLE_ARN'"]}]'
```
