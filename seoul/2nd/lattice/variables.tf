variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "public_key" {
  description = "Public key for EC2 instances"
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKJxEeYZri08zdNwu/5RAtCkj7BMzA46zfx5/oACupEp/6kM184vtLRGlkEtUooHz1ihUJt7S/7mN4Mi22dfRSqsSr+/bZUIZNFVEqiRWCiclE1Ndh6EMeF9ZRbjvtniaOHWfMvXXLTFyUCar4WCN9PGPnS/9SC21jPtX1Eo8CLoGPCEcrTRz9NCikUdDN+WtR/shyv0oZseS/FPjWx12lqAEPT42ZJ2WK3XZgkL2r7Az3efdTlfPBlwKS1vLTQEsjfR4R78pe88CHzmZGXe/T3SonAiv3hksHIqie/VBKFd4qwUf0t5y+L2WilhxPIYwNwyf1jYhpBJmI0MeKVqd1 kmit@DESKTOP-EAE5CEH"
}