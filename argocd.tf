#名前空間（argocd）を作成する
resource "kubernetes_namespace_v1" "kubernetes_namespace_argocd" {
  provider = kubernetes.argocd
  metadata {
    name = "argocd"
  }
  depends_on = [
    aws_eks_access_policy_association.eks_access_policy_association_argocd_admin,
    terraform_data.eks_cani_check
  ]
}

#eksリソース群が完成した後、argocdを導入する
resource "helm_release" "helm_release_argocd" {
  provider        = helm.argocd
  name            = "argocd"
  repository      = "https://argoproj.github.io/argo-helm"
  chart           = "argo-cd"
  version         = "10.9.2"
  namespace       = kubernetes_namespace_v1.kubernetes_namespace_argocd.metadata[0].name
  wait            = true
  timeout         = 900
  atomic          = true
  cleanup_on_fail = true
  depends_on = [
    aws_eks_node_group.eks_node_group_argocd,
    aws_eks_addon.eks_addon_pod_identity_agent_argocd,
    aws_eks_pod_identity_association.eks_pod_identity_association_argocd_to_app_application_controller,
    aws_eks_pod_identity_association.eks_pod_identity_association_argocd_to_app_applicationset_controller,
    aws_eks_pod_identity_association.eks_pod_identity_association_argocd_to_app_server
  ]
}

#ArgoCDに、アプリクラスターへの接続情報を格納するsecretリソースを作成する
resource "kubernetes_secret_v1" "kubernetes_secret_argocd_to_app" {
  provider = kubernetes.argocd
  type     = "Opaque"
  metadata {
    name      = "${var.project}-cluster-app"
    namespace = kubernetes_namespace_v1.kubernetes_namespace_argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }
  }
  depends_on = [
    helm_release.helm_release_argocd,
    aws_eks_access_policy_association.eks_access_policy_association_argocd_to_app
  ]
}

#Secretリソースにデータを追加する
resource "kubernetes_secret_v1_data" "kubernetes_secret_argocd_to_app_data" {
  provider = kubernetes.argocd
  data = {
    name   = aws_eks_cluster.eks_cluster_app.name
    server = aws_eks_cluster.eks_cluster_app.endpoint
    config = jsonencode(
      {
        "awsAuthConfig" = {
          "clusterName" = aws_eks_cluster.eks_cluster_app.name
        }
        "tlsClientConfig" = {
          "insecure" = false
          "caData"   = aws_eks_cluster.eks_cluster_app.certificate_authority[0].data
        }
      }
    )
  }
  metadata {
    name      = kubernetes_secret_v1.kubernetes_secret_argocd_to_app.metadata[0].name
    namespace = kubernetes_namespace_v1.kubernetes_namespace_argocd.metadata[0].name
  }
}



#helmでArgo CD本体とCRDの導入後、argocd-apps Chartを利用して親アプリケーションを作成する
resource "helm_release" "helm_release_argocd_app" {
  provider        = helm.argocd
  name            = "argocd-app"
  repository      = "https://argoproj.github.io/argo-helm"
  chart           = "argocd-apps"
  version         = "2.0.5"
  namespace       = kubernetes_namespace_v1.kubernetes_namespace_argocd.metadata[0].name
  wait            = false
  timeout         = 300
  atomic          = true
  cleanup_on_fail = true
  depends_on = [
    kubernetes_secret_v1_data.kubernetes_secret_argocd_to_app_data,
    terraform_data.all_destroy_dependency_check
  ]
  values = [
    yamlencode(
      {
        applications = {
          "${var.project}-oya-application" = {
            namespace  = kubernetes_namespace_v1.kubernetes_namespace_argocd.metadata[0].name
            finalizers = ["resources-finalizer.argocd.argoproj.io"]
            project    = "default"

            source = {
              repoURL        = "https://github.com/ys-o/EKS-ArgoCD-Handson_ArgoCD_app_of_apps.git"
              targetRevision = "main"
              path           = "ko_application_install"
            }

            destination = {
              server    = "https://kubernetes.default.svc"
              namespace = "argocd"
            }

            syncPolicy = {
              automated = {
                prune    = true
                selfHeal = true
              }
            }
          }
        }
      }
    )
  ]
}
