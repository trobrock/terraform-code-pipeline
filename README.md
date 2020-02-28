# Terraform Code Pipeline

The purpose of this module is the setup an opinionated CI/CD system. This was designed for use with
[trobrock/rails_template](https://github.com/trobrock/rails_template).

## How to use

When using the below reference, please be sure to lock your code to a specific version in the `ref`.
This project uses [Semantic Versioning](https://semver.org/).

```terraform
module "code_pipeline" {
  source = "git://github.com/trobrock/terraform-code-pipeline.git?ref=master"

  short_name  = "app"
  environment = "production"
  repo_owner  = "trobrock"
  repo_name   = "rails_template"

  build_environment = [
    {
      name  = "APP_REPOSITORY_URI"
      value = aws_ecr_repository.app.repository_url
    },
    {
      name  = "WEB_REPOSITORY_URI"
      value = aws_ecr_repository.web.repository_url
    },
    {
      name  = "DATABASE_URL"
      value = module.database.url # Using https://github.com/trobrock/terraform-database
    },
    {
      name  = "RAILS_ENV"
      value = local.environment
    },
    {
      name  = "REDIS_URL"
      value = module.redis.url # Using https://github.com/trobrock/terraform-redis
    }
  ]

  # Every below this is for ECS deployment, if you only need CI and not CD, just skip it
  lambda_subnet              = module.vpc.private_subnets[0] # Using https://github.com/trobrock/terraform-vpc
  ecs_cluster                = aws_ecs_cluster.main
  ecs_security_group_id      = aws_security_group.application_security_group.id
  ecs_task_definition_family = aws_ecs_task_definition.one_off.family
  ecs_task_definition_name   = "one_off"
  deployments = [
    {
      name         = "deploy-web"
      service_name = aws_ecs_service.web.name
      file_name    = "web_imagedefinitions.json"
    },
    {
      name         = "deploy-worker"
      service_name = aws_ecs_service.worker.name
      file_name    = "worker_imagedefinitions.json"
    }
  ]
}
```
