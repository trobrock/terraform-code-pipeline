resource "aws_iam_role" "lambda" {
  count = var.ecs_cluster != null ? 1 : 0

  name = "${local.name}-lambda"

  assume_role_policy = file("${path.module}/policies/lambda_role.json")
}

data "template_file" "lambda_policy" {
  count = var.ecs_cluster != null ? 1 : 0

  template = file("${path.module}/policies/lambda.json")

  vars = {
    cluster_arn         = var.ecs_cluster.arn
    task_definition_arn = "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task-definition/${var.ecs_task_definition_family}"
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  count = var.ecs_cluster != null ? 1 : 0

  name   = "${local.name}-lambda-policy"
  role   = aws_iam_role.lambda[0].id
  policy = data.template_file.lambda_policy[0].rendered
}

resource "aws_lambda_function" "run_rake_tasks" {
  count = var.ecs_cluster != null ? 1 : 0

  filename         = "${path.module}/lambda_functions/run_rake_tasks.zip"
  function_name    = "${local.name}-post-deploy-rake-tasks"
  handler          = "handler.handler"
  role             = aws_iam_role.lambda[0].arn
  runtime          = "python3.7"
  source_code_hash = filebase64sha256("${path.module}/lambda_functions/run_rake_tasks.zip")

  environment {
    variables = {
      cluster_name       = var.ecs_cluster.name
      subnet_id          = var.lambda_subnet
      security_group_ids = var.ecs_security_group_id
      task_definition    = var.ecs_task_definition_family
      task_name          = var.ecs_task_definition_name
    }
  }
}

resource "aws_cloudwatch_log_group" "run_rake_tasks" {
  count = var.ecs_cluster != null ? 1 : 0

  name              = "/aws/lambda/${aws_lambda_function.run_rake_tasks[0].function_name}"
  retention_in_days = 14
}
