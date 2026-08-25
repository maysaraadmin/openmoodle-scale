{{- define "openmoodle.appContainer" -}}
- name: moodle-app
  image: "{{ .Values.global.imageRegistry }}/{{ .Values.moodle.image.repository }}:{{ .Values.moodle.image.tag }}"
  imagePullPolicy: {{ .Values.moodle.image.pullPolicy }}
  securityContext:
    runAsNonRoot: true
    runAsUser: 33
    allowPrivilegeEscalation: false
    capabilities: { drop: [ALL] }
    readOnlyRootFilesystem: true
  ports: [{ name: fastcgi, containerPort: 9000 }]
  startupProbe:
    tcpSocket: { port: fastcgi }
    failureThreshold: 30
    periodSeconds: 2
  readinessProbe:
    tcpSocket: { port: fastcgi }
    initialDelaySeconds: 10
    periodSeconds: 10
  livenessProbe:
    tcpSocket: { port: fastcgi }
    initialDelaySeconds: 30
    periodSeconds: 20
  lifecycle:
    {{- if .Values.preStopHook.enabled }}
    preStop:
      exec:
        command: ["/bin/sh", "-c", "echo 'Graceful shutdown: sending QUIT to PHP-FPM'; kill -QUIT 1 2>/dev/null || true; sleep {{ .Values.preStopHook.timeoutSeconds | default 30 }}"]
    {{- end }}
  env:
    - { name: DB_HOST, value: {{ include "openmoodle.databaseHost" . | quote }} }
    - { name: DB_NAME, value: {{ .Values.database.name | quote }} }
    - { name: DB_USER, value: {{ .Values.database.user | quote }} }
    - name: DB_PASSWORD
      valueFrom: { secretKeyRef: { name: {{ include "openmoodle.secretName" . }}, key: database-password } }
    - name: DB_PASS
      valueFrom: { secretKeyRef: { name: {{ include "openmoodle.secretName" . }}, key: database-password } }
    - name: REDIS_PASSWORD
      valueFrom: { secretKeyRef: { name: {{ include "openmoodle.secretName" . }}, key: redis-password } }
    {{- if .Values.fileStorage.enabled }}
    - name: S3_ACCESS_KEY
      valueFrom: { secretKeyRef: { name: {{ include "openmoodle.secretName" . }}, key: s3-access-key } }
    - name: S3_SECRET_KEY
      valueFrom: { secretKeyRef: { name: {{ include "openmoodle.secretName" . }}, key: s3-secret-key } }
    {{- end }}
  volumeMounts:
    - { name: moodledata, mountPath: /var/moodledata }
    - { name: config, mountPath: /var/www/html/config.php, subPath: config.php, readOnly: true }
    - { name: tmp, mountPath: /tmp }
  resources: {{- toYaml .Values.moodle.resources | nindent 12 }}
{{- end -}}