#RDSインスタンス
resource "aws_db_instance" "rds" {
  identifier              = "${var.project}-rds"
  engine                  = "mysql"
  engine_version          = "8.4"
  instance_class          = "db.t3.micro"
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.sg_rds.id]
  allocated_storage       = 20
  storage_type            = "gp3"
  storage_encrypted       = true
  backup_retention_period = 1
  deletion_protection     = false
  skip_final_snapshot     = true

  db_name                     = "${var.project}_rds"
  username                    = var.db_username
  manage_master_user_password = true

  multi_az            = true
  publicly_accessible = false

  tags = {
    Name = "${var.project}-rds"
  }
}


#SG
resource "aws_security_group" "sg_rds" {
  name   = "${var.project}-sg-rds"
  vpc_id = aws_vpc.eksargocd_vpc.id
  tags = {
    Name = "${var.project}-sg-rds"
  }
}

#インバウンドルール（アプリのEKSクラスターSGからの通信を許可）
resource "aws_vpc_security_group_ingress_rule" "sg_rule_rds" {
  security_group_id            = aws_security_group.sg_rds.id
  referenced_security_group_id = aws_eks_cluster.eks_cluster_app.vpc_config[0].cluster_security_group_id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

#サブネットグループ定義
resource "aws_db_subnet_group" "db_subnet_group" {
  name = "${var.project}-db-subnet-group"
  subnet_ids = [
    aws_subnet.private_subnet_1a.id,
    aws_subnet.private_subnet_1c.id
  ]
  tags = {
    Name = "${var.project}-db-subnet-group"
  }
}