# VPC
아래의 설명과 Reference01의 표를 참고하여 VPC를 구성하도록 합니다. Application이 구동되는 Subnet에서는 Image Download 시 내부 Network만을 거쳐 내려 받을 수 있도록 구성합니다. (ecr.dkr, s3 Endpoint를 사용해야 합니다.)

# Peering between VPCs
해당 Architecture에서는 2개의 VPC로 Network가 분리되어 있습니다. 각 VPC들이 서로 통신할 수 있어야 외부로 부터의 요청을 앱이 문제 없이 처리할 수 있게 됩니다. 각 VPC들을 통신시키기 위하여 Peering Connection을 사용하도록 합니다. 
- peering connection name: skills-peering

# Network Firewall
IGW를 통해 VPC 내부로 들어오는 트래픽과 Bastion에서 나가는 트래픽을 필터링하기 위해 Network Firewall을 구성합니다. IGW를 통해 들어오는 트래픽과, VPC 내부에서 IGW를 통해 나가는 트래픽이 모두 Network Firewall이 위치한 Inspection Subnet을 통해서 이동해야 합니다. PCX 및 IGW, NAT 등을 통하는 트래픽의 흐름을 잘 고려해서 Route table의 Route를 구성하세요.
- network firewall name : skills-firewall
- network firewall policy : skills-firewall-policy
- network firewall subnet : skills-inspect-subnet-a, skills-inspect-subnet-b

## Network Firewall Rule
아래 규칙을 구성해 조건에 맞춰 트래픽을 차단할 수 있도록 합니다.
- Bastion에서 외부 ifconfig.me로 향하는 HTTP/HTTPS 요청을 차단합니다.

# Bastion Server
채점을 위해 AWS EC2를 사용하여 Bastion Server를 생성합니다. 채점 중 ip가 갑작스럽게 변경되는 상황이 없게끔 재시작시에도 ip는 변경되지 않게 구성하여야 합니다. SSH 접근 시 Security를 고려하여 Port Number를  2025로 변경하여야 합니다. skills-hub-subnet-a Subnet에서 실행되어야 합니다. 채점 시 Root user에서 진행하므로 패키지 관련 오류는 없어야 하며, IAM Role은AdministratorAccess Policy만을 사용하여 구성합니다. Github CLI를 통해서 계정 및 레포지토리에 접근할 수 있어야 합니다. 또한 Bastion EC2는 KeyPair 및 Password 인증을 모두 사용해 접근이 가능하도록 구성합니다. Bastion Server는 채점을 위해서 사용됩니다.
잘 못 구성하였을 경우 특정 채점 항목에서 불이익을 받을 수 있으니 주의합니다.
- Instance Name Tag : skills-bastion
- Machine Image : Amazon Linux 2023
- Instance Type : t3.small
- Security Group Name Tag : skills-bastion-sg
- IAM Role Name Tag : skills-bastion-role
- Login Password : Skill53##
- Required Package : awscliv2, curl, jq, eksctl, kubectl, argocd cli, gh cli

# Secret Store
Application Database 연결을 위한 환경변수들을 KMS로 암호화된 Secrets Manager에 저장해 관리합니다. 환경변수 값은 Pod에 직접적으로 명시해선 안되며, Secrets Manager에 저장된 값을 통해서만 불러오도록 구성합니다. (Environment Variables 세부 사항은 Reference02 참고)
- Application Secret Name : skills-secrets

# Application
Green, Red 총 2개의 Application이 존재합니다. 제공된 binary는 golang/gin을 사용하여 개발되었으며, x86 시스템에서 빌드하였습니다. Application 실행 시 바인딩되는 Port Number는 TCP/8080입니다. 또한 2개의 application 전부 /health를 통하여 Appliation 상태를 확인합니다.  (Application 세부 사항은 Reference02 참고)

# RDBMS
Green, Red Application 데이터를 안정적이고 효율적으로 저장하기 위해서 RDMBS를 구성합니다. AWS에서 관리하는 MySQL 호환 엔진을 사용하고, default for major version 8.0으로 Database를 구축하도록 합니다. DB관리에 편의를 위하여 Logging과 Monitoring, Backtracking 이 활성화 되어있어야 합니다. 또한 Bastion Server에서 RDS에 접근 할 수 있도록 구성합니다.
- DB Cluster Name : skills-db-cluster
- Master username : admin
- Master password : Skill53##
- DB instance class : db.t3.medium
- DB Name : day1

# S3 Bucket
ArgoCD의 애플리케이션을 쉽게 관리하기 위해 S3 Bucket 및 Helm Chart를 사용해 Manifest를 관리하도록 구성합니다. 또한 채점에 사용 될 v1.0.1 바이너리들을 S3에 업로드합니다.
- Bucket Name : skills-chart-bucket-<영문 4자리>
- App Chart : s3://skills-chart-bucket-<영문 4자리>/app
- v1.0.1 Binary Path : s3://skills-chart-bucket-<영문 4자리>/images/

# Container Registry
제공된 application들을 Image화 시킨 후 AWS ECR Repository에 저장하려고 합니다. ECR에 Upload 된 Image들은 KMS암호화와 취약점 분석이 가능해야하며. 취약성이 존재해서는 안됩니다. 또한 v1.0.0 Tag로 업로드하며 동일한 Tag가 존재 할 경우 업로드가 불가능 하도록 구성합니다. 채점을 위해 컨테이너에 curl을 설치하도록 합니다.
- Green image repository Name : skills-green-repo
- Red image repository Name : skills-red-repo

# Continuous Delivery
애플리케이션의 배포 과정을 자동화 시켜 업무 효율성 향상을 위해 CD 환경을 구성합니다. 먼저 S3 및 Helm Chart를 활용해 ArgoCD Application을 구성합니다. Application의 Chart source는 s3:// 형식의 S3 URI를 사용하도록 합니다. app 이라는 이름의 Chart를 하나 구성하고, Github에서 day1-values라는 이름의 Public Repository를 생성합니다. day1-values에 green, red 앱을 위한 values 소스를 각각 작성해서 이를 활용하도록 ArgoCD Application을 green, red라는 이름으로 2개 구성해야 합니다. 또한 Argo Rollouts를 활용해 Blue/Green 배포전략을 사용하도록 합니다. ArgoCD에서 Sync 시 Github Repository의 values에 명시된 내용에 따라 앱도 변경되어야 합니다. 단, values를 가져오기 위해 githubusercontent, Github Pages는 사용할 수 없습니다.(채점을 위해 v1.0.1 binary를 사용하는 Dockerfile을 /home/ec2-user/images 폴더 아래의 green, red 폴더 하위에 각각 위치하도록 합니다.)
- Green Values File Name : green.values.yaml
- Red Values File Name   : red.values.yaml

# Container Orchestration
제공된 Application을 Container 환경에 배포하기 위해 AWS EKS를 사용합니다. EKS Cluster Control Plane에서 발생하는 모든 로그들을 CloudWatch Logs에서 확인할 수 있어야 하며, Secret Resource들은 반드시 KMS Encryption 되어야 합니다. 또한 Kubernetes API는 외부에서 접근 불가능해야 하며, Bastion Server에서만 접근할 수 있어야 합니다. 관리의 편의를 위해 모든 NodeGroup은 Managed NodeGroup으로 생성하며, 최소한의 고가용성을 고려하여야 하고, Private 환경에서 NodeGroup이 실행되어야 합니다. 주어진 application들은 skills 라는 Namespace를 사용하여 EKS Cluster 내에서 논리적으로 분리시켜야 합니다. 새로운 Version의 EKS Pod가 배포될 수 있기에 무중단 배포를 고려하여 구성하여야 합니다.
- EKS Cluster Name : skills-eks-cluster
- EKS Cluster Version : 1.32

## Application Managed Nodegroup
Application들은 반드시 Application NodeGroup에서 운용되어야 합니다. 이 외의 다른 Resource들이 존재해서는 안 되며, 고가용성을 고려하여야 합니다. 또한 해당 NodeGroup의 Node는 {skills:app} 라는 Label을 가지고 있어야 합니다.
- NodeGroup Name : skills-app-nodegroup
- Node Instance Name Tag : skills-app-node
- Node Instance Type : t3.medium

## Addon Managed Nodegroup
Application을 제외한 AWS Load Balancer Controller와 같은 Addon들은 반드시 Addon NodeGroup에서 운용되어야 합니다. 최소 2개 이상 운영하여야 합니다. 또한 해당 NodeGroup의 Node는 {skills:addon} 라는 Label을 가지고 있어야 합니다.
- NodeGroup Name : skills-addon-nodegroup
- Node Instance Name Tag : skills-addon-node
- Node Instance Type : t3.medium

## Fargate Profile
CoreDNS를 배포하기 위하여 Fargate를 사용합니다. CoreDNS를 제외한 다른 리소스는 Fargate Profile에 존재해서는 안됩니다.
- Fargate Profile Name : skills-fargate-profile
- Label : {skills:coredns}

## EKS Delpoyments
- green Application Deployment Name : green-deploy
- red Application Deployment Name : red-deploy

# Logging
Application Log를 수집하기 위해서 OpenSearch를 사용합니다. 로그 수집을 위해 Fluentd가 Fluent Bit로 부터 로그를 수신하여 OpenSearch에 저장하도록 구성합니다. Fluentd는 Application Nodegroup 노드 당 Pod 1개 씩 운용되도록 해야하며, Fluent Bit는 애플리케이션 Pod 내에서 Sidecar 방식으로 운용되도록 구성합니다. OpenSearch Dashboard는 웹 브라우저로 접속이 가능해야합니다. 또한 /health 경로의 로그는 전달되지 않도록 구성합니다.
OpenSearch에 적재되는 로그는 JSON 포맷의 형태로 파싱하여 저장하고 /health에 대한 로그는 제외되어야 합니다. (로그 포맷 세부 사항은 Reference03 참고)
- Domain Name : skills-opensearch
- Version : 2.19
- Data node instance type : r7g.medium.search
- Number of data nodes : 2
- Number of master nodes : 3
- Master username : admin
- Master password : Skill53##
- Index pattern : app-log

# Load Balancer
외부에서 Green, Red 애플리케이션에 원활하고 안전하게 접근할 수 있도록 아래 요구사항에 맞춰 Load Balancer를 구성합니다. VPC Endpoint를 사용하여 PrivateLink를 통해 인터넷을 통하지 않고 NLB 간 통신이 가능해야합니다.

## Internal ALB
내부에서 안전하게 application으로 접근할 수 있도록 하며, L7에서 제공되는 다양한 데이터를 기반으로 요청을 분산할 수 있도록 Application Load Balancer를 구성합니다. 
- Load Balancer Name : skills-alb
- Load Balancer Scheme : internal 
- Load Balancer Type : Application Load Balancer
- Load Balancer Listen : HTTP 80

## Internal NLB
External NLB에서 VPC Endpoint를 통해 안전하게 애플리케이션으로 접근할 수 있도록 Internal 타입의 Network Load Balancer를 구성합니다.
- Load Balancer Name : skills-internal-nlb
- Load Balancer Listen : TCP 80

## External NLB
Hub VPC에서 VPC Endpoint를 통해 안전하게 Internal NLB와 통신할 수 있도록 외부 접근이 가능한 Network Load Balancer를 구성합니다.
- Load Balancer Name : skills-nlb
- Load Balancer Scheme : internet-facing
- Load Balancer Listen : TCP 80

# Monitoring
CloudWatch의 Container Insights 기능을 이용하여 모니터링 시스템을 구축합니다. Container Insights 페이지에 접속하였을때 Cluster에 대한 정보 (CPU, Memory, Nodes, Pods)를 한 눈에 볼 수 있어야 합니다.

# Reference01

## Hub VPC
- skills-hub-vpc : 10.0.0.0/16

## Hub Subnets
- skills-hub-subnet-a : 10.0.0.0/24
- skills-hub-subnet-b : 10.0.1.0/24
- skills-inspect-subnet-a : 10.0.2.0/24
- skills-inspect-subnet-b : 10.0.3.0/24

## App VPC
- skills-app-vpc : 192.168.0.0/16

## App Subnets
- skills-app-subnet-a : 192.168.0.0/24
- skills-app-subnet-b : 192.168.1.0/24
- skills-workload-subnet-a : 192.168.2.0/24
- skills-workload-subnet-b : 192.168.3.0/24
- skills-db-subnet-a : 192.168.4.0/24
- skills-db-subnet-b : 192.168.5.0/24

# Reference02
## Environment variables
- DB_USER : DBMS연결에 사용할 사용자명
- DB_PASSWD : RDBMS연결에 사용할 사용자 암호
- DB_URL : RDBMS연결에 사용할 호스트 이름

## Application
- GET /health
    - Response : 200 OK
- POST /green
    - Request : {"x": "abcd", "y": 21}
    - Response : {"status": "inserted", "id": "xx11abcd"}
- GET /green
    - Request : ?id=xx11abcd
    - Response (v1.0.0) : {"x": "abcd", "y": 21, "version": "1.0.0"}
    - Response (v1.0.1) : {"x": "abcd", "y": 21, "version": "1.0.1"}
- POST /red
    - Request : {"name": "kim"}
    - Response : {"status": "inserted", id: "yy11abcd"}
- GET /red
    - Request : ?id=yy11abcd
    - Response (v1.0.0) : {"name": "kim", "version": "1.0.0"}
    - Response (v1.0.1) : {"name": "kim", "version": "1.0.1"}