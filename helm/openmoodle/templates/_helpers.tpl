{{- define "openmoodle.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- define "openmoodle.fullname" -}}
{{- if .Values.fullnameOverride }}{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}{{ else }}{{ printf "%s-%s" .Release.Name (include "openmoodle.name" .) | trunc 63 | trimSuffix "-" }}{{ end -}}
{{- end -}}

{{- define "openmoodle.labels" -}}
app.kubernetes.io/name: {{ include "openmoodle.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "openmoodle.secretName" -}}
{{- default (printf "%s-secrets" (include "openmoodle.fullname" .)) .Values.secrets.existingSecret -}}
{{- end -}}

{{- define "openmoodle.databaseHost" -}}
{{- default (printf "%s-postgresql" .Release.Name) .Values.database.host -}}
{{- end -}}

{{- define "openmoodle.postgresSecretName" -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end -}}

{{- define "openmoodle.postgresSecretKey" -}}
password
{{- end -}}

{{- define "openmoodle.redisHost" -}}
{{- default (printf "%s-redis-cluster" .Release.Name) .Values.redis.host -}}
{{- end -}}

{{- define "openmoodle.imagePullSecrets" -}}
{{- if .Values.moodle.imagePullSecrets }}
{{- toYaml .Values.moodle.imagePullSecrets | nindent 8 }}
{{- end }}
{{- end -}}
