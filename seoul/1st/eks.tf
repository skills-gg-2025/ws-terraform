# EKS Control Plane Security Group
resource "aws_security_group" "wsk_eks_control_plane_sg" {
  name        = "wsk-eks-control-plane-sg"
  description = "wsk-eks-control-plane-sg"
  vpc_id      = aws_vpc.wsk_app.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.76.10.100/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wsk-eks-control-plane-sg"
  }
}

# EKS Cluster Service Role
resource "aws_iam_role" "wsk_eks_cluster_role" {
  name = "wsk-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "wsk_eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.wsk_eks_cluster_role.name
}

# EKS Cluster
resource "aws_eks_cluster" "wsk_eks_cluster" {
  name     = "wsk-eks-cluster"
  role_arn = aws_iam_role.wsk_eks_cluster_role.arn
  version  = "1.32"

  vpc_config {
    subnet_ids              = [aws_subnet.wsk_app_priv_a.id, aws_subnet.wsk_app_priv_b.id]
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = [aws_security_group.wsk_eks_control_plane_sg.id]
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.wsk_key.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  upgrade_policy {
    support_type = "STANDARD"
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  depends_on = [
    aws_iam_role_policy_attachment.wsk_eks_cluster_policy,
  ]

  tags = {
    Name = "wsk-eks-cluster"
  }
}

# EKS Access Entry for Bastion Role
resource "aws_eks_access_entry" "bastion_access" {
  cluster_name      = aws_eks_cluster.wsk_eks_cluster.name
  principal_arn     = aws_iam_role.wsk_bastion_profile.arn
  kubernetes_groups = []
  type              = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion_admin_policy" {
  cluster_name  = aws_eks_cluster.wsk_eks_cluster.name
  principal_arn = aws_iam_role.wsk_bastion_profile.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}



# EKS Node Group Role
resource "aws_iam_role" "wsk_eks_node_role" {
  name = "wsk-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "wsk_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.wsk_eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "wsk_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.wsk_eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "wsk_eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.wsk_eks_node_role.name
}

# Default Node Group
resource "aws_eks_node_group" "wsk_eks_ng_default" {
  cluster_name    = aws_eks_cluster.wsk_eks_cluster.name
  node_group_name = "wsk-eks-ng-default"
  node_role_arn   = aws_iam_role.wsk_eks_node_role.arn
  subnet_ids      = [aws_subnet.wsk_app_priv_a.id, aws_subnet.wsk_app_priv_b.id]

  capacity_type  = "ON_DEMAND"
  ami_type       = "BOTTLEROCKET_x86_64"
  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  labels = {
    role = "default"
  }

  tags = {
    Name = "wsk-eks-ng-default"
    app  = "wsk-eks-ng-default"
  }

  depends_on = [
    aws_iam_role_policy_attachment.wsk_eks_worker_node_policy,
    aws_iam_role_policy_attachment.wsk_eks_cni_policy,
    aws_iam_role_policy_attachment.wsk_eks_container_registry_policy,
  ]
}

# Application Node Group
resource "aws_eks_node_group" "wsk_eks_ng_app" {
  cluster_name    = aws_eks_cluster.wsk_eks_cluster.name
  node_group_name = "wsk-eks-ng-app"
  node_role_arn   = aws_iam_role.wsk_eks_node_role.arn
  subnet_ids      = [aws_subnet.wsk_app_priv_a.id, aws_subnet.wsk_app_priv_b.id]

  capacity_type  = "ON_DEMAND"
  ami_type       = "BOTTLEROCKET_x86_64"
  instance_types = ["c5.xlarge"]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  labels = {
    role = "app"
  }

  taint {
    key    = "role"
    value  = "app"
    effect = "NO_SCHEDULE"
  }

  tags = {
    Name = "wsk-eks-ng-app"
    app  = "wsk-eks-ng-app"
  }

  depends_on = [
    aws_iam_role_policy_attachment.wsk_eks_worker_node_policy,
    aws_iam_role_policy_attachment.wsk_eks_cni_policy,
    aws_iam_role_policy_attachment.wsk_eks_container_registry_policy,
  ]
}

# EKS OIDC Identity Provider
data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.wsk_eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.wsk_eks_cluster.identity[0].oidc[0].issuer
}

# ALB Controller IAM Role
resource "aws_iam_role" "alb_controller_role" {
  name = "AmazonEKSLoadBalancerControllerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks_oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.wsk_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(aws_eks_cluster.wsk_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# ALB Controller Policy
resource "aws_iam_policy" "alb_controller_policy" {
  name = "AWSLoadBalancerControllerIAMPolicy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:GetManagedPrefixListEntries",
          "ec2:DescribeCoipPools",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerAttributes",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:DescribeProtection",
          "shield:GetSubscriptionState",
          "shield:DescribeSubscription",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = "CreateSecurityGroup"
          }
          Null = {
            "aws:RequestedRegion" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          Null = {
            "aws:RequestedRegion" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestedRegion" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestedRegion" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          Null = {
            "aws:RequestedRegion" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteTargetGroup"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestedRegion" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:ModifyRule"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "alb_controller_policy" {
  policy_arn = aws_iam_policy.alb_controller_policy.arn
  role       = aws_iam_role.alb_controller_role.name
}

# EKS Addons
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.wsk_eks_cluster.name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.wsk_eks_cluster.name
  addon_name   = "coredns"
  depends_on   = [aws_eks_node_group.wsk_eks_ng_default]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.wsk_eks_cluster.name
  addon_name   = "kube-proxy"
}

# Secrets Manager Policy for External Secrets
resource "aws_iam_policy" "secretsmanager_policy" {
  name = "secretsmanager-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = [
          "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:rds!db-*",
          "arn:aws:secretsmanager:ap-northeast-2:${data.aws_caller_identity.current.account_id}:secret:wsk-db-url-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.wsk_key.arn
      }
    ]
  })
}

# ServiceAccount IAM Role for External Secrets
resource "aws_iam_role" "access_secrets_role" {
  name = "wsk-access-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks_oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.wsk_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:wsk25:access-secrets"
            "${replace(aws_eks_cluster.wsk_eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "access_secrets_policy" {
  policy_arn = aws_iam_policy.secretsmanager_policy.arn
  role       = aws_iam_role.access_secrets_role.name
}

# Generate K8s manifests with dynamic values
resource "local_file" "externalsecret_yaml" {
  content = templatefile("${path.module}/src/k8s/externalsecret.yaml.tpl", {
    rds_secret_name = aws_db_instance.wsk_rds_cluster.master_user_secret[0].secret_arn
    db_url_secret_name = aws_secretsmanager_secret.db_url.name
  })
  filename = "${path.module}/src/k8s/externalsecret.yaml"
}

resource "local_file" "green_deploy_yaml" {
  content = templatefile("${path.module}/src/k8s/green-deploy.yaml.tpl", {
    account_id = data.aws_caller_identity.current.account_id
  })
  filename = "${path.module}/src/k8s/green-deploy.yaml"
}

resource "local_file" "red_deploy_yaml" {
  content = templatefile("${path.module}/src/k8s/red-deploy.yaml.tpl", {
    account_id = data.aws_caller_identity.current.account_id
  })
  filename = "${path.module}/src/k8s/red-deploy.yaml"
}

resource "local_file" "im_policy_json" {
  content = templatefile("${path.module}/src/k8s/im_policy.json.tpl", {
    account_id = data.aws_caller_identity.current.account_id
    kms_key_arn = aws_kms_key.wsk_key.arn
  })
  filename = "${path.module}/src/k8s/im_policy.json"
}

resource "local_file" "access_secrets_sa_yaml" {
  content = <<-EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: access-secrets
  namespace: wsk25
  annotations:
    eks.amazonaws.com/role-arn: ${aws_iam_role.access_secrets_role.arn}
EOF
  filename = "${path.module}/src/k8s/access-secrets-sa.yaml"
}



# Copy K8s files and execute deploy script
resource "null_resource" "deploy_k8s" {
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("wsk-bastion-key.pem")
    host        = aws_eip.wsk_bastion_eip.public_ip
    port        = 2202
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/ec2-user/k8s"
    ]
  }

  provisioner "file" {
    source      = "src/k8s/"
    destination = "/home/ec2-user/k8s/"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ec2-user/k8s/deploy.sh",
      "cd /home/ec2-user/k8s && ./deploy.sh"
    ]
  }

  depends_on = [
    aws_eks_node_group.wsk_eks_ng_default,
    aws_eks_node_group.wsk_eks_ng_app,
    local_file.externalsecret_yaml,
    local_file.green_deploy_yaml,
    local_file.red_deploy_yaml,
    local_file.im_policy_json,
    local_file.access_secrets_sa_yaml,
    aws_iam_role.access_secrets_role,
    aws_iam_role_policy_attachment.access_secrets_policy
  ]
}