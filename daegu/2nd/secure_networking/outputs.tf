output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.dns_vpc.id
}

output "public_subnet_id" {
  description = "Public Subnet ID"
  value       = aws_subnet.public_subnet.id
}

output "firewall_subnet_id" {
  description = "Firewall Subnet ID"
  value       = aws_subnet.firewall_subnet.id
}

output "firewall_id" {
  description = "Network Firewall ID"
  value       = aws_networkfirewall_firewall.dns_firewall.id
}

output "ec2_public_ip" {
  description = "EC2 Instance Public IP"
  value       = aws_instance.bastion.public_ip
}

output "ec2_private_ip" {
  description = "EC2 Instance Private IP"
  value       = aws_instance.bastion.private_ip
}

output "firewall_endpoint_id" {
  description = "Network Firewall Endpoint ID"
  value       = tolist(aws_networkfirewall_firewall.dns_firewall.firewall_status[0].sync_states)[0].attachment[0].endpoint_id
}

output "ssh_connection_command" {
  description = "SSH connection command"
  value       = "ssh -i dns-bastion-key.pem ec2-user@${aws_instance.bastion.public_ip}"
}