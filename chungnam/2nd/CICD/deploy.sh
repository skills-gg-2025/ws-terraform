#!/bin/bash

# Variables
CLUSTER_NAME="wsc2025-cluster"
REGION="ap-southeast-1"
ALB_ROLE_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/AmazonEKSLoadBalancerControllerRole"

echo "Starting EKS deployment..."

# Wait for EKS cluster to be ready
echo "Waiting for EKS cluster to be ready..."
aws eks wait cluster-active --name $CLUSTER_NAME --region $REGION

# Update kubeconfig
echo "Updating kubeconfig..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Create namespace
echo "Creating wsc2025 namespace..."
kubectl create namespace wsc2025 --dry-run=client -o yaml | kubectl apply -f -

# Install AWS Load Balancer Controller
echo "Installing AWS Load Balancer Controller..."
kubectl create serviceaccount aws-load-balancer-controller -n kube-system --dry-run=client -o yaml | kubectl apply -f -
kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system eks.amazonaws.com/role-arn=$ALB_ROLE_ARN --overwrite

helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller || true

# Wait for load balancer controller to be ready
echo "Waiting for AWS Load Balancer Controller to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system

# Apply k8s manifests
echo "Applying Kubernetes manifests..."
kubectl apply -f /home/ec2-user/k8s_file/

echo "Deployment completed!"