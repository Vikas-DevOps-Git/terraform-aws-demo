variable "environment"        { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "peer_vpc_cidrs"     { type = list(string) default = [] }
