#ECRリポジトリ完成後、空コミットPUSH＋GHAによって最初のイメージをPUSH
resource "terraform_data" "ecr_first_image_push" {
  provisioner "local-exec" {
    interpreter = ["C:/Program Files/Git/bin/bash.exe", "-c"]
    working_dir = var.application_php_localpath
    command     = <<EOF
      set -e
      git commit --allow-empty -m "（Terraformによる自動処理）空コミットでGHAをキックし、最初のイメージをPUSH"
      SHA=`git rev-parse HEAD`
      git push origin HEAD:main

      COUNT=0
      ID=""
      while [ -z "$ID" ]; do
        sleep 5
        ID=`gh run list --workflow="cicd.yaml" --branch="main" --commit="$SHA" --json databaseId --jq '.[0].databaseId // empty'`
        COUNT=$((COUNT + 1))
        if [ -z "$ID" ] && [ $COUNT -eq 10 ]; then
          exit 1
        fi
      done
      gh run watch $ID --exit-status
    EOF
  }

  #ECRリポジトリ完成＋ECRへのアクセス用ロール完成後に実行する為、DEPENSON指定
  depends_on = [aws_iam_role_policy_attachment.policy_attachment_ghaworkflow]
}




#最初のイメージのPUSH後、マニフェストにDB情報やイメージタグを転記
resource "terraform_data" "application_manifests_update" {
  provisioner "local-exec" {
    interpreter = ["C:/Program Files/Git/bin/bash.exe", "-c"]
    working_dir = var.application_manifests_localpath
    environment = {
      ECR_WEB     = aws_ecr_repository.ecr_repository_web.repository_url
      ECR_AP      = aws_ecr_repository.ecr_repository_ap.repository_url
      DB_HOST     = aws_db_instance.rds.address
      DB_NAME     = aws_db_instance.rds.db_name
      SECRETM_ARN = aws_db_instance.rds.master_user_secret[0].secret_arn
    }
    command = <<EOF
    set -e
    git pull --ff-only origin main

    sed -i "/- name: web[[:space:]]*$/ { n; s|image: [^:]*:|image: $ECR_WEB:|; }" base/deployment.yaml
    sed -i "/- name: ap[[:space:]]*$/ { n; s|image: [^:]*:|image: $ECR_AP:|; }" base/deployment.yaml
    
    sed -i "/name: DB_HOST[[:space:]]*$/ { n; s|value:.*|value: $DB_HOST|; }" base/deployment.yaml
    sed -i "/name: DB_NAME[[:space:]]*$/ { n; s|value:.*|value: $DB_NAME|; }" base/deployment.yaml

    sed -i "s/key: arn:aws:secretsmanager.*/key: $SECRETM_ARN/" base/externalsecret.yaml
        
    git add base/deployment.yaml base/externalsecret.yaml

    if ! git diff --cached --quiet; then
      git commit -m "（Terraformによる自動処理）DB情報、ECR URL、Secrets ARNをマニフェストに転記"
      git push origin HEAD:main
    fi
    EOF
  }
  depends_on = [terraform_data.ecr_first_image_push]

  #新規apply時のみではなく、ECRやDBの変更のapply時にもこの転記処理を実行する
  triggers_replace = [
    aws_ecr_repository.ecr_repository_web.repository_url,
    aws_ecr_repository.ecr_repository_ap.repository_url,
    aws_db_instance.rds.address,
    aws_db_instance.rds.db_name,
    aws_db_instance.rds.master_user_secret[0].secret_arn,
  ]
}

#全量apply時に、KubernetesAPIの権限が有効になっていることを確認するためのterraform_dataリソース
resource "terraform_data" "eks_cani_check" {
  provisioner "local-exec" {
    interpreter = ["C:/Program Files/Git/bin/bash.exe", "-c"]
    working_dir = var.application_php_localpath
    environment = {
      AWS_PROFILE    = var.profile
      AWS_REGION     = var.region_default
      CLUSTER_NAME   = aws_eks_cluster.eks_cluster_argocd.name
      ADMIN_ROLE_ARN = aws_iam_role.iam_role_eks_kubectl_admin.arn
    }
    command = <<EOF
      set -e
      aws eks update-kubeconfig --profile "$AWS_PROFILE" --region "$AWS_REGION" --name "$CLUSTER_NAME" --role-arn "$ADMIN_ROLE_ARN" --alias eksargocd-argocd
      COUNT=0
      FLAG=""
      while [ "$FLAG" != "yes" ]; do
        sleep 30
        FLAG=$(kubectl --context eksargocd-argocd auth can-i create namespaces --request-timeout=30s || true)
        COUNT=$((COUNT + 1))
        if [ "$FLAG" != "yes" ] && [ $COUNT -eq 10 ]; then
          exit 1
        fi
      done
    EOF
  }
  depends_on = [aws_eks_access_policy_association.eks_access_policy_association_argocd_admin]
}



#全量destroy時に、ArgoCD管理下のリソースの削除を担保するためのterraform_dataリソース
resource "terraform_data" "all_destroy_dependency_check" {
  input = {
    working_dir    = var.application_manifests_localpath
    app_cluster    = aws_eks_cluster.eks_cluster_app.name
    argocd_cluster = aws_eks_cluster.eks_cluster_argocd.name
    vpc_id         = aws_vpc.eksargocd_vpc.id
    profile        = var.profile
    region         = var.region_default
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["C:/Program Files/Git/bin/bash.exe", "-c"]
    working_dir = self.input.working_dir
    environment = {
      APP_CLUSTER    = self.input.app_cluster
      ARGOCD_CLUSTER = self.input.argocd_cluster
      VPC_ID         = self.input.vpc_id
      AWS_PROFILE    = self.input.profile
      AWS_REGION     = self.input.region
    }

    #ArgoCD管理のリソース群（IngressのALB等）が削除されるまで待機
    command = <<EOF
    set -e
    COUNT=0
    
    DELETED_APP="UNDELETED"
    DELETED_ARGOCD="UNDELETED"
    DELETED_ALB="UNDELETED"
    DELETED_ENI="UNDELETED"
    DELETED_SG="UNDELETED"
    
    while [ -n "$DELETED_APP" ] || [ -n "$DELETED_ARGOCD" ] || [ -n "$DELETED_ALB" ] || [ -n "$DELETED_ENI" ] || [ -n "$DELETED_SG" ]; do
      sleep 60

      DELETED_APP=$(kubectl --context eksargocd-app -n app get deployment,service,ingress -o name --request-timeout=30s)
      DELETED_ARGOCD=$(kubectl --context eksargocd-argocd -n argocd get applications.argoproj.io -o name --request-timeout=30s)
      DELETED_ALB=$(aws elbv2 describe-load-balancers --profile "$AWS_PROFILE" --region "$AWS_REGION" --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text --cli-connect-timeout 10 --cli-read-timeout 10 --no-cli-pager)
      DELETED_ENI=$(aws ec2 describe-network-interfaces --profile "$AWS_PROFILE" --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query "NetworkInterfaces[?starts_with(Description, 'ELB app/')].NetworkInterfaceId" --output text --cli-connect-timeout 10 --cli-read-timeout 10 --no-cli-pager)
      DELETED_SG=$(aws ec2 describe-security-groups --profile "$AWS_PROFILE" --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?starts_with(GroupName, 'k8s-')].GroupId" --output text --cli-connect-timeout 10 --cli-read-timeout 10 --no-cli-pager)
      
      COUNT=$((COUNT + 1))
      if { [ -n "$DELETED_APP" ] || [ -n "$DELETED_ARGOCD" ] || [ -n "$DELETED_ALB" ] || [ -n "$DELETED_ENI" ] || [ -n "$DELETED_SG" ]; } && [ "$COUNT" -eq 20 ]; then
        exit 1
      fi
    done
    EOF
  }


  #destroy時に、以下のDEPENDSONが効いて、上記の削除済みのチェックが完了してから、EKSリソース群等を削除するように制御する
  depends_on = [
    aws_eks_cluster.eks_cluster_app,
    aws_eks_cluster.eks_cluster_argocd,
    kubernetes_secret_v1_data.kubernetes_secret_argocd_to_app_data,
    aws_eks_node_group.eks_node_group_app,
    aws_eks_addon.eks_addon_pod_identity_agent_app,
    aws_eks_pod_identity_association.eks_pod_identity_association_ingress,
    aws_eks_pod_identity_association.eks_pod_identity_association_secrets_manager_view,
    aws_iam_role_policy_attachment.policy_attachment_eks_ingress,
    aws_iam_role_policy_attachment.policy_attachment_secret_manager_view,
    aws_vpc_security_group_ingress_rule.sg_rule_eks_app_cluster,
    aws_eks_access_policy_association.eks_access_policy_association_app_admin
  ]
}

