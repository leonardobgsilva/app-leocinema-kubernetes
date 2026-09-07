{{/*
  leocinema.name always returns the chart name ("leocinema"),
  regardless of the Helm release name.

  This keeps Secret and ConfigMap names stable across all three
  theme deployments (red/green/blue), each in its own namespace.
  Isolation is achieved by namespace, not by resource name prefix.
*/}}
{{- define "leocinema.name" -}}
{{- "leocinema" -}}
{{- end -}}
