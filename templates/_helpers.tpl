{{/*
Expand the name of the chart.
*/}}
{{- define "axxispay-helm-template.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Uses Release.Name so multiple apps can coexist in the same namespace.
*/}}
{{- define "axxispay-helm-template.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "axxispay-helm-template.labels" -}}
app: {{ include "axxispay-helm-template.fullname" . }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "axxispay-helm-template.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "axxispay-helm-template.selectorLabels" -}}
app: {{ include "axxispay-helm-template.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
