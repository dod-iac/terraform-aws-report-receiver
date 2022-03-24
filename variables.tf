variable "tags" {
  description = "Tags to be applied to all resources"
  type = object({
    Project     = string
    Environment = string
    Application = string
  })
  default = {
    Project     = "elmo"
    Environment = "dev"
    Application = "infra"
  }
}


variable "source_region" {
  type        = string
  default     = "us-west-2"
  description = "the region from which data will be published"
}
variable "source_account" {
  type        = string
  description = "the account number of the publishing account"
}
variable "subnet_ids" {
  type        = list(string)
  description = "ids of subnets that kinesisfirehose will create interfaces in. Make sure ACLs permit traffic from this subnet to where opensearch is deployed"

}
variable "opensearch_domain_arn" {
  type        = string
  description = "ARN of opensearch to be used as target of stream"
}

variable "security_group_ids" {
  type        = list(string)
  description = "IDs of security groups to be used that allow ingress to opensearch deployment"
}
variable "stream_type" {
  type        = string
  description = "The type of string being configured. Accepted values are (cloudtrail,flowlog,guardduty,config)"
  validation {
    condition     = var.stream_type == "cloudtrail" || var.stream_type == "flowlog" || var.stream_type == "guardduty" || var.stream_type == "config"
    error_message = "Stream_type must be one of (cloudtrail,flowlog,guardduty,config)."
  }
}


variable "error_logging_bucket" {
  description = "The S3 bucket to send S3 access logs. Used by the firehose error bucket that is created"
  type        = string
}




locals {
  project     = var.tags.Project
  environment = var.tags.Environment
  application = var.tags.Application
  name_prefix = format("%s-%s-%s-%s", random_string.prefix.id, local.project, local.application, local.environment)
}

locals {
  cloudtrail   = var.stream_type == "cloudtrail" ? 1 : 0
  flowlog      = var.stream_type == "flowlog" ? 1 : 0
  config       = var.stream_type == "config" ? 1 : 0
  guardduty    = var.stream_type == "guardduty" ? 1 : 0
  kinesis_data = max(local.cloudtrail, local.flowlog, local.guardduty, local.config)
}


#This is useful for preventing conflicts in naming
resource "random_string" "prefix" {
  keepers = {
    project     = local.project
    environment = local.environment
    application = local.application
  }
  length  = 8
  special = false
  upper   = false
}
