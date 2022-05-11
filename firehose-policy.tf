
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


resource "aws_iam_role" "firehose" {
  name               = local.firehosename
  assume_role_policy = data.aws_iam_policy_document.firehoseassume.json
}

resource "aws_iam_role_policy_attachment" "firehoseattachment" {
  role       = aws_iam_role.firehose.name
  policy_arn = aws_iam_policy.firehose.arn
}