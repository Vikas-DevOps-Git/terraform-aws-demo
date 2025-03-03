variable "environment"            { type = string }
variable "kubernetes_host"        { type = string }
variable "kubernetes_ca_cert"     { type = string  default = "" }
variable "service_account_names"  { type = list(string) default = ["default"] }
variable "namespaces"             { type = list(string) default = ["default"] }
variable "enable_db_engine"       { type = bool    default = false }
