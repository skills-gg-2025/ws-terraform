#!/bin/bash
set -e

# Configure AWS and kubectl
aws configure set region ap-northeast-2
aws configure set output json
aws eks update-kubeconfig --name wsk-eks-cluster
export CLUSTER_NAME=wsk-eks-cluster
export AWS_DEFAULT_REGION=ap-northeast-2
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=== Fixing ServiceAccount Issue ==="

# Create ServiceAccount manually
kubectl create serviceaccount access-secrets -n wsk25 || true

# Get the OIDC issuer URL
OIDC_ISSUER=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text)
OIDC_ID=$(echo $OIDC_ISSUER | cut -d '/' -f 5)

# Create IAM role for ServiceAccount
cat > /tmp/trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/oidc.eks.ap-northeast-2.amazonaws.com/id/$OIDC_ID"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.ap-northeast-2.amazonaws.com/id/$OIDC_ID:sub": "system:serviceaccount:wsk25:access-secrets",
          "oidc.eks.ap-northeast-2.amazonaws.com/id/$OIDC_ID:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

# Create or update IAM role
aws iam create-role --role-name wsk-access-secrets-role --assume-role-policy-document file:///tmp/trust-policy.json || true
aws iam attach-role-policy --role-name wsk-access-secrets-role --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/secretsmanager-policy || true

# Annotate ServiceAccount
kubectl annotate serviceaccount access-secrets -n wsk25 \
  eks.amazonaws.com/role-arn=arn:aws:iam::$AWS_ACCOUNT_ID:role/wsk-access-secrets-role --overwrite

echo "=== ServiceAccount fixed! ==="

# Restart deployments
kubectl rollout restart deployment green-deploy -n wsk25 || true
kubectl rollout restart deployment red-deploy -n wsk25 || true

echo "=== Checking status ==="
kubectl get pods -n wsk25
kubectl get serviceaccounts -n wsk25
kubectl get secrets -n wsk25