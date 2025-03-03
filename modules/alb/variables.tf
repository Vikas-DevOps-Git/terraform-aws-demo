variable "environment"      { type = string }
variable "vpc_id"           { type = string }
variable "subnet_ids"       { type = list(string) }
variable "allowed_cidrs"    { type = list(string) default = ["10.0.0.0/8"] }
variable "internal"         { type = bool   default = true }
variable "certificate_arn"  { type = string default = "" }
variable "access_log_bucket"{ type = string default = "" }
variable "target_port"      { type = number default = 8080 }
variable "health_check_path"{ type = string default = "/health" }
variable "waf_acl_arn"      { type = string default = "" }
