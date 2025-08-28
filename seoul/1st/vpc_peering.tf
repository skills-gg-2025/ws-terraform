# VPC Peering Connection
resource "aws_vpc_peering_connection" "wsk_vpcp" {
  peer_vpc_id = aws_vpc.wsk_app.id
  vpc_id      = aws_vpc.wsk_hub.id
  auto_accept = true

  tags = {
    Name = "wsk-vpcp"
  }
}