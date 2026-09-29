#バージョン等の指定と、ステートファイルをS3で保持する設定
terraform {
  required_version = "1.16.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.66.0"
    }

  }
  #ステートファイルをS3で保持（対応予定）
  # backend "s3" {
  #   bucket = "後で"
  #   key = "eksargocd.tfstate"
  #   region = "ap-northeast-1"
  #   profile = "terraform"
  # }
}


#認証情報とリージョン指定
provider "aws" {
  profile = var.profile
  region  = var.region_default
}


#証明書用のus-east-1プロバイダー
provider "aws" {
  alias   = "provider_acm"
  profile = var.profile
  region  = var.region_acm
}
