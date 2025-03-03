{{- define "bny-base.hpa" -}}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ .Values.appName }}-hpa
  namespace: {{ .Values.namespace | default "default" }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ .Values.appName }}
  minReplicas: {{ .Values.hpa.minReplicas | default 2 }}
  maxReplicas: {{ .Values.hpa.maxReplicas | default 10 }}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.hpa.targetCPU | default 70 }}
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: {{ .Values.hpa.targetMemory | default 80 }}
{{- end }}
