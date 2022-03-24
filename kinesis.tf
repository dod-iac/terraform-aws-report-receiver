#KMS key for encrypting stream
module "kinesis_kms_key" {
  source = "dod-iac/kinesis-kms-key/aws"

  name        = format("alias/%s-%s-kinesis-kms", local.name_prefix, var.stream_type)
  description = format("A KMS key used to encrypt Kinesis stream records at rest for %s", local.name_prefix)
  tags        = var.tags
  version     = ">= 1.0.1"
}
locals {
  firehosename = format("%s-%s-firehose", local.name_prefix, var.stream_type)
}


#Kinesis Stream
module "kinesis_stream" {
  count            = local.kinesis_data
  source           = "dod-iac/kinesis-stream/aws"
  name             = format("%s-%s-kinesis-stream", local.name_prefix, var.stream_type)
  kms_key_id       = module.kinesis_kms_key.aws_kms_key_arn
  tags             = var.tags
  retention_period = 24
  version          = ">=1.0.0"
}



resource "aws_cloudwatch_log_destination" "this" {
  count      = local.kinesis_data
  name       = format("%s-%s-destination", var.source_account, var.stream_type)
  role_arn   = aws_iam_role.publish[0].arn
  target_arn = module.kinesis_stream[0].arn
}

#resource policy to allow sending cloudwatch subscription to destination
resource "aws_cloudwatch_log_destination_policy" "this" {
  count            = local.kinesis_data
  destination_name = aws_cloudwatch_log_destination.this[0].name
  access_policy    = data.aws_iam_policy_document.destination_policy[0].json
}


resource "aws_kinesis_firehose_delivery_stream" "es" {
  name        = local.firehosename
  destination = "elasticsearch"
  s3_configuration {
    role_arn   = aws_iam_role.firehose.arn
    bucket_arn = module.error_bucket.arn
  }
  elasticsearch_configuration {
    domain_arn            = var.opensearch_domain_arn
    role_arn              = aws_iam_role.firehose.arn
    index_name            = format("%s-%s", var.stream_type, var.source_account)
    index_rotation_period = "OneDay"

    vpc_config {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
      role_arn           = aws_iam_role.firehose.arn
    }

  }
  server_side_encryption {
    enabled  = true
    key_type = "CUSTOMER_MANAGED_CMK"
    key_arn  = module.kinesis_kms_key.aws_kms_key_arn
  }
}

module "error_bucket" {
  source            = "trussworks/s3-private-bucket/aws"
  version           = ">= 3.7.1"
  bucket            = format("%s-%s-firehose-error", local.name_prefix, var.stream_type)
  kms_master_key_id = module.firehose_errorkms.aws_kms_key_id
  logging_bucket    = var.error_logging_bucket
  sse_algorithm     = "aws:kms"
  tags = merge(var.tags, {
    Name = format("%s-firhose-error-bucket", local.name_prefix)
    }
  )
  transitions = [
    {
      days          = 30
      storage_class = "STANDARD_IA"
    }

  ]
  expiration = [
    { days = 60 }
  ]
  noncurrent_version_expiration = 60

  noncurrent_version_transitions = [
    {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  ]
}


module "firehose_errorkms" {
  #source = "dod-iac/s3-kms-key/aws"
  source      = "git::https://github.com/dod-iac/terraform-aws-s3-kms-key.git?ref=rms-extending-principals"
  name        = format("alias/%s-%s-firehose-error-kms", local.name_prefix, var.stream_type)
  description = format("A KMS key used to encrypt objects at rest in S3 for %s:%s.", local.application, local.environment)
  tags        = var.tags
}
