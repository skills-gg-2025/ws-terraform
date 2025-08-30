apiVersion: v1
kind: ServiceAccount
metadata:
  name: access-secrets
  namespace: wsk25
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::${account_id}:role/wsk-access-secrets-role