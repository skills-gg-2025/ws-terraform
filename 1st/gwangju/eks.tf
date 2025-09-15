# Security Group for EKS Cluster
resource "aws_security_group" "eks_cluster" {
  name        = "gj2025-eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.app.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", "192.168.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gj2025-eks-cluster-sg"
  }
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster" {
  name = "gj2025-eks-cluster-role"

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

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# CloudWatch Log Group for EKS
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/gj2025-eks-cluster/cluster"
  retention_in_days = 7

  tags = {
    Name = "gj2025-eks-logs"
  }
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = "gj2025-eks-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.32"

  vpc_config {
    subnet_ids              = [aws_subnet.app_private_a.id, aws_subnet.app_private_b.id]
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_cloudwatch_log_group.eks
  ]

  tags = {
    Name = "gj2025-eks-cluster"
  }
}

# EKS Access Entry for Bastion Role
resource "aws_eks_access_entry" "bastion" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.bastion.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion_admin" {
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.bastion.arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion]
}

# Launch Template for Addon Nodes
resource "aws_launch_template" "addon_nodes" {
  name_prefix = "gj2025-eks-addon-node-"

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "gj2025-eks-addon-node"
    }
  }
}

# Launch Template for App Nodes
resource "aws_launch_template" "app_nodes" {
  name_prefix = "gj2025-eks-app-node-"

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "gj2025-eks-app-node"
    }
  }
}

# IAM Role for EKS Node Group
resource "aws_iam_role" "eks_node_group" {
  name = "gj2025-eks-node-group-role"

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

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

# EKS Addon Node Group
resource "aws_eks_node_group" "addon" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "gj2025-eks-addon-nodegroup"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = [aws_subnet.app_private_a.id, aws_subnet.app_private_b.id]

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 2
  }

  instance_types = ["t3.medium"]
  ami_type       = "BOTTLEROCKET_x86_64"

  labels = {
    "node" = "addon"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]

  tags = {
    Name = "gj2025-eks-addon-nodegroup"
  }

  launch_template {
    name    = aws_launch_template.addon_nodes.name
    version = aws_launch_template.addon_nodes.latest_version
  }
}

# EKS App Node Group
resource "aws_eks_node_group" "app" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "gj2025-eks-app-nodegroup"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = [aws_subnet.app_private_a.id, aws_subnet.app_private_b.id]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  instance_types = ["t3.medium"]
  ami_type       = "BOTTLEROCKET_x86_64"

  labels = {
    "node" = "app"
  }

  taint {
    key    = "node"
    value  = "app"
    effect = "NO_SCHEDULE"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]

  tags = {
    Name = "gj2025-eks-app-nodegroup"
  }

  launch_template {
    name    = aws_launch_template.app_nodes.name
    version = aws_launch_template.app_nodes.latest_version
  }
}

# EKS Add-ons
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"
  depends_on   = [aws_eks_node_group.addon]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
  depends_on   = [aws_eks_node_group.addon]
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"
  depends_on   = [aws_eks_node_group.addon]
}

# Deploy EKS applications after cluster is ready
resource "null_resource" "eks_deploy" {
  depends_on = [
    aws_eks_node_group.addon,
    aws_eks_node_group.app,
    null_resource.copy_k8s_files,
    null_resource.docker_build
  ]

  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for bastion setup to complete...'",
      "while [ ! -f /tmp/bastion-setup-complete ]; do",
      "  echo 'Bastion setup still in progress...'",
      "  sleep 10",
      "done",
      "echo 'Bastion setup completed! Waiting additional 30 seconds...'",
      "sleep 30",
      "echo 'Waiting for EKS cluster and nodegroups to be ready...'",
      "while true; do",
      "  CLUSTER_STATUS=$(aws eks describe-cluster --name gj2025-eks-cluster --query 'cluster.status' --output text 2>/dev/null)",
      "  if [ \"$CLUSTER_STATUS\" = \"ACTIVE\" ]; then",
      "    echo 'EKS cluster is active'",
      "    break",
      "  fi",
      "  echo 'Waiting for EKS cluster... Current status:' $CLUSTER_STATUS",
      "  sleep 20",
      "done",
      "while true; do",
      "  ADDON_NG_STATUS=$(aws eks describe-nodegroup --cluster-name gj2025-eks-cluster --nodegroup-name gj2025-eks-addon-nodegroup --query 'nodegroup.status' --output text 2>/dev/null)",
      "  APP_NG_STATUS=$(aws eks describe-nodegroup --cluster-name gj2025-eks-cluster --nodegroup-name gj2025-eks-app-nodegroup --query 'nodegroup.status' --output text 2>/dev/null)",
      "  if [ \"$ADDON_NG_STATUS\" = \"ACTIVE\" ] && [ \"$APP_NG_STATUS\" = \"ACTIVE\" ]; then",
      "    echo 'Both nodegroups are active'",
      "    break",
      "  fi",
      "  echo 'Waiting for nodegroups... Addon:' $ADDON_NG_STATUS 'App:' $APP_NG_STATUS",
      "  sleep 20",
      "done",
      "echo 'Waiting additional 30 seconds for nodes to be fully ready...'",
      "sleep 30",
      "echo 'Moving k8s files to home directory...'",
      "cp -r /tmp/k8s /home/ec2-user/",
      "chown -R ec2-user:ec2-user /home/ec2-user/k8s",
      "echo 'Running EKS deployment...'",
      "cd /home/ec2-user/k8s",
      "chmod +x deploy.sh",
      "./deploy.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("./gj2025-key.pem")
      host        = aws_eip.bastion.public_ip
      port        = 2222
      timeout     = "15m"
    }
  }
}