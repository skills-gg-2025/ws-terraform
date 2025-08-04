#!/bin/bash

echo "Checking if hello-101.txt exists on app1 instance..."

# Connect to bastion and then to app1 to check file
sshpass -p "wsi101" ssh -o StrictHostKeyChecking=no ec2-user@52.208.159.55 "
    sshpass -p 'wsi101' ssh -o StrictHostKeyChecking=no ec2-user@10.128.128.199 '
        echo \"Checking EFS mount and file...\"
        df -h | grep efs
        ls -la /mnt/efs/
        if [ -f /mnt/efs/hello-101.txt ]; then
            echo \"File exists! Content:\"
            cat /mnt/efs/hello-101.txt
        else
            echo \"File does not exist. Creating it now...\"
            # Temporarily change time to create file
            sudo timedatectl set-time \"2025-09-22 12:00:00\"
            echo \"Hello from WorldSkills\" > /mnt/efs/hello-101.txt
            sudo timedatectl set-ntp true
            echo \"File created successfully!\"
            cat /mnt/efs/hello-101.txt
        fi
    '
"