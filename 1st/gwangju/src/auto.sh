#!/bin/bash
set -euo pipefail

trap 'echo "Error: script run failed"; exit 1' ERR
cd gj2025-repository
git branch app-green
git checkout app-green
git rm -rf .
cp ../k8s/argocd/green/app-green/* .
git add .
git commit -m "add app-green"
git push -u origin app-green
git branch gitops-green
git checkout gitops-green
git rm -rf .
cp ../k8s/argocd/green/gitops-green/* .
git add .
git commit -m "add gitops-green"
git push -u origin gitops-green
git branch app-red
git checkout app-red
git rm -rf .
cp ../k8s/argocd/red/app-red/* .
git add .
git commit -m "add app-red"
git push -u origin app-red
git branch gitops-red
git checkout gitops-red
git rm -rf .
cp ../k8s/argocd/red/gitops-red/* .
git add .
git commit -m "add gitops-red"
git push -u origin gitops-red
