# Gyeonggi

## Day 1
- Solution Architecture

### ✅ Terraform 배포 이후 체크 리스트

- ℹ️ `Bastion을 이용해 MySQL 테이블 생성`
    - src/day1_table_v1.sql 파일을 이용합니다.
- ℹ️ `Container Insights "대시보드에 추가" 기능 사용`
- ℹ️ `Bastion CI/CD 환경 구성하기 (디렉토리만 생성됩니다.)`
    - src/artifact -> /home/ec2-user/pipeline/artifact
    - imageDetail.json : <ACCOUNT_ID> 변경
    - taskdef.json
        1. 각 애플리케이션마다 생성된 task definition 이동
        2. JSON -> AWS CLI 입력 다운로드 클릭
        3. containerDefinitions[0].image 부분을 "<GREEN_IMAGE>" 혹은 "<RED_IMAGE>"로 대체
    - src/green.sh -> /home/ec2-user/pipeline/green.sh (<비번호> 변경)
    - src/red.sh -> /home/ec2-user/pipeline/red.sh (<비번호> 변경)