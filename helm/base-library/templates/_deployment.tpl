{{- define "bny-base.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.appName }}
  namespace: {{ .Values.namespace | default "default" }}
  labels:
    app: {{ .Values.appName }}
    team: {{ .Values.team }}
    env: {{ .Values.env }}
    version: {{ .Values.image.tag | quote }}
  annotations:
    deployment.kubernetes.io/revision: "1"
spec:
  replicas: {{ .Values.replicas | default 2 }}
  selector:
    matchLabels:
      app: {{ .Values.appName }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: {{ .Values.appName }}
        version: {{ .Values.image.tag | quote }}
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: {{ .Values.metricsPort | default "8080" | quote }}
    spec:
      serviceAccountName: {{ .Values.appName }}-sa
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 2000
      containers:
      - name: {{ .Values.appName }}
        image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
        imagePullPolicy: Always
        ports:
        - containerPort: {{ .Values.containerPort | default 8080 }}
        resources:
          requests:
            cpu:    {{ .Values.resources.requests.cpu    | default "100m" }}
            memory: {{ .Values.resources.requests.memory | default "128Mi" }}
          limits:
            cpu:    {{ .Values.resources.limits.cpu    | default "500m" }}
            memory: {{ .Values.resources.limits.memory | default "512Mi" }}
        readinessProbe:
          httpGet:
            path: /health
            port: {{ .Values.containerPort | default 8080 }}
          initialDelaySeconds: 10
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: {{ .Values.containerPort | default 8080 }}
          initialDelaySeconds: 30
          periodSeconds: 10
        env:
        - name: ENV
          value: {{ .Values.env }}
        - name: APP_NAME
          value: {{ .Values.appName }}
{{- end }}
