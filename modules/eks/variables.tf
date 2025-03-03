variable "environment"              { type = string }
variable "vpc_id"                   { type = string }
variable "private_subnet_ids"       { type = list(string) }
variable "cluster_role_arn"         { type = string }
variable "node_role_arn"            { type = string }
variable "kms_key_arn"              { type = string }
variable "kubernetes_version"       { type = string  default = "1.29" }
variable "on_demand_instance_types" { type = list(string) default = ["m5.large"] }
variable "spot_instance_types"      { type = list(string) default = ["m5.large", "m5.xlarge", "m4.large"] }
variable "on_demand_desired"        { type = number  default = 2 }
variable "on_demand_min"            { type = number  default = 1 }
variable "on_demand_max"            { type = number  default = 5 }
variable "spot_desired"             { type = number  default = 3 }
variable "spot_min"                 { type = number  default = 0 }
variable "spot_max"                 { type = number  default = 10 }
