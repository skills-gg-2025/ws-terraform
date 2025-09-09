# OpenSearch Domain
resource "aws_opensearch_domain" "skills_opensearch" {
  domain_name    = "skills-opensearch"
  engine_version = "OpenSearch_2.19"

  cluster_config {
    instance_type            = "r7g.medium.search"
    instance_count           = 2
    dedicated_master_enabled = true
    dedicated_master_type    = "r7g.medium.search"
    dedicated_master_count   = 3
    zone_awareness_enabled   = true

    zone_awareness_config {
      availability_zone_count = 2
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = 20
  }

  # VPC 설정 제거하여 퍼블릭 접근 허용
  # vpc_options 블록을 제거

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    anonymous_auth_enabled         = false
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = "admin"
      master_user_password = "Skill53##"
    }
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_logs.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_search_logs.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_es_logs.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  tags = {
    Name = "skills-opensearch"
  }

  depends_on = [
    aws_iam_service_linked_role.opensearch,
    aws_cloudwatch_log_resource_policy.opensearch_log_policy
  ]
}



# CloudWatch Log Groups for OpenSearch
resource "aws_cloudwatch_log_group" "opensearch_logs" {
  name              = "/aws/opensearch/domains/skills-opensearch/index-slow"
  retention_in_days = 7

  tags = {
    Name = "skills-opensearch-index-slow-logs"
  }
}

resource "aws_cloudwatch_log_group" "opensearch_search_logs" {
  name              = "/aws/opensearch/domains/skills-opensearch/search-slow"
  retention_in_days = 7

  tags = {
    Name = "skills-opensearch-search-slow-logs"
  }
}

resource "aws_cloudwatch_log_group" "opensearch_es_logs" {
  name              = "/aws/opensearch/domains/skills-opensearch/application"
  retention_in_days = 7

  tags = {
    Name = "skills-opensearch-application-logs"
  }
}

# CloudWatch Log Resource Policy for OpenSearch
resource "aws_cloudwatch_log_resource_policy" "opensearch_log_policy" {
  policy_name = "opensearch-log-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "es.amazonaws.com"
        }
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# OpenSearch Service Linked Role
resource "aws_iam_service_linked_role" "opensearch" {
  aws_service_name = "es.amazonaws.com"
  description      = "Service linked role for Amazon OpenSearch Service"
}

# OpenSearch Domain Access Policy
resource "aws_opensearch_domain_policy" "skills_opensearch_policy" {
  domain_name = aws_opensearch_domain.skills_opensearch.domain_name

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = "es:*"
        Resource = "${aws_opensearch_domain.skills_opensearch.arn}/*"
      }
    ]
  })
}
