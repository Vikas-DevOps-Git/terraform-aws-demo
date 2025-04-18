variable "aws_region"           { type = string  default = "us-east-1" }
variable "vpc_cidr"             { type = string  default = "10.0.0.0/16" }
variable "public_subnet_cidrs"  { type = list(string) default = ["10.2.1.0/24","10.2.2.0/24"] }
variable "private_subnet_cidrs" { type = list(string) default = ["10.2.10.0/24","10.2.11.0/24"] }
variable "availability_zones"   { type = list(string) default = ["us-east-1a","us-east-1b"] }
variable "kms_key_arn"          { type = string  default = "" }
variable "waf_acl_arn"          { type = string  default = "" }

# Prod-specific hardening vars
variable "enable_deletion_protection" { type = bool   default = true }
variable "log_retention_days"         { type = number default = 365 }
variable "backup_retention_days"      { type = number default = 30 }
