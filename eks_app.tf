#アプリ用EKSクラスター
resource "aws_eks_cluster" "eks_cluster_app" {
  name     = "${var.project}-eks-cluster-app"
  role_arn = aws_iam_role.iam_role_eks_controlplane.arn
  version  = "1.36"
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }
  vpc_config {
    subnet_ids = [
      aws_subnet.private_subnet_1a.id,
      aws_subnet.private_subnet_1c.id
    ]
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.developer_public_ip_cidrs
  }
  tags = {
    Name = "${var.project}-eks-cluster-app"
  }
  depends_on = [aws_iam_role_policy_attachment.policy_attachment_eks_controlplane]
}

#アクセスエントリー（ローカル端末からkubectl（閲覧）を実行する用）
resource "aws_eks_access_entry" "eks_access_entry_app_viewer" {
  cluster_name  = aws_eks_cluster.eks_cluster_app.name
  principal_arn = aws_iam_role.iam_role_eks_kubectl_viewer.arn
  type          = "STANDARD"
}

#アクセスエントリーへのKubernetesAPI権限（閲覧）のアタッチ（AWSAPIではなくKubernetesAPIの権限）
resource "aws_eks_access_policy_association" "eks_access_policy_association_app_viewer" {
  cluster_name  = aws_eks_access_entry.eks_access_entry_app_viewer.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  principal_arn = aws_eks_access_entry.eks_access_entry_app_viewer.principal_arn
  access_scope {
    type = "cluster"
  }
}

#アクセスエントリー（Terraform Kubernetes Providerによる変更・管理用）
resource "aws_eks_access_entry" "eks_access_entry_app_admin" {
  cluster_name  = aws_eks_cluster.eks_cluster_app.name
  principal_arn = aws_iam_role.iam_role_eks_kubectl_admin.arn
  type          = "STANDARD"
}

#アクセスエントリーへのKubernetesAPI権限（変更・管理）のアタッチ（AWSAPIではなくKubernetesAPIの権限）
resource "aws_eks_access_policy_association" "eks_access_policy_association_app_admin" {
  cluster_name  = aws_eks_access_entry.eks_access_entry_app_admin.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.eks_access_entry_app_admin.principal_arn
  access_scope {
    type = "cluster"
  }
}


#アクセスエントリー（ArgoCDポッドからの監視・操作を受け付ける用）
resource "aws_eks_access_entry" "eks_access_entry_argocd_to_app" {
  cluster_name  = aws_eks_cluster.eks_cluster_app.name
  principal_arn = aws_iam_role.iam_role_eks_argocd_to_app.arn
  type          = "STANDARD"
}

#アクセスエントリーへのKubernetesAPI権限（監視・操作）のアタッチ（AWSAPIではなくKubernetesAPIの権限）
resource "aws_eks_access_policy_association" "eks_access_policy_association_argocd_to_app" {
  cluster_name  = aws_eks_access_entry.eks_access_entry_argocd_to_app.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.eks_access_entry_argocd_to_app.principal_arn
  access_scope {
    type = "cluster"
  }
}



#ノードグループ（ロールへのポリシーアタッチ、ネットワークまわりをdepends on指定）
resource "aws_eks_node_group" "eks_node_group_app" {
  node_group_name = "${var.project}-eks-node-group-app"
  cluster_name    = aws_eks_cluster.eks_cluster_app.name
  node_role_arn   = aws_iam_role.iam_role_eks_worker.arn
  subnet_ids = [
    aws_subnet.private_subnet_1a.id,
    aws_subnet.private_subnet_1c.id
  ]
  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 2
  }
  tags = {
    Name = "${var.project}-eks-node-group-app"
  }
  depends_on = [
    aws_iam_role_policy_attachment.policy_attachment_eks_worker_cni,
    aws_iam_role_policy_attachment.policy_attachment_eks_worker_ecr,
    aws_iam_role_policy_attachment.policy_attachment_eks_worker_kubelet,
    aws_route.igw_route,
    aws_route_table_association.public_routetable_subnet_1a,
    aws_route.natgw_route,
    aws_route_table_association.private_routetable_subnet_1a,
    aws_route_table_association.private_routetable_subnet_1c
  ]
}





#アドオン（pod_identity_agent）を導入
resource "aws_eks_addon" "eks_addon_pod_identity_agent_app" {
  addon_name   = "eks-pod-identity-agent"
  cluster_name = aws_eks_cluster.eks_cluster_app.name
}

#アドオン（pod_identity_agent）の設定（AWS Secret Managerから値を取得する為のロールを付ける）
resource "aws_eks_pod_identity_association" "eks_pod_identity_association_secrets_manager_view" {
  cluster_name    = aws_eks_cluster.eks_cluster_app.name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.iam_role_secret_manager_view.arn
}