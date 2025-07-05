output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_ssh_command" {
  description = "SSH command to connect to bastion"
  value       = "ssh -i nsl-bastion-key.pem ec2-user@${aws_instance.bastion.public_ip}"
}

output "bastion_key_file" {
  description = "Private key file location"
  value       = "${path.module}/nsl-bastion-key.pem"
}

output "bastion_instance_id" {
  description = "Instance ID of bastion host"
  value       = aws_instance.bastion.id
}

output "dynamodb_tables" {
  description = "DynamoDB table names"
  value = {
    users       = aws_dynamodb_table.users.name
    orders      = aws_dynamodb_table.orders.name
    order_items = aws_dynamodb_table.order_items.name
    products    = aws_dynamodb_table.products.name
    categories  = aws_dynamodb_table.categories.name
  }
}

output "dax_cluster_endpoint" {
  description = "DAX cluster endpoint"
  value       = aws_dax_cluster.nsl_dax.cluster_address
}

output "vpc_id" {
  description = "Default VPC ID"
  value       = data.aws_vpc.default.id
}