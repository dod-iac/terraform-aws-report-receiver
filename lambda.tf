resource "aws_lambda_event_source_mapping" "this" {
  count                  = local.kinesis_data
  event_source_arn       = module.kinesis_stream[0].arn
  function_name          = aws_lambda_function.this.arn
  parallelization_factor = 10
  starting_position      = "LATEST"
}

locals {
  lambda_name = format("%s-%s-lambda", local.name_prefix, var.stream_type)
}
resource "aws_lambda_function" "this" {
  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256
  function_name    = local.lambda_name
  handler          = format("%s.lambda_handler", var.stream_type)
  role             = aws_iam_role.etl_lambda.arn
  runtime          = "python3.8"
  environment {
    variables = {
      DELIVERYSTREAM = local.firehosename
      PROJECT        = local.project
    }
  }
  tracing_config {
    mode = "PassThrough"
  }
  depends_on = [
    aws_iam_role_policy_attachment.logging_policy,
    aws_cloudwatch_log_group.this,
  ]
  timeout = 30
}

data "archive_file" "this" {
  type        = "zip"
  source_file = format("%s/%s.py", path.module, var.stream_type)
  output_path = format("%s/%s-lambda.zip", path.root, var.stream_type)
}
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${local.lambda_name}"
  retention_in_days = 1
  kms_key_id        = module.cloudwatch_kms_key.aws_kms_key_arn
}

module "cloudwatch_kms_key" {
  source = "dod-iac/cloudwatch-kms-key/aws"

  name = "alias/${local.name_prefix}-lambda-cloudwatch"

  tags    = var.tags
  version = "~>1.0.0"
}
