#!/bin/bash

# Build and push application image to ECR
echo "Building and pushing application image..."

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="eu-west-1"

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push application image
cd src
docker build -t skills-app skills-app
docker tag skills-app:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/skills-app:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/skills-app:latest

# Build and push fluent bit image
docker build -t skills-firelens skills-firelens
docker tag skills-firelens:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/skills-firelens:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/skills-firelens:latest

echo "Images pushed successfully!"
echo "App image: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/skills-app:latest"
echo "Fluent Bit image: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/skills-firelens:latest"
