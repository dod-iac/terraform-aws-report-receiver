resource "aws_iam_policy" "publish" {
  count       = local.kinesis_data
  name        = format("%s-%s-enable-kineesis-publish", local.name_prefix, var.stream_type)
  path        = "/"
  description = format("IAM policy for  ing stream for %s:%s", local.name_prefix, var.stream_type)

  policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [

        {
          Action   = ["kms:GenerateDataKey"]
          Resource = [module.kinesis_kms_key.aws_kms_key_arn]
          Effect   = "Allow"
        },
        {
          Action   = ["kinesis:PutRecord", "kinesis:PutRecords"]
          Resource = [module.kinesis_stream[0].arn]
          Effect   = "Allow"
        }
      ]
    }
  )
}
data "aws_iam_policy_document" "assumepublish" {
  count = local.kinesis_data
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${var.source_region}.amazonaws.com", "logs.${data.aws_region.current.name}.amazonaws.com", "events.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${var.source_region}:${var.source_account}:*", "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.id}:*", "arn:aws:events:us-west-2:302469026048:rule/report-guard-duty-finding", "arn:aws:events:us-west-2:302469026048:rule/report-config-updates"]
    }
  }
}
data "aws_iam_policy_document" "firehoseassume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
    condition {
      test = "StringLike"
      //   variable = "aws:SourceAccount"
      variable = "sts:ExternalId"
      values   = [data.aws_caller_identity.current.id]
    }
  }
}

data "aws_iam_policy_document" "destination_policy" {
  count = local.kinesis_data
  statement {
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        var.source_account,
      ]
    }
    actions = [
      "logs:PutSubscriptionFilter",
    ]

    resources = [
      aws_cloudwatch_log_destination.this[0].arn,
    ]
  }
}

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

data "aws_iam_policy_document" "firehosepolicy" {
  statement {
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:CreateNetworkInterfacePermission",
    "ec2:DeleteNetworkInterface"]

    #conditions ec2:Vpc, ec2:Subnet
    resources = ["*"]
  }
  statement {
    actions = [
      "es:DescribeDomain",
      "es:DescribeDomains",
      "es:DescribeDomainConfig",
      "es:ESHttpPost",
      "es:ESHttpPut"
    ]
    resources = [
      var.opensearch_domain_arn,
      format("%s/*", var.opensearch_domain_arn)
    ]
  }
  statement {
    actions = [
      "es:ESHttpGet"
    ]
    resources = [
      format("%s/_all/_settings", var.opensearch_domain_arn),
      format("%s/_cluster/stats", var.opensearch_domain_arn),
      format("%s/_all/_nodes", var.opensearch_domain_arn),
      format("%s/_all/_nodes/stats", var.opensearch_domain_arn),
      format("%s/_all/_nodes/*/stats", var.opensearch_domain_arn),
      format("%s/_all/_stats", var.opensearch_domain_arn),
      format("%s/_all/_nodes", var.opensearch_domain_arn),
      format("%s/_all/%s*/_mapping/*", var.opensearch_domain_arn, format("%s-%s", var.stream_type, var.source_account)),
      format("%s/_all/%s*/_stats", var.opensearch_domain_arn, format("%s-%s", var.stream_type, var.source_account))

    ]
  }
  statement {
    actions = [
      "s3:PutObject"
    ]
    resources = [module.error_bucket.arn, format("%s/*", module.error_bucket.arn)]
  }
  statement {
    actions   = ["kms:Encrypt", "kms:GenerateDataKey"]
    resources = [module.firehose_errorkms.aws_kms_key_arn]
  }
}
resource "aws_iam_policy" "firehose" {
  name   = "${local.name_prefix}-${var.stream_type}-firehose-opensearch-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.firehosepolicy.json
}
