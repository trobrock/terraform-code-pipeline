locals {
  name = "${var.short_name}-${var.environment}"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "codepipeline_role" {
  name = "${local.name}-codepipeline-role"

  assume_role_policy = file("${path.module}/policies/codepipeline_role.json")
}

data "template_file" "codepipeline_policy" {
  template = file("${path.module}/policies/codepipeline.json")

  vars = {
    aws_s3_bucket_arn = aws_s3_bucket.source.arn
  }
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name   = "${local.name}-codepipeline-policy"
  role   = aws_iam_role.codepipeline_role.id
  policy = data.template_file.codepipeline_policy.rendered
}

resource "aws_iam_role" "codebuild_role" {
  name               = "${local.name}-codebuild-role"
  assume_role_policy = file("${path.module}/policies/codebuild_role.json")
}

data "template_file" "codebuild_policy" {
  template = file("${path.module}/policies/codebuild_policy.json")

  vars = {
    aws_region        = var.aws_region
    aws_s3_bucket_arn = aws_s3_bucket.source.arn
    short_name        = var.short_name
    environment       = var.environment
    account_id        = data.aws_caller_identity.current.account_id
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name   = "${local.name}-codebuild-policy"
  role   = aws_iam_role.codebuild_role.id
  policy = data.template_file.codebuild_policy.rendered
}

resource "aws_codebuild_project" "build" {
  name          = "${local.name}-codebuild"
  build_timeout = var.build_timeout
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE"]
  }

  environment {
    compute_type    = "BUILD_GENERAL1_MEDIUM"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }

    dynamic "environment_variable" {
      for_each = var.build_environment
      content {
        name  = environment_variable.value.name
        value = environment_variable.value.value
      }
    }
  }

  source {
    type = "CODEPIPELINE"
  }
}

resource "aws_codepipeline" "pipeline" {
  name     = "${local.name}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.source.bucket
    type     = "S3"

    encryption_key {
      id   = aws_kms_key.key.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source"]

      configuration = {
        Owner                = var.repo_owner
        Repo                 = var.repo_name
        Branch               = var.branch
        PollForSourceChanges = false
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source"]
      output_artifacts = ["imagedefinitions"]

      configuration = {
        ProjectName = "${local.name}-codebuild"
      }
    }
  }

  dynamic "stage" {
    for_each = var.ecs_cluster != null ? [1] : []
    content {
      name = "Deploy"

      dynamic "action" {
        for_each = var.deployments
        content {
          name            = action.value.name
          category        = "Deploy"
          owner           = "AWS"
          provider        = "ECS"
          input_artifacts = ["imagedefinitions"]
          version         = "1"

          configuration = {
            ClusterName = var.ecs_cluster.name
            ServiceName = action.value.service_name
            FileName    = action.value.file_name
          }
        }
      }
    }
  }

  dynamic "stage" {
    for_each = var.ecs_cluster != null ? [1] : []
    content {
      name = "Post-Deploy-Tasks"

      action {
        name     = "rake-tasks"
        category = "Invoke"
        owner    = "AWS"
        provider = "Lambda"
        version  = "1"

        configuration = {
          FunctionName = aws_lambda_function.run_rake_tasks[0].function_name
        }
      }
    }
  }
}
