{{- define "openmoodle.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- define "openmoodle.fullname" -}}
{{- if .Values.fullnameOverride }}{{ .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}{{ else }}{{ printf "%s-%s" .Release.Name (include "openmoodle.name" .) | trunc 63 | trimSuffix "-" }}{{ end }}
{{- end }}
{{- define "openmoodle.labels" -}}
app.kubernetes.io/name: {{ include "openmoodle.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}