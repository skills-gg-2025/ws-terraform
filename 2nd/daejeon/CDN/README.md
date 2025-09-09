# Edge DRM with CloudFront

이 모듈은 CloudFront, Lambda@Edge, CloudFront Function을 사용하여 Edge DRM을 구현합니다.

## 구성 요소

- **S3 Bucket**: `web-drm-bucket-<3자리 숫자>`로 미디어 파일 저장
- **CloudFront Distribution**: `web-cdn` - DRM 보호된 콘텐츠 배포
- **CloudFront Function**: `web-cdn-function` - Query String에서 DRM 토큰 추출
- **Lambda@Edge**: `web-drm-function` - DRM 토큰 검증

## DRM 토큰

- 유효한 토큰: `drm-cloud`
- 캐시 TTL: 60초
- 토큰별 캐시 분리

## 사용법

```bash
terraform init
terraform plan
terraform apply
```

## 테스트

CloudFront 도메인을 통해 다음과 같이 접근:
- 유효한 토큰: `https://<cloudfront-domain>/cloud.mp4?token=drm-cloud`
- 무효한 토큰: `https://<cloudfront-domain>/cloud.mp4?token=invalid` (403 응답)