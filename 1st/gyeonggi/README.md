<h1 align="center">Deploying Gyeonggi 1st task</h1>

## A. 유의 사항
1. ❗ **배포 전** Host 환경에 Docker 설치가 필요합니다.
2. `day1_table_v1.sql`을 통해 Aurora의 테이블을 삽입할 필요가 없습니다.
3.  채점 시 KeyPair를 통해 접근할 것입니다. 채점 전 키페어의 권한이 적절한지 확인해야 합니다.
4. `terraform.tfvars`에서 비번호, Aurora 마스터 사용자 이름, 비밀번호를 설정해야합니다.

## B. Monitoring
1. Container Insights의 `대시보드에 추가` 기능을 사용 해 대시보드에 추가 후, 저장합니다.
2. Green, Red API를 여러 번 호출하여 지표의 값과 경보 상태가 변화하는지  확인합니다. 
