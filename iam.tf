#EKSコントロールプレーン用ロール
resource "aws_iam_role" "iam_role_eks_controlplane" {
  name               = "${var.project}-iam-role-eks-controlplane"
  assume_role_policy = data.aws_iam_policy_document.trust_policy_controlplane.json
}

#ポリシーをアタッチ（EKS管理権限）
resource "aws_iam_role_policy_attachment" "policy_attachment_eks_controlplane" {
  role       = aws_iam_role.iam_role_eks_controlplane.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

#信頼ポリシー（EKS用ロール用）
data "aws_iam_policy_document" "trust_policy_controlplane" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}


#kubectl用ロール（閲覧用）
resource "aws_iam_role" "iam_role_eks_kubectl_viewer" {
  name               = "${var.project}-iam-role-eks-kubectl-viewer"
  assume_role_policy = data.aws_iam_policy_document.trust_policy_kubectl_and_provider.json
}

#Terraform Kubernetes Provider用ロール(変更・管理用)
resource "aws_iam_role" "iam_role_eks_kubectl_admin" {
  name               = "${var.project}-iam-role-eks-kubectl-admin"
  assume_role_policy = data.aws_iam_policy_document.trust_policy_kubectl_and_provider.json
}
#信頼ポリシー（kubectl/Provider用ロール用）
data "aws_iam_policy_document" "trust_policy_kubectl_and_provider" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.aws_account_id}:user/terraform"]
    }
  }
}


#ワーカーノード（EC2）用ロール
resource "aws_iam_role" "iam_role_eks_worker" {
  name               = "${var.project}-iam-role-eks-worker"
  assume_role_policy = data.aws_iam_policy_document.trust_policy_worker.json
}

#ポリシーをアタッチ（クラスターへの接続等）
resource "aws_iam_role_policy_attachment" "policy_attachment_eks_worker_kubelet" {
  role       = aws_iam_role.iam_role_eks_worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

#ポリシーをアタッチ（ECRからのイメージ取得）
resource "aws_iam_role_policy_attachment" "policy_attachment_eks_worker_ecr" {
  role       = aws_iam_role.iam_role_eks_worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

#ポリシーをアタッチ（CNIによるPODのIPアドレス管理）
resource "aws_iam_role_policy_attachment" "policy_attachment_eks_worker_cni" {
  role       = aws_iam_role.iam_role_eks_worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

#信頼ポリシー（ワーカーノード用ロール用）
data "aws_iam_policy_document" "trust_policy_worker" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}




#GHAWorkflow用ロール
resource "aws_iam_role" "iam_role_ghaworkflow" {
  name               = "${var.project}-iam-role-ghaworkflow"
  assume_role_policy = data.aws_iam_policy_document.trust_policy_ghaworkflow.json
}

#WEBとAPのECRリポジトリ指定してPUSHを許可するポリシー
data "aws_iam_policy_document" "iam_policy_document_webap_ecr_push" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:CompleteLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:InitiateLayerUpload",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:BatchGetImage"
    ]
    resources = [
      aws_ecr_repository.ecr_repository_ap.arn,
      aws_ecr_repository.ecr_repository_web.arn
    ]
  }
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "iam_policy_webap_ecr_push" {
  name   = "${var.project}-iam-policy-webap-ecr-push"
  policy = data.aws_iam_policy_document.iam_policy_document_webap_ecr_push.json
  tags = {
    Name = "${var.project}-iam-policy-webap-ecr-push"
  }
}

#ポリシーをアタッチ（GHAworkflowマシンがECRにPushすることを許可）
resource "aws_iam_role_policy_attachment" "policy_attachment_ghaworkflow" {
  role       = aws_iam_role.iam_role_ghaworkflow.name
  policy_arn = aws_iam_policy.iam_policy_webap_ecr_push.arn
}

#信頼ポリシー（GHAWorkflow用ロール用/OIDCによる認証）
data "aws_iam_policy_document" "trust_policy_ghaworkflow" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_oidc.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:ys-o@273895000/EKS-ArgoCD-Handson_Application@1387028415:ref:refs/heads/main"]
    }
  }
}



#KubernetesのSecretリソース生成時の、Secret Manager閲覧用ロール
resource "aws_iam_role" "iam_role_secret_manager_view" {
  name               = "${var.project}-iam-role-secret-manager-view"
  assume_role_policy = data.aws_iam_policy_document.trust_policy_secret_manager_view.json
}

#Secret Manager上での検索、およびDB認証情報を取得することを許可するポリシー
data "aws_iam_policy_document" "iam_policy_document_secret_manager_view" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:ListSecrets",
      "secretsmanager:BatchGetSecretValue"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [aws_db_instance.rds.master_user_secret[0].secret_arn]
  }
}

resource "aws_iam_policy" "iam_policy_secret_manager_view" {
  name   = "${var.project}-iam-policy-secret-manager-view"
  policy = data.aws_iam_policy_document.iam_policy_document_secret_manager_view.json
  tags = {
    Name = "${var.project}-iam-policy-secret-manager-view"
  }
}


#ポリシーをアタッチ（Secret ManagerからDB認証情報を取得することを許可）
resource "aws_iam_role_policy_attachment" "policy_attachment_secret_manager_view" {
  role       = aws_iam_role.iam_role_secret_manager_view.name
  policy_arn = aws_iam_policy.iam_policy_secret_manager_view.arn
}

#信頼ポリシー（KubernetesのSecretリソース生成時の、Secret Manager閲覧用ロール用）
data "aws_iam_policy_document" "trust_policy_secret_manager_view" {
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}


#ArgoCDポッドがアプリクラスターを操作する為のロール
resource "aws_iam_role" "iam_role_eks_argocd_to_app" {
  name               = "${var.project}-iam-role-eks-argocd-to-app"
  assume_role_policy = data.aws_iam_policy_document.trust_policy_argocd_to_app.json
}


#信頼ポリシー（ArgoCDポッドがアプリクラスターを操作する為のロール用）
data "aws_iam_policy_document" "trust_policy_argocd_to_app" {
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}






#Ingress用ロール
resource "aws_iam_role" "iam_role_eks_ingress" {
  name = "${var.project}-iam-role-eks-ingress"
  assume_role_policy = data.aws_iam_policy_document.trust_policy_ingress.json
}


#カスタムポリシー（Ingressが、ALB／TG／SG等の操作を行うための権限を設定）
data "aws_iam_policy_document" "iam_policy_document_ingress" {
  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:*",
      "ec2:*",
      "iam:*"
    ]
    resources = ["*"]
  }
}


resource "aws_iam_policy" "iam_policy_ingress" {
  name = "${var.project}-iam-policy-ingress"
  policy = data.aws_iam_policy_document.iam_policy_document_ingress.json
  tags = {
    Name = "${var.project}-iam-policy-ingress"
  }
}

#ポリシーをアタッチ（Ingress用ロールにアタッチ）
resource "aws_iam_role_policy_attachment" "policy_attachment_eks_ingress" {
  role = aws_iam_role.iam_role_eks_ingress.name
  policy_arn = aws_iam_policy.iam_policy_ingress.arn
}

#信頼ポリシー（Ingress用ロール用）
data "aws_iam_policy_document" "trust_policy_ingress" {
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
    principals {
      type = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}