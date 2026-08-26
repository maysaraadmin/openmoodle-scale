{{- define "openmoodle.initContainers" -}}
- name: wait-for-db
  image: "postgres:16"
  imagePullPolicy: IfNotPresent
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    allowPrivilegeEscalation: false
    capabilities: { drop: [ALL] }
    readOnlyRootFilesystem: true
  command:
    - /bin/sh
    - -c
    - |
      echo "Waiting for database at {{ include "openmoodle.databaseHost" . }}..."
      export PGPASSWORD="${DB_PASSWORD}"
      for i in $(seq 1 60); do
        if pg_isready -h "{{ include "openmoodle.databaseHost" . }}" -U "{{ .Values.database.user }}" -d "{{ .Values.database.name }}" >/dev/null 2>&1; then
          echo "Database is ready."
          exit 0
        fi
        echo "Retrying in 2s... ($i/60)"
        sleep 2
      done
      echo "Database not ready after 120s, failing."
      exit 1
  env:
    - { name: DB_PASSWORD, valueFrom: { secretKeyRef: { name: {{ include "openmoodle.postgresSecretName" . }}, key: {{ include "openmoodle.postgresSecretKey" . } } } }
  volumeMounts:
    - { name: config, mountPath: /var/www/html/config.php, subPath: config.php, readOnly: true }
    - { name: tmp, mountPath: /tmp }
  resources:
    requests: { cpu: 100m, memory: 128Mi }
    limits: { cpu: 500m, memory: 256Mi }
{{- end -}}
