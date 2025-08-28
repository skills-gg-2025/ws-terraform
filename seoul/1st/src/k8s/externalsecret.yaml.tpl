apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: db-secret
  namespace: wsk25
spec:
  refreshInterval: 30m
  secretStoreRef:
    name: aws-secrets
    kind: SecretStore
  target:
    name: db-secret
    creationPolicy: Owner
  data:
  - secretKey: DB_USER
    remoteRef:
      key: ${rds_secret_name}
      property: username
  - secretKey: DB_PASSWD
    remoteRef:
      key: ${rds_secret_name}
      property: password
  - secretKey: DB_URL
    remoteRef:
      key: ${db_url_secret_name}
      property: db_url