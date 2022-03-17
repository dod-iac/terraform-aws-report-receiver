


// module "alerts_kms_key" {
//     count = local.config
//   source = "dod-iac/sns-kms-key/aws"

//   name = format("alias/%s-alerts", local.name_prefix)
//   tags = {
//     Application = local.application
//     Environment = local.environment
//     Automation  = "Terraform"
//   }
// }

// module "alerts" {
//     count = local.config
//   source = "dod-iac/sns-topic/aws"

//   name = format("%s-alerts", local.name_prefix)
//   kms_master_key_id = module.alerts_kms_key[0].aws_kms_key_arn
//   tags = {
//     Application = local.application
//     Environment = local.environment
//     Automation  = "Terraform"
//   }
// }

// data "aws_iam_policy_document" "config" {
//   count = length(var.reporter_role_arns)>0 && local.config == 1? 1:0
//   statement {
//     effect = "Allow"
//     principals {
//       type        = "AWS"
//       identifiers = var.reporter_role_arns
//     }
//     actions   = ["sns:Publish"]
//     resources = [ module.alerts[0].arn]
//   }
// }
// resource "aws_sns_topic_policy" "config" {
//   count = length(var.reporter_role_arns)>0 && local.config == 1? 1:0
//   arn    =  module.alerts[0].arn
//   policy = data.aws_iam_policy_document.config[0].json
// }

// resource "aws_lambda_permission" "with_sns" {
//     count = local.config
//   statement_id  = "AllowExecutionFromSNS"
//   action        = "lambda:InvokeFunction"
//   function_name = aws_lambda_function.this.function_name
//   principal     = "sns.amazonaws.com"
//   source_arn    = module.alerts[0].arn
// }
// resource "aws_sns_topic_subscription" "lambda" {
// count = local.config
//   topic_arn = module.alerts[0].arn
//   protocol  = "lambda"
//   endpoint  = aws_lambda_function.this.arn
// }
