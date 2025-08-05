#!/bin/bash

# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f ./main-key -N ""

echo "SSH key pair generated:"
echo "Private key: ./main-key"
echo "Public key: ./main-key.pub"
echo ""
echo "Copy the following public key to your variables.tf file:"
cat ./main-key.pub