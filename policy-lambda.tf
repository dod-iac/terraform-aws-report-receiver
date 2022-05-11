



data "aws_iam_policy_document" "lambdaassume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    // condition {
    //   test     = "ArnLike"
    //   variable = "aws:SourceArn"
    //   values   = ["arn:${data.aws_partition.current.id}:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.id}:function:${local.lambda_name}"]
    // }

  }
}


data "aws_iam_policy_document" "logging_policy_doc" {
  statement {
    sid = "CloudwatchPutMetricData"

    actions = [
      "cloudwatch:PutMetricData",
    ]

    resources = [
      "*"
    ]
  }

  statement {
    sid = "InstanceLogging"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      aws_cloudwatch_log_group.this.arn,
      format("%s:*", aws_cloudwatch_log_group.this.arn),
    ]

  }
  statement {
    actions = [
      "kms:Encrypt"
    ]
    resources = [module.cloudwatch_kms_key.aws_kms_key_arn]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = [aws_cloudwatch_log_group.this.arn]
    }
  }
  dynamic "statement" {
    for_each = range(0, local.kinesis_data)
    content {
      actions   = ["kinesis:GetRecords", "kinesis:GetShardIterator", "kinesis:DescribeStream", "kinesis:ListShards", "kinesis:ListStreams"]
      resources = [module.kinesis_stream[0].arn]
    }

  }
  statement {
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:Encrypt"]
    resources = [module.kinesis_kms_key.aws_kms_key_arn]
  }


  statement {
    actions   = ["firehose:PutRecordBatch"]
    resources = [aws_kinesis_firehose_delivery_stream.es.arn]
  }
}
resource "aws_iam_policy" "logging_policy" {
  name   = "${local.name_prefix}-${var.stream_type}-lambda-logging-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.logging_policy_doc.json
}



resource "aws_iam_role" "etl_lambda" {
  name               = format("%s-%s-lambda-role", local.name_prefix, var.stream_type)
  assume_role_policy = data.aws_iam_policy_document.lambdaassume.json
}


resource "aws_iam_role_policy_attachment" "logging_policy" {
  role       = aws_iam_role.etl_lambda.name
  policy_arn = aws_iam_policy.logging_policy.arn
}
