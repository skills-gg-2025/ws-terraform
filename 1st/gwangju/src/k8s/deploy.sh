#!/bin/bash
set -e
set -o pipefail

TOTAL_STEPS=17

echo "[0/$TOTAL_STEPS] Cleaning up previous files..."
rm -f iam_policy.json ex_policy.json argocd-linux-amd64 kubectl-argo-rollouts-linux-amd64

echo "[1/$TOTAL_STEPS] Initializing ..."
aws configure set region ap-northeast-2
export CLUSTER_NAME="gj2025-eks-cluster"
export AWS_DEFAULT_REGION="ap-northeast-2"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Updating kubeconfig..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_DEFAULT_REGION


echo "[2/$TOTAL_STEPS] Checking Node Status ..."
sleep 30
for i in {1..5}; do
  if kubectl wait --for=condition=Ready nodes --all --timeout=60s; then
    break
  fi
  echo "Retry $i/5: Waiting for nodes to be ready..."
  sleep 30
done

echo "[3/$TOTAL_STEPS] Inserting DB Table ..."
RDS_PROXY_ENDPOINT=$(aws rds describe-db-proxy-endpoints --db-proxy-name gj2025-rds-proxy --query 'DBProxyEndpoints[0].Endpoint' --output text)
mysql -h $RDS_PROXY_ENDPOINT -P 3306 -u admin -pSkills53#\$% day1 < /tmp/day1_table_v1.sql

echo "[4/$TOTAL_STEPS] Setting EKS Environments ..."
kubectl create namespace skills --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace amazon-cloudwatch --dry-run=client -o yaml | kubectl apply -f -

helm repo add eks https://aws.github.io/eks-charts
helm repo add external-secrets https://charts.external-secrets.io
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo "[5/$TOTAL_STEPS] Creating OIDC provider ..."
eksctl utils associate-iam-oidc-provider --region=$AWS_DEFAULT_REGION --cluster=$CLUSTER_NAME --approve || echo "OIDC provider already exists"

echo "[6/$TOTAL_STEPS] Installing Load Balancer controller ..."
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.13.3/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json 2>/dev/null || echo "Policy already exists"

eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve --override-existing-serviceaccounts

echo "[7/$TOTAL_STEPS] Installing External-secrets ..."
helm upgrade --install external-secrets \
   external-secrets/external-secrets \
   -n external-secrets \
   --create-namespace \
   --set installCRDs=true \
   --set webhook.port=9443 &

wait

echo "[8/$TOTAL_STEPS] Validation 1"
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

echo "Waiting for ALB Controller to be ready..."
for i in {1..3}; do
  if kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system; then
    break
  fi
  echo "Retry $i/3: ALB Controller not ready, waiting..."
  sleep 60
done

echo "Waiting for External Secrets to be ready..."
for i in {1..3}; do
  if kubectl wait --for=condition=available --timeout=300s deployment/external-secrets -n external-secrets; then
    break
  fi
  echo "Retry $i/3: External Secrets not ready, waiting..."
  sleep 60
done

echo "[9/$TOTAL_STEPS] still Installing External-secrets ..."
cat > ex_policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-policy --policy-name secretsmanager-policy --policy-document file://ex_policy.json 2>/dev/null || echo "Policy already exists"
POLICY_ARN=$(aws iam get-policy --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/secretsmanager-policy --query Policy.Arn --output text)

eksctl create iamserviceaccount \
  --name gj-secrets \
  --cluster $CLUSTER_NAME \
  --namespace skills \
  --attach-policy-arn $POLICY_ARN \
  --approve --override-existing-serviceaccounts

echo "[10/$TOTAL_STEPS] Applying External-secrets ..."
rm -rf app/deployment.yaml
envsubst < app/deployment.yaml.tpl > app/deployment.yaml

kubectl apply -f secretstore.yaml
kubectl apply -f externalsecret.yaml

echo "[11/$TOTAL_STEPS] Installing ArgoCD CLI..."
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

echo "[12/$TOTAL_STEPS] Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install argocd argo/argo-cd \
    --namespace argocd \
    --values values.yaml &

helm upgrade --install rollouts argo/argo-rollouts -n argocd &

wait

kubectl -n argocd patch secret argocd-secret \
  --type merge \
  -p "$(echo -n '{"data":{"admin.password":"' ; htpasswd -nbBC 10 "" 'Skills53' | tr -d ':\n' | base64 -w0 ; echo '"}}')" \
&& kubectl -n argocd rollout restart deployment argocd-server

echo "[13/$TOTAL_STEPS] Installing Argo Rollouts kubectl plugin..."
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x ./kubectl-argo-rollouts-linux-amd64
sudo mv ./kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

echo "[14/$TOTAL_STEPS] Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=180s deployment/argocd-server -n argocd

echo "[15/$TOTAL_STEPS] Applying FluentBit configuration..."
# Create IAM role for FluentBit
cat > fluent-bit-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-policy --policy-name FluentBitCloudWatchLogsPolicy --policy-document file://fluent-bit-policy.json 2>/dev/null || echo "Policy already exists"

eksctl create iamserviceaccount \
  --name fluent-bit \
  --cluster $CLUSTER_NAME \
  --namespace amazon-cloudwatch \
  --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/FluentBitCloudWatchLogsPolicy \
  --approve --override-existing-serviceaccounts

kubectl apply -f fluent-bit-cluster-info.yaml
kubectl apply -f configmap-green.yaml
kubectl apply -f configmap-red.yaml
kubectl apply -f daemonset.yaml

echo "[16/$TOTAL_STEPS] Applying application configurations..."
kubectl apply -f app/

echo "[$TOTAL_STEPS/$TOTAL_STEPS] EKS deployment completed successfully!"