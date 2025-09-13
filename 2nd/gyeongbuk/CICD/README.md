# Actions Runner Controller
## 요구사항
EKS와 Github 및 Github Actions, ArgoCD를 활용한 CI/CD 파이프라인을 구성해야 합니다. EKS cluster 위에서 동작하는 Self-hosted Runner를 구축하여 workflow job들을 수행할 수 있도록 합니다. Github-hosted Runner는 사용할 수 없습니다. 컨테이너 이미지가 빌드되어 ECR에 업로드되면 ArgoCD를 통해 업로드된 이미지로 컨테이너에 무중단 배포 되어야 합니다. 요구사항에 맞게 적절한 파이프라인을 구성하세요. 해당 문제는 eu-central-1에 리소스를 생성합니다.

## VPC 구성
- dev환경과 prod환경으로 나눠 운영하기 위해 VPC 2개를 구성해야 합니다.
- 각각의 VPC는 2개의 Public subnet, 2개의 Private subnet이 존재해야 합니다.
- VPC Name tag: dev-vpc, prod-vpc

## Bastion 구성
- dev-vpc의 Public subnet에 채점을 위한 Bastion EC2를 생성하며, 정상적으로 EKS Cluster에 클러스터 관리자 권한으로 접근할 수 있어야 합니다. 또한 채점을 위해 gh cli를 통해 Github에 접근할 수 있어야 하고 argocd cli를 통해 ArgoCD에 login 되어 있어야 합니다.
- 채점을 위해 인스턴스 iam role에 AdministratorAccess 정책을 추가해야 합니다.
- Bastion EC2 설치 패키지: kubectl, gh cli, argocd cli
- Bastion Name tag: dev-bastion

## Application
- 애플리케이션은 8080 port에서 동작합니다.
- 애플리케이션은 Argo Rollouts CRD를 통해 각 EKS cluster에 배포되어야 합니다.
- 애플리케이션은 각 EKS cluster의 app namespace에 배포되어야 합니다.

## EKS
- EKS cluster를 dev와 prod로 분리된 2개의 VPC의 Private subnet에 각각 구성해야 합니다.
- dev-cluster, prod-cluster라는 cluster name을 사용합니다.

## Repository
- Github를 이용해 애플리케이션 개발 및 형상 관리를 위한 Public Repository를 구성합니다.
- day2-product라는 이름의 Repository를 생성합니다.
- app이라는 이름의 Helm chart를 Repository의 최상위 위치의 charts/ 에 구성하고, dev.values.yaml, prod.values.yaml을 values/ 에 구성합니다.
- main branch에 애플리케이션 소스코드 및 배포 관리 환경 구성을 위한 .github/workflows, Dockerfile, app.py, requirements.txt, charts/, values/ 를 함께 commit & push 합니다.
- main branch를 source로 하여 dev, prod branch를 생성합니다. 또한 dev branch를 base로 설정합니다.
- 새로운 기능을 위한 feature/* 형태의 branch를 추가할 수 있으며, dev 및 prod branch로 PR을 생성할 수 있습니다.
- prod branch로의 PR 요청 처리를 위한 approval 이라는 PR label을 생성합니다.

## Registry
- ECR에서 product/dev, product/prod 라는 2개의 private repostory를 생성합니다.
- 제공된 Python 소스코드를 통해 빌드된 이미지를 업로드해 두어야 합니다.

## Workflow
- Github Actions를 활용한 파이프라인을 구성합니다.
- workflow는 dev, prod라는 이름으로 2개를 작성해야 하며, 각각 dev.yml, prod.yml로 작성합니다. 
- workflow는 멀티 아키텍처를 고려해 linux/amd64, linux/arm64 를 모두 빌드할 수 있도록 구성해야 합니다. 또한 새로 빌드되는 이미지의 tag는 Commit ID를 사용합니다.
- Trigger 발생 시 product/dev, product/prod ECR repo에 새로운 tag로 이미지 업로드 후 Repo 내 values/ 의 dev/prod.values.yaml를 새로운 이미지를 사용하도록 수정하고 argocd sync하여 각각의 cluster에서 새 버전으로 업데이트 되도록 전체 작업을 자동화합니다.
- dev, prod cluster에 각각의 Self-hosted Runner를 구성해야 하며, runner는 각각 dev, prod라는 custom label을 가지고 있어야 합니다. 또한 2개의 runner를 유지해야 합니다.
- feature/* branch에서 dev branch로 PR 생성 시 dev-cluster의 runner를 사용해 1분 이내에 dev branch로 merge를 진행하며, product/dev ECR repo로 build & push 한 후 ArgoCD에 즉시 Sync 하도록 구성합니다.
- dev branch에서 prod branch로 PR 생성 시, 해당 PR에 approval label을 부여하면 1분 이내에 prod branch로 merge를 진행하며, product/prod ECR repo로 build & push 한 후 ArgoCD에 즉시 Sync 하도록 구성합니다. 또한 dev branch에 Fast-Forwarding 해야 합니다.
- Dockerfile을 잘 구성하여 1분 이내에 파이프라인이 성공적으로 완료되도록 하세요.
- ECR push 시 ECR에 접근할 때 보안을 위해 AWS Access Key를 사용할 수 없습니다. Github OIDC를 구성하여 workflow에서 IAM Role을 통해 접근할 수 있도록 구성합니다.

## Argo
- ArgoCD는 dev-cluster에만 설치합니다. prod-cluster는 Rollouts만 설치할 수 있으며, dev-cluster에 위치한 ArgoCD에 등록해 함께 관리할 수 있도록 합니다. 또한 argocd라는 namespace를 사용해야 합니다.
- 애플리케이션은 Blue/Green 배포 전략을 통해 업데이트 되어야 하며, Auto sync는 비활성화합니다. Workflow에서의 Sync로 인해 새로운 버전의 애플리케이션이 준비가 완료되면 자동으로 기존 애플리케이션을 대체해야 합니다.
- 애플리케이션 업데이트가 완료되면 기존 애플리케이션 pod는 종료되어야 합니다.
- Rollout 리소스의 이름은 product로 구성합니다.
- ArgoCD Application의 이름은 각각 dev, prod로 구성합니다.

## ALB
- ALB를 통해 최신 애플리케이션에 접근할 수 있도록 환경별로 2개의 ALB를 구성해야 합니다.
    - Ingress Name : dev-ingress, prod-ingress
    - Ingress Namespace : app
    - ALB Name Tag : dev-alb, prod-alb