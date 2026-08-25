{{- define "openmoodle.initContainers" -}}
- name: wait-for-db
  image: "mysql:8.0"
  imagePullPolicy: IfNotPresent
  securityContext:
    runAsNonRoot: true
    runAsUser: 999
    allowPrivilegeEscalation: false
    capabilities: { drop: [ALL] }
  command:
    - /bin/sh
    - -c
    - |
      echo "Waiting for database at {{ include "openmoodle.databaseHost" . }}..."
      for i in $(seq 1 60); do
        if mysqladmin ping -h"{{ include "openmoodle.databaseHost" . }}" -u"{{ .Values.database.user }}" -p"${DB_PASSWORD}" --silent; then
          echo "Database is ready."
          exit 0
        fi
        echo "Retrying in 2s... ($i/60)"
        sleep 2
      done
      echo "Database not ready after 120s, failing."
      exit 1
  env:
    - { name: DB_PASSWORD, valueFrom: { secretKeyRef: { name: {{ include "openmoodle.secretName" . }}, key: database-password } } }
  volumeMounts:
    - { name: config, mountPath: /var/www/html/config.php, subPath: config.php, readOnly: true }
    - { name: tmp, mountPath: /tmp }
  resources:
    requests: { cpu: 100m, memory: 128Mi }
    limits: { cpu: 500m, memory: 256Mi }
{{- end -}}