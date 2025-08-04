#!/bin/bash
sudo timedatectl set-ntp false
sudo timedatectl set-time "2025-09-22 12:00:00"
sudo echo "Hello from WorldSkills" > /mnt/efs/hello-101.txt
sudo chown ec2-user:ec2-user /mnt/efs/hello-101.txt
sudo timedatectl set-ntp true
cat /mnt/efs/hello-101.txt