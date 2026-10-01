#バージョン等の指定と、ステートファイルをS3で保持する設定
terraform {
  required_version = "1.16.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.66.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
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


#AWSプロバイダーデフォルト構成設定
provider "aws" {
  profile = var.profile
  region  = var.region_default
}


#AWS、証明書用のus-east-1プロバイダー構成設定
provider "aws" {
  alias   = "provider_acm"
  profile = var.profile
  region  = var.region_acm
}

#AWSコンソール操作時のIAMユーザー
data "aws_iam_user" "iam_user_console" {
  user_name = var.console_user_name
}



#kubernetesプロバイダー構成設定
provider "kubernetes" {
  alias                  = "argocd"
  host                   = aws_eks_cluster.eks_cluster_argocd.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster_argocd.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      aws_eks_cluster.eks_cluster_argocd.name,
      "--region",
      var.region_default,
      "--role-arn",
      aws_iam_role.iam_role_eks_kubectl_admin.arn,
      "--profile",
      var.profile
    ]
  }
}



#helmプロバイダー構成設定
provider "helm" {
  alias = "argocd"
  kubernetes = {
    host                   = aws_eks_cluster.eks_cluster_argocd.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster_argocd.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        aws_eks_cluster.eks_cluster_argocd.name,
        "--region",
        var.region_default,
        "--role-arn",
        aws_iam_role.iam_role_eks_kubectl_admin.arn,
        "--profile",
        var.profile
      ]
    }
  }
}
