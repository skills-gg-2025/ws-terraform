#!/bin/bash

# EFS 파일 시스템 ID와 액세스 포인트 ID
EFS_ID="fs-0458891f10e7afe03"
AP_ID="fsap-059322e83eb7cd9ce"

# 마운트 포인트 생성
sudo mkdir -p /mnt/efs

# EFS 마운트 (액세스 포인트 사용, TLS 암호화)
sudo mount -t efs -o tls,accesspoint=$AP_ID $EFS_ID /mnt/efs

# /etc/fstab에 추가하여 재부팅 후에도 마운트 유지
echo "$EFS_ID.efs.eu-west-1.amazonaws.com:/ /mnt/efs efs defaults,_netdev,tls,accesspoint=$AP_ID" | sudo tee -a /etc/fstab

# hello-101.txt 파일이 없으면 생성
if [ ! -f /mnt/efs/hello-101.txt ]; then
    echo "Hello from WorldSkills" | sudo tee /mnt/efs/hello-101.txt
    sudo chown ec2-user:ec2-user /mnt/efs/hello-101.txt
fi

echo "EFS mounted successfully at /mnt/efs"