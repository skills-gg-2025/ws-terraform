# VPC Lattice
## 요구사항
당신에게 쥐어진 아키텍처를 바탕으로 고가용성과 성능 등 여러 가지 요소를 고려하여 웹 어플리케이션이 구동할 수 있는 클라우드 플랫폼을 구축하여야 합니다. AWS에서 제공하는 솔루션 및 다양한 Use Case 등을 활용하여 보다 빠르고 안정성 있게 구축하는 것이 당신의 업무입니다. 해당 문제는 ap-southeast-1에 리소스를 생성하도록 합니다.

## VPC
VPC를 생성하여 클라우드 네트워킹을 구성합니다. HA를 고려하여 최소 2개의 가용영역(AZ)를 가지도록 구성합니다.

### Consumer VPC
- VPC Name : skills-consumer-vpc
- VPC CIDR : 172.168.0.0/16
- Intetnet G/W Name : skills-consumer-igw
- Nat G/W Name : skills-consumer-nat-a, skills-consumer-nat-c

#### Public Subnet A
- CIDR : 172.168.0.0/24
- Name : skills-consumer-public-subnet-a
- 외부 통신 : Internet G/W를 구성하여 인터넷을 접근
- Route Table Name : skills-consumer-public-rt

#### Public Subnet C
- CIDR : 172.168.1.0/24
- Name : skills-consumer-public-subnet-c
- 외부 통신 : Internet G/W를 구성하여 인터넷을 접근
- Route Table Name : skills-consumer-public-rt

#### Private Subnet A
- CIDR : 172.168.2.0/24
- Name : skills-consumer-workload-subnet-a
- 외부 통신 : Nat G/W를 구성하여 인터넷을 접근
- Route Table Name : skills-consumer-workload-rt-a

#### Private Subnet C
- CIDR : 172.168.3.0/24
- Name : skills-consumer-workload-subnet-c
- 외부 통신 : Nat G/W를 구성하여 인터넷을 접근
- Route Table Name : skills-consumer-workload-rt-c

### Service VPC
- VPC Name : skills-service-vpc
- VPC CIDR : 10.0.0.0/16
- Intetnet G/W Name : skills-service-igw
- Nat G/W Name : skills-service-nat-a, skills-service-nat-c

#### Public Subnet A
- CIDR : 10.0.0.0/24
- Name : skills-service-public-subnet-a
- 외부 통신 : Internet G/W를 구성하여 인터넷을 접근
- Route Table Name : skills-service-public-rt

#### Public Subnet C
- CIDR : 10.0.1.0/24
- Name : skills-service-public-subnet-c
- 외부 통신 : Internet G/W를 구성하여 인터넷을 접근
- Route Table Name : skills-service-public-rt

#### Private Subnet A
- CIDR : 10.0.2.0/24
- Name : skills-service-workload-subnet-a
- 외부 통신 : Nat G/W를 구성하여 인터넷을 접근
- Route Table Name : skills-service-workload-rt-a

#### Private Subnet C
- CIDR : 10.0.3.0/24
- Name : skills-service-workload-subnet-c
- 외부 통신 : Nat G/W를 구성하여 인터넷을 접근
- Route Table Name : skills-service-workload-rt-c

## VPC Lattice
해당 아키텍처는 Consumer VPC와 Service VPC로 네트워크가 분리되어 있으며, 두 VPC 간 통신은 VPC Lattice를 통해 이루어집니다. Consumer VPC에서 발생한 요청은 VPC Lattice를 거쳐 Service VPC로 전달되며, 이를 통해 안전하고 효율적인 네트워크 연결이 가능합니다.
- Lattice Service Network Name : skills-app-service-network
- Lattice Service Name : skills-app-service
- Lattice Target Group Name : skills-alb-tg

## Bastion
채점을 위해 AWS EC2를 사용하여 Bastion Server를 생성합니다. 채점 중 ip가 갑작스럽게 변경되는 상황이 없게끔 재시작시에도 ip는 변경되지 않게 구성하여야 합니다. Bastion은 채점용으로 사용됨으로 반드시 SSH를 통한 접속과 권한문제가 없도록 합니다.
- Instance Name Tag : skills-bastion
- Machine Image : Amazon Linux 2023
- Instance Type : t3.micro
- Security Group Name Tag : skills-bastion-sg
- IAM Role Name Tag : skills-bastion-role
- Required Package : awscliv2 , curl, jq 

## Application
### Consumer Server (External ALB)
Consumer Server는 Consumer VPC 내 Private Subnet에 위치하며, External ALB와 연결됩니다. 외부 클라이언트로부터 받은 요청을 수신한 후, 이를 VPC Lattice를 통해 Service VPC로 전달하여 App Server와 통신합니다. 이를 통해 외부 트래픽을 안전하게 내부 서비스로 라우팅합니다. Consumer Server는 웹서버를 사용하거나 Python을 이용하여 직접 개발하여 서버를 구성하도록 합니다.
- External ALB Name : skills-consumer-alb

### App Server (Internal ALB)
App Server는 Service VPC 내 Private Subnet에 위치하며, Internal ALB와 연결됩니다. VPC Lattice를 통해 Consumer Server로부터 전달된 요청을 수신하고, 비즈니스 로직을 처리합니다. App Server는 DynamoDB와 통합되어 데이터를 저장하고 조회하며, 확장성과 안정성을 제공합니다. 
- Internal ALB Name : skills-app-alb

## DynamoDB
App Server는 DynamoDB를 사용하여 데이터를 처리합니다. 테이블 구성 시 PAY_PER_REQUEST 모드를 사용하며 UserId를 테이블의 키로 사용합니다. 또한 데이터 유실을 대비하여 PITR 을 활성화 하며 테이블의 의도치 않은 삭제를 방지 하기 위해 테이블의 삭제 방지를 구성합니다.
- Table Name : skills-app-table
- Keys : UserId
- Mode : PAY_PER_REQUEST