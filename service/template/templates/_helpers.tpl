{{- define "service.fullname" -}}
{{ .Values.project }}-{{ .Values.service }}
{{- end -}}

{{- define "service.name" -}}
{{ .Values.service }}
{{- end -}}
