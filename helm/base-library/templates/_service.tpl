{{- define "bny-base.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.appName }}
  namespace: {{ .Values.namespace | default "default" }}
  labels:
    app: {{ .Values.appName }}
spec:
  selector:
    app: {{ .Values.appName }}
  ports:
  - port: 80
    targetPort: {{ .Values.containerPort | default 8080 }}
    protocol: TCP
  type: ClusterIP
{{- end }}
