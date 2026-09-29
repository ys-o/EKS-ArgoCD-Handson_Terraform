#変数群の宣言
variable "project" {
  type = string
}

variable "profile" {
  type = string
}

variable "domain" {
  type = string
}

variable "region_default" {
  type = string
}

variable "region_acm" {
  type = string
}

variable "az_1a" {
  type = string
}

variable "az_1c" {
  type = string
}

variable "cidr_all" {
  type = string
}

variable "cidr_vpc" {
  type = string
}

variable "cidr_public_1a" {
  type = string
}

variable "cidr_public_1c" {
  type = string
}

variable "cidr_private_1a" {
  type = string
}

variable "cidr_private_1c" {
  type = string
}

variable "developer_public_ip_cidrs" {
  description = "管理者のパブリックIPを指定するCIDR（家と会社等を指定）"
  type        = list(string)
}

variable "aws_account_id" {
  description = "AWSのアカウントID、中身はgit管理（＝terraform.tfvars内での定義）対象外"
  type        = string
}

variable "db_username" {
  type = string
}