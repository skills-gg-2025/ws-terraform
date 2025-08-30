# 충남 1과제 배포
## 데이터 베이스
1. `day1_table_v1.sql`를 사용하여 테이블 생성
## EKS
1. EKS 클러스터 생성
2.  시작 템플릿 user data 변경 후 노드그룹 생성

```
[settings.kubernetes]
cluster-domain = "wsc2025.local"
```
## Kubernetes
1. coredns로 kubenetes 내부 사용 도메인 변경

```
kubectl edit -n kube-system cm coredns
kubectl rollout restart deployment -n kube-system coredns 
kubectl get --raw "/api/v1/nodes/NODE_NAME/proxy/configz" | jq | grep -i domain
```
2. AWS Load Balancer Controller 설치 후 secret.yaml, deployment.yaml, service.yaml, ingress.yaml 배포
3. wsc2025-external-nlb 생성
4. configmap에 codepipeline role 추가
```
kubectl edit configmap aws-auth -n kube-system

mapRoles: |
  - rolearn: arn:aws:iam::942035140074:role/codebuild-wsc2025-service-role
    username: build
    groups:
      - system:masters

kubectl get configmap aws-auth -n kube-system -o yaml
```
## Code build, pipeline
1. 추가구성 -> 도커 권한 추가 후 빌드 생성
2. pipeline 배포에서 아티팩트를 BuildArtifact 선택
3. 매니페스트 파일 경로를 deployment-resolved.yaml로 설정
