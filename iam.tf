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


#kubectl実行用ロール
resource "aws_iam_role" "iam_role_eks_kubectl" {
  name               = "${var.project}-iam-role-eks-kubectl"
  assume_role_policy = data.aws_iam_policy_document.trust_policy_bashuser.json
}

#信頼ポリシー（kubectl実行用ロール用）
data "aws_iam_policy_document" "trust_policy_bashuser" {
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

#ポリシーをアタッチ（kubeletによる情報取得）
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