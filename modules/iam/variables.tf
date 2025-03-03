variable "environment"          { type = string }
variable "oidc_provider_arn"    { type = string  default = "" }
variable "oidc_provider_url"    { type = string  default = "" }
variable "namespace"            { type = string  default = "default" }
variable "service_account_name" { type = string  default = "default" }
variable "app_name"             { type = string  default = "app" }
variable "aws_region"           { type = string  default = "us-east-1" }
