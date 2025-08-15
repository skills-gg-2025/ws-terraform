resource "tls_private_key" "ci_app_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ci_app_keypair" {
  key_name   = "key"
  public_key = file("key.pem.pub")
}

