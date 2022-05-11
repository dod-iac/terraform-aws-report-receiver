#All policies around the publisher being able to get data to kinesis

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
      identifiers = ["logs.${var.source_region}.amazonaws.com", "events.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["arn:${var.source_partition}:logs:${var.source_region}:${var.source_account}:*", 
      "arn:${var.source_partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.id}:*", 
      "arn:${var.source_partition}:events:${var.source_region}:${var.source_account}:rule/*"
      ]
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

resource "aws_iam_role" "publish" {
  count              = local.kinesis_data
  name               = format("%s-%s-cloudwatch-kinesis-role", local.name_prefix, var.stream_type)
  assume_role_policy = data.aws_iam_policy_document.assumepublish[0].json
}



resource "aws_iam_role_policy_attachment" "publishattachment" {
  count      = local.kinesis_data
  role       = aws_iam_role.publish[0].name
  policy_arn = aws_iam_policy.publish[0].arn
}
