# S3 Multi-Region Access Point
## 요구사항
현재 Amazon CloudFront와 CloudFront Function 등을 기반으로, 국가별 콘텐츠 분기와 악의적인 User-Agent 차단 기능을 구현하여 정적 콘텐츠를 제공하고 자동화된 요청을 차단함으로써 웹 서비스의 보안성과 성능을 강화하고 있습니다. AWS의 글로벌 인프라와 엣지 컴퓨팅 기술을 활용하여, 빠르고 안정적인 정적 웹 콘텐츠 제공 환경을 구성하는 것이 당신의 주요 책임입니다.해당 문제는 ap-northeast-2, us-east-1에 리소스를 생성합니다.

## VPC
채점을 위해 기본 VPC를 생성하여 클라우드 네트워킹을 구성합니다. 

## S3 Bucket
아래의 정보를 이용하여 S3버킷을 생성하고, 지급 받은 파일들을 모두 S3에 업로드 합니다. 해당 파일들은 이후 CloudFront를 통해 접근 할 수 있어야 하며 Lambda@Edge가 요청을 SigV4 방식으로 서명해 CloudFront가 S3 MRAP에 접근 하도록 구성해야합니다. 또한 사용자의 지리적 위치에 따라 가장 가까운 리전의 S3 버킷에서 콘텐츠를 제공하여 네트워크 레이턴시를 최소화 하기 위해 아래의 정보를 참고하여 Multi Region Access Point를 구성합니다. MRAP는 Public Access 차단을 활성화 하도록 합니다. 
- KR S3 Name Tag : skills-kr-cdn-web-static-<계정ID>
- US S3 Name Tag : skills-us-cdn-web-static-<계정ID>
- MRAP Name : skills-mrap
- Lambda@Edge Function Name : skills-cdn-edge-function

## Bastion
채점을 위해 AWS EC2를 사용하여 ap-northesat-2 에 Bastion Server를 생성합니다. 채점 중 ip가 갑작스럽게 변경되는 상황이 없게끔 재시작시에도 ip는 변경되지 않게 구성하여야 합니다. Bastion은 채점용으로 사용됨으로 반드시 SSH를 통한 접속과 권한문제가 없도록 합니다.
- Instance Name Tag : mrap-bastion
- Machine Image : Amazon Linux 2023
- Instance Type : t3.micro
- Security Group Name Tag : mrap-bastion-sg
- IAM Role Name Tag : mrap-bastion-role
- Required Package : awscliv2 , curl, jq 

## CloudFront Distributions
Distributions를 생성하고 글로벌 콘텐츠 전송을 위한 기본 설정 구성을 합니다. 오리진은 MRAP를 사용해야하며, Viewer Protocol Policy는 Redirect HTTP to HTTPS로 설정해야합니다. Origin Request Policy는 지역 정보를 기반으로 설정 해야합니다. 또한 CloudFront의 Viewer Request 단계에 연결되는 함수 코드를 개발해서 작성합니다. 지역기반 차단은 CloudFront 헤더 기능을 활용하여 KR, US 국가 이외에 들어오는 요청과 user-agent 헤더에 bot, crawler, spider가 포함되면 403 Status 와 아래의 응답을 반환하도록 구성합니다.
- CloudFront Name Tag : skills-global-distribution
- CloudFront Function Name : skills-cf-function
- Allow Region List : KR, US
- Country 403 Status Body : “Access denied: unsupported country”
- User Agent 403 Status Body :“Request blocked due to suspicious User-Agent”

## CloudFront Invalidations
현재 CloudFront를 통해 배포된 콘텐츠 중 일부 오브젝트가 업데이트되지 않는 문제가 발생하고 있습니다. 이를 해결하기 위해, Lambda를 이용해 해당 오브젝트에 대해 CloudFront Invalidation을 수행하여 캐시를 무효화하고 최신 버전이 사용자에게 전달되도록 아래의 정보를 참고하여 구성하도록 합니다. 
- KR Lambda Function Name : skills-lambda-function-kr
- US Lambda Function Name : skills-lambda-function-us
- KR Lambda IAM Role Name : skills-lambda-role-kr
- US Lambda IAM Role Name : skills-lambda-role-us