output "bastion_public_ip" {
  description = "Public IP of the Bastion Host"
  value       = aws_eip.bastion.public_ip
}

output "service_a_private_ip" {
  description = "Private IP of Service A"
  value       = aws_instance.service_a.private_ip
}

output "service_b_private_ip" {
  description = "Private IP of Service B"
  value       = aws_instance.service_b.private_ip
}

output "lattice_service_url" {
  description = "VPC Lattice Service URL"
  value       = "https://${aws_vpclattice_service.service_b_lattice.dns_entry[0].domain_name}"
}

output "dynamodb_table_name" {
  description = "DynamoDB Table Name"
  value       = aws_dynamodb_table.service_b_table.name
}