#!/bin/bash

# EFS 마운트 확인
if ! mountpoint -q /mnt/efs; then
    echo "EFS not mounted, attempting to mount..."
    sudo mount -a
    sleep 5
fi

# 디렉토리 권한 확인 및 수정
sudo chown ec2-user:ec2-user /mnt/efs
sudo chmod 755 /mnt/efs

# 파일 생성
echo "Hello from WorldSkills" > /mnt/efs/hello-101.txt
chown ec2-user:ec2-user /mnt/efs/hello-101.txt
chmod 644 /mnt/efs/hello-101.txt

echo "File created successfully!"
ls -la /mnt/efs/