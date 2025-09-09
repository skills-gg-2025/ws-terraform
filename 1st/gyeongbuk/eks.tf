# EKS Cluster IAM Role
resource "aws_iam_role" "eks_cluster_role" {
  name = "skills-eks-cluster-role"

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

  tags = {
    Name = "skills-eks-cluster-role"
  }
}

# Attach EKS Cluster Service Role Policy
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}



# EKS Security Group
resource "aws_security_group" "eks_cluster_sg" {
  name        = "skills-eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.app.id

  # Allow HTTPS from Bastion
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/24"] # Hub subnet A where bastion is located
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "skills-eks-cluster-sg"
  }
}

# EKS Cluster
resource "aws_eks_cluster" "skills_cluster" {
  name     = "skills-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.32"

  vpc_config {
    subnet_ids              = [aws_subnet.workload_subnet_a.id, aws_subnet.workload_subnet_b.id]
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = [aws_security_group.eks_cluster_sg.id]
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.secrets_key.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_cloudwatch_log_group.eks_cluster_logs
  ]

  tags = {
    Name = "skills-eks-cluster"
  }
}

# CloudWatch Log Group for EKS Cluster
resource "aws_cloudwatch_log_group" "eks_cluster_logs" {
  name              = "/aws/eks/skills-eks-cluster/cluster"
  retention_in_days = 7

  tags = {
    Name = "skills-eks-cluster-logs"
  }
}

# EKS Node Group IAM Role
resource "aws_iam_role" "eks_node_group_role" {
  name = "skills-eks-nodegroup-role"

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

  tags = {
    Name = "skills-eks-nodegroup-role"
  }
}

# Attach required policies to Node Group IAM Role
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

# Launch Template for Application Node Group
resource "aws_launch_template" "app_node_template" {
  name_prefix = "skills-app-node-template-"

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "skills-app-node"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name = "skills-app-node-template"
  }
}

# Launch Template for Addon Node Group
resource "aws_launch_template" "addon_node_template" {
  name_prefix = "skills-addon-node-template-"

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "skills-addon-node"
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name = "skills-addon-node-template"
  }
}



# Application Managed Node Group
resource "aws_eks_node_group" "app_node_group" {
  cluster_name    = aws_eks_cluster.skills_cluster.name
  node_group_name = "skills-app-nodegroup"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = [aws_subnet.workload_subnet_a.id, aws_subnet.workload_subnet_b.id]

  capacity_type  = "ON_DEMAND"
  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.app_node_template.id
    version = aws_launch_template.app_node_template.latest_version
  }

  labels = {
    skills = "app"
  }

  taint {
    key    = "skills"
    value  = "app"
    effect = "NO_SCHEDULE"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_registry_policy,
  ]
}

# Addon Managed Node Group
resource "aws_eks_node_group" "addon_node_group" {
  cluster_name    = aws_eks_cluster.skills_cluster.name
  node_group_name = "skills-addon-nodegroup"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = [aws_subnet.workload_subnet_a.id, aws_subnet.workload_subnet_b.id]

  capacity_type  = "ON_DEMAND"
  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.addon_node_template.id
    version = aws_launch_template.addon_node_template.latest_version
  }

  labels = {
    skills = "addon"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_registry_policy,
  ]
}

# Fargate Profile IAM Role
resource "aws_iam_role" "eks_fargate_role" {
  name = "skills-eks-fargate-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks-fargate-pods.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "skills-eks-fargate-role"
  }
}

# Attach Fargate Pod Execution Role Policy
resource "aws_iam_role_policy_attachment" "eks_fargate_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.eks_fargate_role.name
}

# Fargate Profile for CoreDNS
resource "aws_eks_fargate_profile" "coredns_profile" {
  cluster_name           = aws_eks_cluster.skills_cluster.name
  fargate_profile_name   = "skills-fargate-profile"
  pod_execution_role_arn = aws_iam_role.eks_fargate_role.arn
  subnet_ids             = [aws_subnet.workload_subnet_a.id, aws_subnet.workload_subnet_b.id]

  selector {
    namespace = "kube-system"
    labels = {
      k8s-app = "kube-dns"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.eks_fargate_policy]

  tags = {
    Name = "skills-fargate-profile"
  }
}

# EKS Addon - CoreDNS
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.skills_cluster.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = null

  depends_on = [
    aws_eks_fargate_profile.coredns_profile,
    aws_eks_node_group.app_node_group,
    aws_eks_node_group.addon_node_group
  ]

  tags = {
    Name = "skills-coredns-addon"
  }
}

# EKS Addon - kube-proxy
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.skills_cluster.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = null

  depends_on = [
    aws_eks_node_group.app_node_group,
    aws_eks_node_group.addon_node_group
  ]

  tags = {
    Name = "skills-kube-proxy-addon"
  }
}

# EKS Addon - VPC CNI
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.skills_cluster.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.app_node_group,
    aws_eks_node_group.addon_node_group
  ]

  tags = {
    Name = "skills-vpc-cni-addon"
  }
}


resource "aws_eks_access_entry" "bastion" {
  cluster_name  = aws_eks_cluster.skills_cluster.name
  principal_arn = aws_iam_role.bastion_role.arn
}

resource "aws_eks_access_policy_association" "bastion" {
  cluster_name  = aws_eks_cluster.skills_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.bastion_role.arn

  access_scope {
    type = "cluster"
  }
}
