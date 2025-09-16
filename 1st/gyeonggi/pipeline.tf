# S3 Buckets for Pipeline Artifacts
resource "aws_s3_bucket" "green_artifacts" {
  bucket        = "ws25-cd-green-artifact-${var.number}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "green_versioning" {
  bucket = aws_s3_bucket.green_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket" "red_artifacts" {
  bucket        = "ws25-cd-red-artifact-${var.number}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "red_versioning" {
  bucket = aws_s3_bucket.red_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Notifications
resource "aws_s3_bucket_notification" "green_bucket_notification" {
  bucket      = aws_s3_bucket.green_artifacts.id
  eventbridge = true
}

resource "aws_s3_bucket_notification" "red_bucket_notification" {
  bucket      = aws_s3_bucket.red_artifacts.id
  eventbridge = true
}



# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "ws25-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

data "aws_iam_policy_document" "codedeploy_ecs" {
  statement {
    sid       = "AllowCodeDeployDeploymentActions"
    effect    = "Allow"
    resources = ["arn:aws:codedeploy:*:${data.aws_caller_identity.current.account_id}:deploymentgroup:*"]

    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetDeployment",
    ]
  }

  statement {
    sid    = "AllowCodeDeployApplicationActions"
    effect = "Allow"

    resources = [
      "arn:aws:codedeploy:*:${data.aws_caller_identity.current.account_id}:application:*"
    ]

    actions = [
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:RegisterApplicationRevision",
    ]
  }

  statement {
    sid       = "AllowCodeDeployDeploymentConfigAccess"
    effect    = "Allow"
    resources = ["arn:aws:codedeploy:*:${data.aws_caller_identity.current.account_id}:deploymentconfig:*"]
    actions   = ["codedeploy:GetDeploymentConfig"]
  }

  statement {
    sid       = "AllowECSRegisterTaskDefinition"
    effect    = "Allow"
    resources = ["*"]
    actions   = ["ecs:RegisterTaskDefinition"]
  }

  statement {
    sid    = "AllowPassRoleToECS"
    effect = "Allow"

    resources = [
      aws_iam_role.ecs_task_execution_role.arn,
      aws_iam_role.ecs_task_role.arn,
    ]

    actions = ["iam:PassRole"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"

      values = [
        "ecs.amazonaws.com",
        "ecs-tasks.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role_policy" "codepipeline_ecs" {
  name   = "codedeploy_ecs_policy"
  role   = aws_iam_role.codepipeline_role.name
  policy = data.aws_iam_policy_document.codedeploy_ecs.json
}

resource "aws_iam_role_policy_attachment" "S3FullAccess" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# IAM Role for CodeDeploy
resource "aws_iam_role" "codedeploy_role" {
  name = "ws25-codedeploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy_role_policy" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# IAM Role for CloudWatch Events
resource "aws_iam_role" "cloudwatch_events_role" {
  name = "ws25-cloudwatch-events-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudwatch_events_policy" {
  name = "ws25-cloudwatch-events-policy"
  role = aws_iam_role.cloudwatch_events_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codepipeline:StartPipelineExecution"
        ]
        Resource = [
          aws_codepipeline.green_pipeline.arn,
          aws_codepipeline.red_pipeline.arn
        ]
      }
    ]
  })
}

# CodeDeploy Applications
resource "aws_codedeploy_app" "green_app" {
  compute_platform = "ECS"
  name             = "ws25-cd-green-app"
}

resource "aws_codedeploy_app" "red_app" {
  compute_platform = "ECS"
  name             = "ws25-cd-red-app"
}

# CodeDeploy Deployment Groups
resource "aws_codedeploy_deployment_group" "green_dg" {
  app_name               = aws_codedeploy_app.green_app.name
  deployment_group_name  = "ws25-cd-green-dg"
  service_role_arn       = aws_iam_role.codedeploy_role.arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 0
    }

    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.green.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.app_alb_listener.arn]
      }

      target_group {
        name = aws_lb_target_group.green_primary.name
      }

      target_group {
        name = aws_lb_target_group.green_sub.name
      }
    }
  }
}

resource "aws_codedeploy_deployment_group" "red_dg" {
  app_name               = aws_codedeploy_app.red_app.name
  deployment_group_name  = "ws25-cd-red-dg"
  service_role_arn       = aws_iam_role.codedeploy_role.arn
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 0
    }

    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.red.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.app_alb_listener.arn]
      }

      target_group {
        name = aws_lb_target_group.red_primary.name
      }

      target_group {
        name = aws_lb_target_group.red_sub.name
      }
    }
  }
}

# CodePipeline for Green
resource "aws_codepipeline" "green_pipeline" {
  name     = "ws25-cd-green-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.green_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        S3Bucket             = aws_s3_bucket.green_artifacts.bucket
        S3ObjectKey          = "artifact.zip"
        PollForSourceChanges = false
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ApplicationName                = aws_codedeploy_app.green_app.name
        DeploymentGroupName            = aws_codedeploy_deployment_group.green_dg.deployment_group_name
        TaskDefinitionTemplateArtifact = "source_output"
        AppSpecTemplateArtifact        = "source_output"
        Image1ArtifactName             = "source_output"
        Image1ContainerName            = "GREEN_IMAGE"
      }
    }
  }
}

# CodePipeline for Red
resource "aws_codepipeline" "red_pipeline" {
  name     = "ws25-cd-red-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.red_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        S3Bucket             = aws_s3_bucket.red_artifacts.bucket
        S3ObjectKey          = "artifact.zip"
        PollForSourceChanges = false
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ApplicationName                = aws_codedeploy_app.red_app.name
        DeploymentGroupName            = aws_codedeploy_deployment_group.red_dg.deployment_group_name
        TaskDefinitionTemplateArtifact = "source_output"
        AppSpecTemplateArtifact        = "source_output"
        Image1ArtifactName             = "source_output"
        Image1ContainerName            = "RED_IMAGE"
      }
    }
  }
}

# CloudWatch Event Rules for Pipeline Triggers
resource "aws_cloudwatch_event_rule" "green_s3_trigger" {
  name        = "ws25-green-pipeline-trigger"
  description = "Trigger Green pipeline on S3 object upload"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.green_artifacts.bucket]
      }
      object = {
        key = ["artifact.zip"]
      }
    }
  })
}

resource "aws_cloudwatch_event_rule" "red_s3_trigger" {
  name        = "ws25-red-pipeline-trigger"
  description = "Trigger Red pipeline on S3 object upload"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.red_artifacts.bucket]
      }
      object = {
        key = ["artifact.zip"]
      }
    }
  })
}

# CloudWatch Event Targets
resource "aws_cloudwatch_event_target" "green_pipeline_target" {
  rule      = aws_cloudwatch_event_rule.green_s3_trigger.name
  target_id = "GreenPipelineTarget"
  arn       = aws_codepipeline.green_pipeline.arn
  role_arn  = aws_iam_role.cloudwatch_events_role.arn
}

resource "aws_cloudwatch_event_target" "red_pipeline_target" {
  rule      = aws_cloudwatch_event_rule.red_s3_trigger.name
  target_id = "RedPipelineTarget"
  arn       = aws_codepipeline.red_pipeline.arn
  role_arn  = aws_iam_role.cloudwatch_events_role.arn
}


