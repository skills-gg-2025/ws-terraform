#!/bin/bash
cd /home/ec2-user/pipeline/artifact/red
zip -r /tmp/artifact.zip .
aws s3 cp /tmp/artifact.zip s3://ws25-cd-red-artifact-<NUM>/artifact.zip