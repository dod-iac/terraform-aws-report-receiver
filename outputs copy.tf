output "kinesis_stream_arn" {
  value = local.kinesis_data > 0 ? module.kinesis_stream[0].arn : ""
}
output "destination_arn" {
  value = local.kinesis_data > 0 ? aws_cloudwatch_log_destination.this[0].arn : ""
}
output "kinesis_name" {
  value = local.kinesis_data > 0 ? module.kinesis_stream[0].name : ""
}
output "kms_arn" {
  value = module.kinesis_kms_key.aws_kms_key_arn
}

output "publish_role_arn" {
  value = local.kinesis_data > 0 ? aws_iam_role.publish[0].arn : ""
}


// output "sns_topic_arn"{
//     value = local.config>0?module.alerts[0].arn:""
//     description = "ARN of the SNS topic"
// }
