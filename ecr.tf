#ECRリポジトリ（WEB用）
resource "aws_ecr_repository" "ecr_repository_web" {
  name                 = "${var.project}-ecr-repository-web"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
  tags = {
    Name = "${var.project}-ecr-repository-web"
  }
}

#ECRリポジトリ（AP用）
resource "aws_ecr_repository" "ecr_repository_ap" {
  name                 = "${var.project}-ecr-repository-ap"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
  tags = {
    Name = "${var.project}-ecr-repository-ap"
  }
}