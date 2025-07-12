output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.wsi_vpc.id
}

output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = aws_instance.wsi_bastion.public_ip
}

output "app_instance_private_ip" {
  description = "Private IP of app instance"
  value       = aws_instance.wsi_app_instance.private_ip
}

output "efs_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.wsi_efs.id
}

output "efs_access_point_id" {
  description = "ID of the EFS access point"
  value       = aws_efs_access_point.wsi_ap.id
}

output "private_key_file" {
  description = "Path to the private key file"
  value       = "wsi-key.pem"
}

