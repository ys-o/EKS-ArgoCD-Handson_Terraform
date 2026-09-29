output "rds_address" {
  value = aws_db_instance.rds.address
}

output "rds_port" {
  value = aws_db_instance.rds.port
}

output "rds_db_name" {
  value = aws_db_instance.rds.db_name
}

output "rds_username" {
  value = aws_db_instance.rds.username
}

output "rds_master_secret_arn" {
  value = aws_db_instance.rds.master_user_secret[0].secret_arn
}
