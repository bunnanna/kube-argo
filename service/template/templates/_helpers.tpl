{{- define "service.fullname" -}}
{{ .Values.project }}-{{ .Values.service }}
{{- end -}}
