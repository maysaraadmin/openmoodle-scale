{{- define "openmoodle.webContainer" -}}
- name: moodle-web
  image: "{{ .Values.global.imageRegistry }}/{{ .Values.moodle.nginx.repository }}:{{ .Values.moodle.nginx.tag }}"
  imagePullPolicy: {{ .Values.moodle.nginx.pullPolicy }}
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
    allowPrivilegeEscalation: false
    capabilities: { drop: [ALL] }
    readOnlyRootFilesystem: true
  ports: [{ name: http, containerPort: 8080 }]
  readinessProbe:
    httpGet: { path: {{ .Values.readinessProbe.path | default "/health" }}, port: {{ .Values.readinessProbe.port | default "http" }} }
    initialDelaySeconds: {{ .Values.readinessProbe.initialDelaySeconds | default 10 }}
    periodSeconds: {{ .Values.readinessProbe.periodSeconds | default 10 }}
    timeoutSeconds: {{ .Values.readinessProbe.timeoutSeconds | default 3 }}
    failureThreshold: {{ .Values.readinessProbe.failureThreshold | default 3 }}
  livenessProbe:
    httpGet: { path: {{ .Values.livenessProbe.path | default "/health" }}, port: {{ .Values.livenessProbe.port | default "http" }} }
    initialDelaySeconds: {{ .Values.livenessProbe.initialDelaySeconds | default 30 }}
    periodSeconds: {{ .Values.livenessProbe.periodSeconds | default 20 }}
    timeoutSeconds: {{ .Values.livenessProbe.timeoutSeconds | default 5 }}
    failureThreshold: {{ .Values.livenessProbe.failureThreshold | default 6 }}
  lifecycle:
    {{- if .Values.preStopHook.enabled }}
    preStop:
      exec:
        command: ["/bin/sh", "-c", "echo 'Graceful shutdown: stopping nginx'; nginx -s quit; sleep {{ .Values.preStopHook.timeoutSeconds | default 30 }}"]
    {{- end }}
  volumeMounts:
    - { name: tmp, mountPath: /tmp }
    - { name: nginx-cache, mountPath: /var/cache/nginx }
    - { name: nginx-run, mountPath: /var/run }
  resources:
    requests: { cpu: 100m, memory: 128Mi }
    limits: { cpu: 500m, memory: 256Mi }
{{- end -}}