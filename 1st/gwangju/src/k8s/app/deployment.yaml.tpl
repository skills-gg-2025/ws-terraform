apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: green-rollout
  namespace: skills
spec:
  replicas: 2
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: green
  template:
    metadata:
      labels:
        app: green
    spec:
      terminationGracePeriodSeconds: 60
      nodeSelector:
        node: app
      tolerations:
      - key: node
        operator: Equal
        value: app
        effect: NoSchedule
      containers:
      - name: green
        image: ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-2.amazonaws.com/green:latest
        imagePullPolicy: Always
        envFrom:
        - secretRef:
            name: db-secret
        ports:
        - containerPort: 8080
  strategy:
    blueGreen:
      activeService: green-svc
      autoPromotionEnabled: true
---
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: red-rollout
  namespace: skills
spec:
  replicas: 2
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: red
  template:
    metadata:
      labels:
        app: red
    spec:
      terminationGracePeriodSeconds: 60
      nodeSelector:
        node: app
      tolerations:
      - key: node
        operator: Equal
        value: app
        effect: NoSchedule
      containers:
      - name: red
        image: ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-2.amazonaws.com/red:latest
        imagePullPolicy: Always
        envFrom:
        - secretRef:
            name: db-secret
        ports:
        - containerPort: 8080
  strategy:
    blueGreen:
      activeService: red-svc
      autoPromotionEnabled: true