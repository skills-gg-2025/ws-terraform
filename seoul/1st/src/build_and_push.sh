#!/bin/bash

# Get AWS Account ID and Region
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="ap-northeast-2"
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "Building and pushing images to ECR..."
echo "Account ID: $ACCOUNT_ID"
echo "Registry: $ECR_REGISTRY"

# Fix Dockerfiles
echo "Fixing Dockerfiles..."
sed -i 's/alpine:linux/alpine:latest/g' ./green/v1.0.0/Dockerfile
sed -i 's/alpine:linux/alpine:latest/g' ./green/v1.0.1/Dockerfile
sed -i 's/alpine:linux/alpine:latest/g' ./red/v1.0.0/Dockerfile
sed -i 's/alpine:linux/alpine:latest/g' ./red/v1.0.1/Dockerfile

# Login to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# Build and push Green App v1.0.0
echo "Building Green App v1.0.0..."
docker build -t wsk1/grapp:v1.0.0 ./green/v1.0.0/
docker tag wsk1/grapp:v1.0.0 $ECR_REGISTRY/wsk1/grapp:v1.0.0
docker push $ECR_REGISTRY/wsk1/grapp:v1.0.0

# Build and push Green App v1.0.1
echo "Building Green App v1.0.1..."
docker build -t wsk1/grapp:v1.0.1 ./green/v1.0.1/
docker tag wsk1/grapp:v1.0.1 $ECR_REGISTRY/wsk1/grapp:v1.0.1
docker push $ECR_REGISTRY/wsk1/grapp:v1.0.1

# Build and push Red App v1.0.0
echo "Building Red App v1.0.0..."
docker build -t wsk1/reapp:v1.0.0 ./red/v1.0.0/
docker tag wsk1/reapp:v1.0.0 $ECR_REGISTRY/wsk1/reapp:v1.0.0
docker push $ECR_REGISTRY/wsk1/reapp:v1.0.0

# Build and push Red App v1.0.1
echo "Building Red App v1.0.1..."
docker build -t wsk1/reapp:v1.0.1 ./red/v1.0.1/
docker tag wsk1/reapp:v1.0.1 $ECR_REGISTRY/wsk1/reapp:v1.0.1
docker push $ECR_REGISTRY/wsk1/reapp:v1.0.1

echo "All images built and pushed successfully!"