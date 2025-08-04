output "bastion_public_ip" {
  description = "Bastion host public IP"
  value       = aws_eip.bastion_eip.public_ip
}

output "efs_file_system_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.wsi_efs.id
}

output "efs_access_point_id" {
  description = "EFS access point ID"
  value       = aws_efs_access_point.wsi_efs_ap.id
}

output "app1_private_ip" {
  description = "App1 instance private IP"
  value       = aws_instance.app1.private_ip
}

output "app2_private_ip" {
  description = "App2 instance private IP"
  value       = aws_instance.app2.private_ip
}