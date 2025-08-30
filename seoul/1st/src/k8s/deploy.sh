#!/bin/bash
set -e
aws configure set region ap-northeast-2
aws configure set output json
aws eks update-kubeconfig --name wsk-eks-cluster
export CLUSTER_NAME=wsk-eks-cluster
export AWS_DEFAULT_REGION=ap-northeast-2
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_PAGER=""
cd /home/ec2-user/k8s

echo "=== Starting K8s deployment ==="

# Add Helm repositories
helm repo add eks https://aws.github.io/eks-charts
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Create the missing Service Account
kubectl create serviceaccount aws-load-balancer-controller -n kube-system || true
kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
  eks.amazonaws.com/role-arn=arn:aws:iam::$AWS_ACCOUNT_ID:role/AmazonEKSLoadBalancerControllerRole || true

# Delete existing deployment if it exists
kubectl delete deployment aws-load-balancer-controller -n kube-system || true
sleep 10

# Install AWS Load Balancer Controller
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

# Wait for it to be ready
echo "Waiting for AWS Load Balancer Controller..."
for i in {1..10}; do
    if kubectl get pods -n kube-system | grep aws-load-balancer | grep Running; then
        echo "AWS Load Balancer Controller is running"
        break
    fi
    echo "Waiting... ($i/10)"
    sleep 30
done

# Create namespace
kubectl create namespace wsk25 || true

# Install External Secrets
helm upgrade --install external-secrets external-secrets/external-secrets \
  -n external-secrets \
  --create-namespace \
  --set installCRDs=true

# Wait for External Secrets
echo "Waiting for External Secrets..."
for i in {1..5}; do
    if kubectl get pods -n external-secrets | grep external-secrets | grep Running; then
        echo "External Secrets is running"
        break
    fi
    echo "Waiting... ($i/5)"
    sleep 30
done

# Create ServiceAccount for Secrets Manager
echo "Creating ServiceAccount..."
kubectl apply -f access-secrets-sa.yaml
sleep 20

echo "=== Applying K8s manifests ==="

# Apply SecretStore
kubectl apply -f secretstore.yaml
sleep 10

# Apply ExternalSecret
kubectl apply -f externalsecret.yaml
sleep 15

# Apply Services
kubectl apply -f green-svc.yaml
kubectl apply -f red-svc.yaml
sleep 10

# Delete existing deployments first to force recreation
echo "Deleting existing deployments..."
kubectl delete deployment green-deploy -n wsk25 || true
kubectl delete deployment red-deploy -n wsk25 || true
sleep 10

# Apply Deployments
echo "Creating new deployments..."
kubectl apply -f green-deploy.yaml
kubectl apply -f red-deploy.yaml
sleep 20

# Check if pods are starting
echo "Checking pod status..."
kubectl get pods -n wsk25
kubectl get events -n wsk25 --sort-by='.lastTimestamp'

# Debug pod issues
echo "Debugging pod issues..."
kubectl describe pods -n wsk25 | grep -A 10 -B 5 "Warning\|Error" || true

# Wait for pods to be ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=green -n wsk25 --timeout=600s || {
  echo "Green pods failed to start. Debugging..."
  kubectl describe pods -l app=green -n wsk25
  kubectl get events -n wsk25 --field-selector involvedObject.kind=Pod
  kubectl logs -l app=green -n wsk25 --tail=50 || true
}
kubectl wait --for=condition=ready pod -l app=red -n wsk25 --timeout=600s || {
  echo "Red pods failed to start. Debugging..."
  kubectl describe pods -l app=red -n wsk25
  kubectl get events -n wsk25 --field-selector involvedObject.kind=Pod
  kubectl logs -l app=red -n wsk25 --tail=50 || true
}

# Verify pods are running and ready
echo "Verifying pod readiness..."
kubectl get pods -n wsk25 -o wide
kubectl get endpoints -n wsk25

# Apply Ingress
echo "Applying Ingress..."
kubectl apply -f green-ig.yaml
kubectl apply -f red-ig.yaml
sleep 30

# Check Ingress status
echo "Checking Ingress status..."
kubectl get ingress -n wsk25
kubectl describe ingress -n wsk25

echo "=== Final Status ==="
kubectl get all -n wsk25
kubectl get secrets -n wsk25
kubectl get externalsecrets -n wsk25
kubectl get secretstores -n wsk25

# Check ALB Controller status
echo "=== ALB Controller Status ==="
kubectl get pods -n kube-system | grep aws-load-balancer
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=20 || true

echo "=== Installation - Argo CD ==="
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update argo

helm install argocd argo/argo-cd \
    --create-namespace \
    --namespace argocd \
    --values values.yaml
