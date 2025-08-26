## Web ServiceProvisioning
10, 11, 12, 13 부분은 직접 생성해야합니다. 

## 3. Network Configure
Cloud내에 가상 사설 Network를 구축할 수 있도록 아래의 설명과 Reference01의 표를 참고하여 VPC를 구성하도록 합니다. Reference01의 표를 참고하여 VPC를 구성하도록 하며, Subnet 이름 뒤에 알파벳은 가용 영역(AZ)을 의미합니다.

## 4. Transit Gateway
생성되는 VPC끼리 통신이 가능하도록 구성하기 위해 Transit Gateway를 사용합니다. Application VPC에 있는 서버 및 DB 접근은 Hub VPC에 있는 Bastion을 통해서 가능하도록 구성합니다. Transit Gateway의 이름은 “wsc2025-tgw”로 지정합니다.
- Hub VPC TGW Attachment Name: wsc2025-hub-tgat
- Application VPC TGW Attachment Name: wsc2025-app-tgat

## 5. Bastion
채점을 위해 AWS EC2를 사용하여 Bastion Server를 생성합니다. 외부에서 접근이 가능하도록 구성해야 하며, 채점 중 ip가 갑작스럽게 변경되는 상황이 없게끔 재시작시에도 ip는 변경되지 않게 구성하여야 합니다. 모든 AWS Service를 Access 가능해야 하며, 구성이 잘못되었을 경우 채점 진행시 불이익이 발생할 수 있습니다.
- Instance Name Tag : wsc2025-bastion
- Subnet : wsc2025-pub-sub-sn-a
- Machine Image : Amazon Linux 2023
- Instance Type : t3.small
- Required Package : awscliv2 , curl , kubectl , jq

## 7. Database
Green, Red 앱에서 사용하는 RDBMS 엔진으로 MySQL을 사용하며 데이터베이스 이름은 day1 입니다. 테이블 생성은 첨부파일 day1_table_v1.sql을 이용합니다. 데이터베이스는 Multi-AZ DB instance으로 생성하며, Application VPC에 DB Subnet에 생성합니다. ⚠️day1_table_v1.sql 삽입 필요⚠️ 

- DB Instance Name : wsc2025-db-instance
- DB Engine : MySQL Community
- Master username : admin
- Master password : Skill53##
- DB instance class : db.t3.medium 

## 8. Container Registry
Registry 컨테이너 이미지 저장을 위해 ECR을 사용하도록 합니다. 바이너리 이름과 동일하게 green/v1.0.0, red/v1.0.0 , green/v1.0.1, red/v1.0.1 총 4개의 이미지를 업로드 해둡니다. 과제는 1.0.0으로 진행하고 CD pipeline 채점시 v1.0.1 이미지를 활용합니다. ⚠️어플리케이션 업로드 필요⚠️

## 9. S3
애플리케이션 관련 파일들을 S3에 체계적으로 저장하여 관리합니다. /source/green 프리픽스에는 Green 애플리케이션 및 Green ECR에 푸시할 파일들을, /source/red 프리픽스에는 Red 애플리케이션 및 Red ECR에 푸시할 파일들을 각각 업로드합니다. 각 애플리케이션 및 ECR에 푸시할 파일들을 zip 파일 형태로 업로드하며, Green과 Red 각각에 대해 독립적으로 버전 및 패키지를 관리할 수 있도록 구성합니다.
- S3 Bucket Name: wsc2025-app-<임의의 4자리 영문>
- Green ZIP File Name: green.zip
- Red ZIP File Name: red.zip

## <u>10. Container Orchestartion</u>
EKS를 통해 컨테이너를 배포하고 관리합니다. 주어진 애플리케이션들은 각각 wsc2025-red-app, wsc2025-green-app라는 이름의 container으로 구성하며, pod들은 wsc2025이라는 namespace에 생성합니다. Cluster는 Application VPC에 위치해야 하며, node name은 <instance-id>.ec2.internal로 변경합니다. Kubernetes 내부에서 사용하는 Domain을 기존 *.cluster.local에서 *.wsc2025.local로 변경합니다. ⚠️k8s 디렉토리에 있는 yaml 파일로 생성합니다.⚠️

- user data script & coredns로 Kubernetes 내부 사용 도메인 변경

```
[settings.kubernetes]
cluster-domain = "wsc2025.local"
```

---

```
kubectl edit -n kube-system cm coredns
kubectl rollout restart deployment -n kube-system coredns 
kubectl get --raw "/api/v1/nodes/NODE_NAME/proxy/configz" | jq | grep -i domain
```

- EKS Cluster Name : wsc2025-eks-cluster
- EKS Cluster Version : 1.32

### Application NodeGroup
애플리케이션은 전용 Application NodeGroup에서만 실행되어야 합니다. 해당 NodeGroup의 노드에는 { app: db } 라벨이 지정되어 있어야 합니다.
- NodeGroup Name: wsc2025-app-ng
- Node Instance Name: wsc2025-app-node
- Node Instance Type: t3.medium

### Addon NodeGroup
애플리케이션 이외의 Addon 또는 시스템 구성 요소들은 별도의 Addon NodeGroup에서 운영합니다. 해당 노드에는 { app: addon } 라벨이 설정되어 있어야 합니다.
- NodeGroup Name: wsc2025-addon-ng
- Node Instance Name: wsc2025-addon-node
- Node Instance Type: t3.medium

### Application Deployment
애플리케이션은 Kubernetes Deployment를 통해 관리되며, 항상 고가용성을 유지할 수 있도록 구성합니다. Deployment의 label은 각각 green deploy는 app:wsc2025-green-deploy을 사용하고, red deploy에는 app:wsc2025-red-deploy을 사용합니다.
- Green Deployment Name: wsc2025-green-deploy
- Red Deployment Name: wsc2025-red-deploy
- Green Service Name: wsc2025-green-svc
- Red Service Name: wsc2025-red-svc

## <u>11. LoadBalancer</u>
애플리케이션이 배포된 Application VPC에는 내부 통신을 위한 Internal ALB를 생성합니다. 이 ALB는 Private Subnet에 위치하며, 외부에서는 직접 접근할 수 없습니다. 외부 요청을 수신하기 위해, Hub VPC에는 External NLB를 생성합니다. 이 NLB는 Public Subnet에 위치하며, 인터넷으로부터 직접 접근이 가능합니다.
외부사용자가 API에 접근할 시 Hub VPC에 있는 External NLB를 통해 애플리케이션이 접근가능해야 합니다.
- Application VPC LoadBalancer Name : wsc2025-app-alb
- Hub VPC LoadBalancer Name : wsc2025-external-nlb

## <u>12. Continuous Integration</u>
Build 작업은 AWS CodeBuild를 통해 수행합니다. S3에 ZIP 파일이 업로드되면, 파일명에 애플리케이션에 포함된 버전 정보에 따라 ECR에 자동으로 Docker 이미지가 푸시되도록 구성해야 합니다. 예를 들어 green_1.0.0 파일이 업로드되면 ECR에는 v1.0.0 태그로, red_1.0.1이 업로드되면 v1.0.1 태그로 이미지가 푸시되어야 합니다. 애플리케이션 구분은 S3 업로드 경로의 프리픽스를 기준으로 합니다. /source/green/ 경로에 업로드된 파일은 Green 애플리케이션, /source/red/ 경로에 업로드된 파일은 Red 애플리케이션으로 간주하며, 각각 독립적인 CodeBuild 프로젝트를 통해 빌드가 수행되어야 합니다. ⚠️src 디렉토리에 있는 green.zip과 red.zip을 이용합니다.⚠️
- Green CodeBuild Name: wsc2025-green-build
- Red CodeBuild Name: wsc2025-red-build

## <u>13. Pipeline</u>
빌드와 테스트 과정을 자동화하기 위해 AWS CodePipeline을 활용합니다. 파이프라인은 S3에 새로운 버전의 애플리케이션이 업로드 되면 먼저 12번에서 생성한 CodeBuild를 통해 빌드 단계를 수행합니다. 빌드가 정상적으로 완료되면, 이어서 수동 승인 단계가 진행됩니다. 수동 승인이 완료되면, kubernetes 환경에 새로운 이미지를 가진 deployment로 배포되어야 합니다.
- Green CodePipeline Name: wsc2025-green-pipeline
- Red CodePipeline Name: wsc2025-red-pipeline