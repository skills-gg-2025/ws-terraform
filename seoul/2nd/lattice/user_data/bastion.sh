#!/bin/bash
dnf update -y
dnf install -y awscli jq curl unzip

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Configure AWS CLI to use instance profile
aws configure set region ap-southeast-1