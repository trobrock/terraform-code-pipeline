variable "aws_region" {
  description = "The AWS region to launch resources in"
  type        = string
  default     = "us-east-1"
}

variable "short_name" {
  description = "The short name of the application to use on resources"
  type        = string
}

variable "environment" {
  description = "The name of the environment we are deploying"
  type        = string
}

variable "repo_owner" {
  description = "The owner of the repo on GitHub"
  type        = string
}

variable "repo_name" {
  description = "The name of the repo on GitHub"
  type        = string
}

variable "branch" {
  description = "The name of the branch to run against"
  type        = string
  default     = "master"
}

variable "build_timeout" {
  description = "The time in minutes to timeout a codebuild run"
  type        = number
  default     = 10
}

variable "build_environment" {
  type = list(object({
    name  = string
    value = string
  }))

  description = "The environment variables to set in the build environment"
}

variable "deployments" {
  type = list(object({
    name         = string
    service_name = string
    file_name    = string
  }))

  description = "The configuration for the code pipeline deployment"
  default     = []
}

variable "lambda_subnet" {
  description = "The subnet to launch the post deploy container task in"
  type        = string
  default     = null
}

variable "ecs_cluster" {
  description = "The ECS cluster that you will be deploying to"
  default     = null
}

variable "ecs_task_definition_family" {
  description = "The family of the task definition to launch for post deploy tasks"
  type        = string
  default     = null
}

variable "ecs_task_definition_name" {
  description = "The name of the container to launch for post deploy tasks"
  type        = string
  default     = null
}

variable "ecs_security_group_id" {
  description = "The security group ID to use for the post deploy tasks"
  type        = string
  default     = null
}
