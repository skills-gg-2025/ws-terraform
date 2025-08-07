#!/bin/bash
if ! mountpoint -q /mnt/efs; then
    echo "EFS not mounted, attempting to mount..."
    sudo mount -a
    sleep 5
fi

sudo chown ec2-user:ec2-user /mnt/efs
sudo chmod 755 /mnt/efs

echo "Hello from WorldSkills" > /mnt/efs/hello-101.txt
chown ec2-user:ec2-user /mnt/efs/hello-101.txt
chmod 644 /mnt/efs/hello-101.txt

echo "File created successfully!"
ls -la /mnt/efs/