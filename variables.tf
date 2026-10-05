#変数群の宣言（GitHub公開／共通設定）
variable "project" {
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

variable "db_username" {
  type = string
}






#変数群の宣言（値はGitHub非公開／環境依存）
variable "domain" {
  description = "（ドメイン名指定でのアクセスを実装する場合）ドメイン名"
  type        = string
}

variable "developer_public_ip_cidrs" {
  description = "管理者のパブリックIPを指定するCIDR（家と会社等を指定）"
  type        = list(string)
}

variable "aws_account_id" {
  description = "AWSのアカウントID"
  type        = string
}

variable "console_user_name" {
  description = "コンソールを操作するIAMユーザー名"
  type        = string
}

variable "application_php_localpath" {
  description = "ローカルのアプリ資材ディレクトリ"
  type        = string
}

variable "application_manifests_localpath" {
  description = "ローカルのアプリマニフェストディレクトリ"
  type        = string
}

variable "profile" {
  description = "Terraformを実行するCLIにおけるプロファイル名"
  type        = string
}