{{/* Define um template para gerar o nome do chart */}}
{{- define "leocinema.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
