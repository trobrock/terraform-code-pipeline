data "template_file" "kms_key_policy" {
  template = file("${path.module}/policies/kms_key.json")

  vars = {
    account_id            = data.aws_caller_identity.current.account_id
    codepipeline_role_arn = aws_iam_role.codepipeline_role.arn
    codebuild_role_arn    = aws_iam_role.codebuild_role.arn
  }
}

resource "aws_kms_key" "key" {
  description = "The key to be used to encrypt the artifact store for ${local.name}-codepipeline-store"
  policy      = data.template_file.kms_key_policy.rendered
}

resource "aws_s3_bucket" "source" {
  bucket        = "${local.name}-codepipeline-store"
  acl           = "private"
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}
