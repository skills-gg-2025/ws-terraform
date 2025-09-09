#!/bin/bash
cd /home/ec2-user/pipeline/artifact/green
zip -r /tmp/artifact.zip .
aws s3 cp /tmp/artifact.zip s3://ws25-cd-green-artifact-108/artifact.zip