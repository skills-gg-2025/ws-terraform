# ECS Firelens
## 요구사항
ECS 환경에서 효율적인 로그 처리 및 관리를 위해 Fluentbit 를 활용해 애플리케이션 컨테이너들의 로그를 수집할 수 있도록 합니다. 해당 문제는 eu-west-1에 리소스를 생성합니다.

## VPC
### VPC 정보
- VPC CIDR : 10.1.0.0/16
- VPC Tag : Name=skills-log-vpc

### Private A subnet 정보
- CIDR : 10.1.0.0/24
- Tag : Name=skills-log-priv-a
- 외부 통신 : NAT G/W를 구성하여 인터넷 접근이 가능하도록 구성
- Route table Tag : Name=skills-log-priv-rt-a

### Private B subnet 정보
- CIDR : 10.1.1.0/24
- Tag : Name=skills-log-priv-b
- 외부 통신 : NAT G/W를 구성하여 인터넷 접근이 가능하도록 구성
- Route table Tag : Name=skills-log-priv-rt-b

### Public A subnet 정보
- CIDR : 10.1.2.0/24
- Tag : Name=skills-log-pub-a
- 외부 통신 : Internet G/W를 구성하여 인터넷을 접근
- Route table Tag : Name=skills-log-pub-rt

### Public B subnet 정보
- CIDR : 10.1.3.0/24
- Tag : Name=skills-log-pub-b
- 외부 통신 : Internet G/W를 구성하여 인터넷을 접근
- Route table Tag : Name=skills-log-pub-rt

## Bastion Server
채점을 위해 AWS EC2를 사용하여 Bastion Server를 생성합니다. Bastion은 채점용으로 사용됨으로 반드시 SSH를 통한 접속과 권한문제가 없도록 합니다.
- Instance Name Tag : skills-log-bastion
- Machine Image : Amazon Linux 2023
- Instance Type : t3.small
- Security Group Name Tag : skills-log-bastion-sg
- IAM Role Name Tag : skills-log-bastion-role
- Required Package : awscliv2 , curl, jq, docker

## Application
애플리케이션은 외부 사용자의 요청을 받아 서버 내부에서 로그를 남깁니다. Public 서브넷에 위치한 ALB를 통해 요청을 전달받습니다.
- Binding port: 5000
- GET /check : {"data": "hello"}
- GET /health : {"status": "ok"}

## ECR
제공된 application이 포함된 컨테이너 이미지를 ECR에 저장하려고 합니다. ECR에 upload 된 이미지는 스캐닝 되어야 하며 취약점이 존재해서는 안됩니다.
- application ECR name : skills-app
- fluent bit ECR name : skills-firelens

## Elastic Container Service
아래의 정보를 활용하여 ECS를 구성합니다. Python Applcation은 ECR을 통하여 task에 배포합니다. ALB를 통해서 들어오는 요청만 허용해야 하며, alb는 /health 경로를 통해 healthcheck를 해야합니다. 모든 서비스의 호스트 포트는 5000으로 설정합니다. 모든 서비스는 Fargate에서 실행되어야 하며, 또한 모든 응용 프로그램은 Private Subnet에 구성하도록 합니다. FireLens를 이용한 Fluent Bit 로깅 구성을 포함한 Task Definition을 작성합니다. 로그 드라이버는 awsfirelens를 사용합니다. FireLens 구성 파일(extra.conf, parsers.conf)은 선수가 직접 작성해야 합니다.
- ECS Cluster Name : skills-log-cluster
- ALB name Tag : skills-log-alb
- ECS Service Name : app
- ECS TaskDefinition Name Tag : skills-log-app-td
- Container Name : app, log_router

## Fluent Bit
Fluent Bit는 FIrelens와 통합되며, extra.conf에서 INPUT, FILTER를 구성하고 parsers.conf에는 PARSER를 구성하여 애플리케이션 로그를 JSON 형태로 파싱해야 합니다.
- Plain Log : 172.17.0.1 - - [14/Jun/2025 02:43:22] "GET /check HTTP/1.1" 200 -
- CloudWatch Log
``` json
{
    "clientip": "10.1.3.186",
    "timestamp": "14/Jun/2025 03:32:25",
    "method": "GET",
    "path": "/check",
    "http_version": "1.1",
    "statuscode": "200"
}
```

## Cloudwatch
모든 어플리케이션 로그는 CloudWatch Logs로 전송되어야 하며, 로그는 JSON 형식으로 구조화하여 시각화 및 분석에 적합한 품질로 유지합니다.
- Log Group Name : /skills/app
- Log Stream Name : logs/<ECS TASK ID>