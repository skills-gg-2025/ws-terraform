output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.ci_app_server.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.ci_app_server.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i CIAppServer-key.pem ec2-user@${aws_instance.ci_app_server.public_ip}"
}

output "private_key" {
  description = "Private key for SSH access"
  value       = tls_private_key.ci_app_key.private_key_pem
  sensitive   = true
}