# 충남 2과제 CICD 배포
## Github
1. `wsc2025-argocd-repo` 퍼블릭 디렉토리 생성
2. `src/argocd_file` 경로에 있는 파일 모두 업로드
3. `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `PERSONAL_ACCESS_TOKEN(repo, workflow, read:org)` 시크릿 추가
4. `Settings -> Actions -> General` 아래의 `Read and write permissions` 으로 변경
## Argocd
1. `wsc2025-argo-app` 앱 생성
2. `Path ./manifest`로 설정
