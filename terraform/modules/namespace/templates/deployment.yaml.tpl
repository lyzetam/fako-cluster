apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${app_name}
  namespace: ${app_name}
  labels:
    app.kubernetes.io/name: ${app_name}
    app.kubernetes.io/component: ${component}
spec:
  replicas: ${replicas}
  selector:
    matchLabels:
      app.kubernetes.io/name: ${app_name}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ${app_name}
    spec:
      imagePullSecrets:
        - name: dockerhub-registry
      containers:
        - name: ${app_name}
          image: ${image}
          imagePullPolicy: Always
          ports:
            - containerPort: ${port}
              name: http
%{ if enable_secrets || length(env_vars) > 0 ~}
          env:
%{ for key, value in env_vars ~}
            - name: ${key}
              value: "${value}"
%{ endfor ~}
%{ if enable_secrets ~}
          envFrom:
            - secretRef:
                name: ${app_name}-secrets
%{ endif ~}
%{ endif ~}
%{ if enable_storage ~}
          volumeMounts:
            - name: data
              mountPath: ${storage_mount_path}
%{ endif ~}
          resources:
            requests:
              memory: "${resources.requests_memory}"
              cpu: "${resources.requests_cpu}"
            limits:
              memory: "${resources.limits_memory}"
              cpu: "${resources.limits_cpu}"
          livenessProbe:
            httpGet:
              path: ${health_check_path}
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: ${health_check_path}
              port: http
            initialDelaySeconds: 10
            periodSeconds: 5
%{ if enable_storage ~}
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: ${app_name}-pvc
%{ endif ~}
