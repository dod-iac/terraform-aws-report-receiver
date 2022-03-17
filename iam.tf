#create a role that can publish data to stream and can be assumed by logs
resource "aws_iam_role" "publish" {
  count              = local.kinesis_data
  name               = format("%s-%s-cloudwatch-kinesis-role", local.name_prefix, var.stream_type)
  assume_role_policy = data.aws_iam_policy_document.assumepublish[0].json
}
resource "aws_iam_role" "etl_lambda" {
  name               = format("%s-%s-lambda-role", local.name_prefix, var.stream_type)
  assume_role_policy = data.aws_iam_policy_document.lambdaassume.json
}
resource "aws_iam_role" "firehose" {
  name               = local.firehosename
  assume_role_policy = data.aws_iam_policy_document.firehoseassume.json
}

resource "aws_iam_role_policy_attachment" "logging_policy" {
  role       = aws_iam_role.etl_lambda.name
  policy_arn = aws_iam_policy.logging_policy.arn
}
resource "aws_iam_role_policy_attachment" "firehoseattachment" {
  role       = aws_iam_role.firehose.name
  policy_arn = aws_iam_policy.firehose.arn
}

resource "aws_iam_role_policy_attachment" "publishattachment" {
  count      = local.kinesis_data
  role       = aws_iam_role.publish[0].name
  policy_arn = aws_iam_policy.publish[0].arn
}
