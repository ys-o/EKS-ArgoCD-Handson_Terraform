# EKS-ArgoCD-Handson_Terraform

## 概要

EKSとArgo CDを使ったWeb/APアプリケーションのハンズオンで、AWSリソースを構築するTerraformファイルです。
VPC、EKSクラスター2個、RDS、ECR、IAMなどの作成と、Argo CD本体・親Applicationの初期導入を行います。

## 4リポジトリの役割

| リポジトリ | 役割 |
|---|---|
| [Terraform（本リポジトリ）](https://github.com/ys-o/EKS-ArgoCD-Handson_Terraform) | AWSリソースの構築とArgo CDの初期導入 |
| [Argo CDアプリケーション定義](https://github.com/ys-o/EKS-ArgoCD-Handson_ArgoCD_app_of_apps) | Web/AP、ESO、AWS Load Balancer Controllerの子Application定義 |
| [Web/APマニフェスト](https://github.com/ys-o/EKS-ArgoCD-Handson_Application_manifests) | Deployment、Service、Ingress、SecretStore、ExternalSecret |
| [Web/APアプリ資材](https://github.com/ys-o/EKS-ArgoCD-Handson_Application) | PHP、Dockerfile、Nginx設定、GitHub Actionsワークフロー |

## ファイル構成

```text
main.tf            # バージョン、Provider、S3バックエンド
variables.tf       # 変数の宣言
terraform.tfvars   # 公開する共通設定値
network.tf         # VPC、サブネット、IGW、NAT Gateway
eks_argocd.tf      # Argo CD用EKSクラスター
eks_app.tf         # アプリ用EKSクラスター
iam.tf             # IAMロール・ポリシー
iam_oidc.tf        # GitHub Actions用OIDC Provider
rds.tf             # RDS MySQL
ecr.tf             # Web/AP用ECRリポジトリ
argocd.tf          # Argo CD導入、アプリクラスター登録、親Application
terraform_data.tf  # 初回イメージ準備、設定値転記、権限確認、削除待ち
outputs.tf         # RDS接続先などの出力

<<GITHUB非公開のファイル群>>
hidden.auto.tfvars　#　GitHub非公開（環境依存）の変数
hidden.s3.tfbackend #　tfstate管理用S3の定義
```

## GitHub非公開（環境依存）の変数

```text
domain                          # ドメイン
developer_public_ip_cidrs       # 作業者用端末のIPアドレス
aws_account_id                  # AWSアカウントID
console_user_name               # AWSコンソールにログインするIAMユーザー名
application_php_localpath       # phpアプリのディレクトリ（初回イメージをPUSHするため）
application_manifests_localpath # phpアプリマニフェストのディレクトリ（初回にタグを書き換えてPUSHするため）
profile                         # CLI上のterraform用profile名
```
