# EKS Cluster Service Role
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

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
  role       = aws_iam_role.eks_cluster_role.name
}

# EKS Node Group Role
resource "aws_iam_role" "eks_node_group_role" {
  name = "eks-node-group-role"

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
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

# Security Groups for EKS
resource "aws_security_group" "eks_cluster_sg" {
  name        = "eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.dev_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-cluster-sg"
  }
}

resource "aws_security_group" "prod_eks_cluster_sg" {
  name        = "prod-eks-cluster-sg"
  description = "Security group for Prod EKS cluster"
  vpc_id      = aws_vpc.prod_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.dev_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "prod-eks-cluster-sg"
  }
}

# Dev EKS Cluster
resource "aws_eks_cluster" "dev_cluster" {
  name     = "dev-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.33"

  vpc_config {
    subnet_ids              = [aws_subnet.dev_private_1.id, aws_subnet.dev_private_2.id]
    security_group_ids      = [aws_security_group.eks_cluster_sg.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  access_config {
    authentication_mode = "API"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]

  tags = {
    Name = "dev-cluster"
  }
}

# Prod EKS Cluster
resource "aws_eks_cluster" "prod_cluster" {
  name     = "prod-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.33"

  vpc_config {
    subnet_ids              = [aws_subnet.prod_private_1.id, aws_subnet.prod_private_2.id]
    security_group_ids      = [aws_security_group.prod_eks_cluster_sg.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  access_config {
    authentication_mode = "API"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]

  tags = {
    Name = "prod-cluster"
  }
}

# Dev EKS Node Group
resource "aws_eks_node_group" "dev_node_group" {
  cluster_name    = aws_eks_cluster.dev_cluster.name
  node_group_name = "dev-node-group"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = [aws_subnet.dev_private_1.id, aws_subnet.dev_private_2.id]
  instance_types  = ["t3.medium"]
  ami_type        = "AL2023_x86_64_STANDARD"
  capacity_type   = "ON_DEMAND"

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]

  tags = {
    Name = "dev-node-group"
  }
}

# Prod EKS Node Group
resource "aws_eks_node_group" "prod_node_group" {
  cluster_name    = aws_eks_cluster.prod_cluster.name
  node_group_name = "prod-node-group"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = [aws_subnet.prod_private_1.id, aws_subnet.prod_private_2.id]
  instance_types  = ["t3.medium"]
  ami_type        = "AL2023_x86_64_STANDARD"
  capacity_type   = "ON_DEMAND"

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]

  tags = {
    Name = "prod-node-group"
  }
}

resource "aws_eks_addon" "dev_coredns" {
  cluster_name                = aws_eks_cluster.dev_cluster.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = null

  depends_on = [
    aws_eks_node_group.dev_node_group
  ]

  tags = {
    Name = "dev-coredns-addon"
  }
}

resource "aws_eks_addon" "dev_kube_proxy" {
  cluster_name                = aws_eks_cluster.dev_cluster.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = null

  depends_on = [
    aws_eks_node_group.dev_node_group
  ]

  tags = {
    Name = "dev-kube-proxy-addon"
  }
}

resource "aws_eks_addon" "dev_vpc_cni" {
  cluster_name                = aws_eks_cluster.dev_cluster.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.dev_node_group
  ]

  tags = {
    Name = "dev-vpc-cni-addon"
  }
}

resource "aws_eks_access_entry" "dev_bastion" {
  cluster_name  = aws_eks_cluster.dev_cluster.name
  principal_arn = aws_iam_role.bastion_role.arn
}

resource "aws_eks_access_policy_association" "dev_bastion" {
  cluster_name  = aws_eks_cluster.dev_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.bastion_role.arn

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_addon" "prod_coredns" {
  cluster_name                = aws_eks_cluster.prod_cluster.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = null

  depends_on = [
    aws_eks_node_group.prod_node_group
  ]

  tags = {
    Name = "prod-coredns-addon"
  }
}

resource "aws_eks_addon" "prod_kube_proxy" {
  cluster_name                = aws_eks_cluster.prod_cluster.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = null

  depends_on = [
    aws_eks_node_group.prod_node_group
  ]

  tags = {
    Name = "prod-kube-proxy-addon"
  }
}

resource "aws_eks_addon" "prod_vpc_cni" {
  cluster_name                = aws_eks_cluster.prod_cluster.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.prod_node_group
  ]

  tags = {
    Name = "prod-vpc-cni-addon"
  }
}

resource "aws_eks_access_entry" "prod_bastion" {
  cluster_name  = aws_eks_cluster.prod_cluster.name
  principal_arn = aws_iam_role.bastion_role.arn
}

resource "aws_eks_access_policy_association" "prod_bastion" {
  cluster_name  = aws_eks_cluster.prod_cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.bastion_role.arn

  access_scope {
    type = "cluster"
  }
}