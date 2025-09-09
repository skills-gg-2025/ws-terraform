# ECS and CloudWatch Monitoring System

This project implements a monitoring system using ECS and CloudWatch for a Flask application in the ap-northeast-1 region.

## Architecture

- **VPC**: 10.0.0.0/16 with public and private subnets across two availability zones
- **ECS**: Fargate-based cluster with the Flask application running in containers
- **ALB**: External Application Load Balancer for routing traffic to the containers
- **CloudWatch**: Dashboard with widgets for monitoring application performance

## Deployment Instructions

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform installed
- Docker installed (for building and pushing the container image)

### Deployment Steps

1. Initialize Terraform:
   ```
   terraform init
   ```

2. Apply the Terraform configuration:
   ```
   terraform apply
   ```

3. Build and push the Docker image:
   ```
   cd src
   aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url)
   docker build -t wsi-app .
   docker tag wsi-app:latest $(terraform output -raw ecr_repository_url):latest
   docker push $(terraform output -raw ecr_repository_url):latest
   ```

4. Update the ECS service to use the new image:
   ```
   aws ecs update-service --cluster wsi-app-cluster --service wsi-app-service --force-new-deployment --region ap-northeast-1
   ```

## Monitoring

The CloudWatch Dashboard (wsi-dashboard) includes the following widgets:

- **wsi-success**: Shows successful HTTP requests (2XX)
- **wsi-fail**: Shows failed HTTP requests (4XX)
- **wsi-sli**: Displays the success rate as a gauge
- **wsi-p90-p96-p99**: Shows the p90, p95, and p99 latency metrics

## Application Endpoints

- `/hello`: Returns a greeting message with random string
- `/healthcheck`: Health check endpoint
- `/test_latency`: Simulates random latency between 0.01 and 1.0 seconds
- `/latency_stats`: Provides statistics about recorded latencies