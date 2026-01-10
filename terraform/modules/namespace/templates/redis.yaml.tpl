apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: ${app_name}
  labels:
    app.kubernetes.io/name: redis
    app.kubernetes.io/component: cache
    app.kubernetes.io/part-of: ${part_of}
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: redis
      app.kubernetes.io/part-of: ${part_of}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: redis
        app.kubernetes.io/part-of: ${part_of}
    spec:
      imagePullSecrets:
        - name: dockerhub-registry
      containers:
        - name: redis
          image: redis:7-alpine
          ports:
            - containerPort: 6379
              name: redis
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "128Mi"
              cpu: "100m"
          livenessProbe:
            exec:
              command:
                - redis-cli
                - ping
            initialDelaySeconds: 10
            periodSeconds: 5
          readinessProbe:
            exec:
              command:
                - redis-cli
                - ping
            initialDelaySeconds: 5
            periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: ${app_name}
  labels:
    app.kubernetes.io/name: redis
    app.kubernetes.io/component: cache
    app.kubernetes.io/part-of: ${part_of}
spec:
  type: ClusterIP
  ports:
    - port: 6379
      targetPort: redis
      protocol: TCP
      name: redis
  selector:
    app.kubernetes.io/name: redis
    app.kubernetes.io/part-of: ${part_of}
