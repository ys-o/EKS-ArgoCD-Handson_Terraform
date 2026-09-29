#ArgoCD用のEKSクラスター
resource "aws_eks_cluster" "eks_cluster_argocd" {
  name     = "${var.project}-eks-cluster-argocd"
  role_arn = aws_iam_role.iam_role_eks_controlplane.arn
  version  = "1.36"
  vpc_config {
    subnet_ids = [
      aws_subnet.private_subnet_1a.id,
      aws_subnet.private_subnet_1c.id
    ]
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.developer_public_ip_cidrs
  }
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }
  tags = {
    Name = "${var.project}-eks-cluster-argocd"
  }
  depends_on = [aws_iam_role_policy_attachment.policy_attachment_eks_controlplane]
}

#アクセスエントリー（ローカル端末からkubectl（閲覧）を実行する用）
resource "aws_eks_access_entry" "eks_access_entry_argocd_viewer" {
  cluster_name  = aws_eks_cluster.eks_cluster_argocd.name
  principal_arn = aws_iam_role.iam_role_eks_kubectl_viewer.arn
  type          = "STANDARD"
}

#アクセスエントリーへのKubernetesAPI権限（閲覧）のアタッチ（AWSAPIではなくKubernetesAPIの権限）
resource "aws_eks_access_policy_association" "eks_access_policy_association_argocd_viewer" {
  cluster_name  = aws_eks_access_entry.eks_access_entry_argocd_viewer.cluster_name
  principal_arn = aws_eks_access_entry.eks_access_entry_argocd_viewer.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  access_scope {
    type = "cluster"
  }
}

#アクセスエントリー（Terraform Kubernetes Providerによる変更・管理用）
resource "aws_eks_access_entry" "eks_access_entry_argocd_admin" {
  cluster_name  = aws_eks_cluster.eks_cluster_argocd.name
  principal_arn = aws_iam_role.iam_role_eks_kubectl_admin.arn
  type          = "STANDARD"
}

#アクセスエントリーへのKubernetesAPI権限（変更・管理）のアタッチ（AWSAPIではなくKubernetesAPIの権限）
resource "aws_eks_access_policy_association" "eks_access_policy_association_argocd_admin" {
  cluster_name  = aws_eks_access_entry.eks_access_entry_argocd_admin.cluster_name
  principal_arn = aws_eks_access_entry.eks_access_entry_argocd_admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}

#ノードグループ（ロールへのポリシーアタッチ、ネットワークまわりをdepends on指定）
resource "aws_eks_node_group" "eks_node_group_argocd" {
  node_group_name = "${var.project}-eks-node-group-argocd"
  cluster_name    = aws_eks_cluster.eks_cluster_argocd.name
  node_role_arn   = aws_iam_role.iam_role_eks_worker.arn
  capacity_type   = "ON_DEMAND"
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
    Name = "${var.project}-eks-node-group-argocd"
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
resource "aws_eks_addon" "eks_addon_pod_identity_agent_argocd" {
  addon_name   = "eks-pod-identity-agent"
  cluster_name = aws_eks_cluster.eks_cluster_argocd.name
}


#アドオン（pod_identity_agent）の設定（アプリクラスターを監視／操作する為のロールを付ける：application-controller）
resource "aws_eks_pod_identity_association" "eks_pod_identity_association_argocd_to_app_application_controller" {
  cluster_name    = aws_eks_cluster.eks_cluster_argocd.name
  namespace       = "argocd"
  role_arn        = aws_iam_role.iam_role_eks_argocd_to_app.arn
  service_account = "argocd-application-controller"
}

#アドオン（pod_identity_agent）の設定（アプリクラスターを監視／操作する為のロールを付ける：applicationset-controller）
resource "aws_eks_pod_identity_association" "eks_pod_identity_association_argocd_to_app_applicationset_controller" {
  cluster_name    = aws_eks_cluster.eks_cluster_argocd.name
  namespace       = "argocd"
  role_arn        = aws_iam_role.iam_role_eks_argocd_to_app.arn
  service_account = "argocd-applicationset-controller"
}

#アドオン（pod_identity_agent）の設定（アプリクラスターを監視／操作する為のロールを付ける：server）
resource "aws_eks_pod_identity_association" "eks_pod_identity_association_argocd_to_app_server" {
  cluster_name    = aws_eks_cluster.eks_cluster_argocd.name
  namespace       = "argocd"
  role_arn        = aws_iam_role.iam_role_eks_argocd_to_app.arn
  service_account = "argocd-server"
}