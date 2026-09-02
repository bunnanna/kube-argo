{{- define "service.fullname" -}}
{{ .Values.project }}-{{ .Values.service }}
{{- end -}}

{{- define "service.name" -}}
{{ .Values.service }}
{{- end -}}

{{- define "service.springConfigName" -}}
{{ .Values.project }},{{ .Values.service }}
{{- end -}}

{{- define "service.otelAgentPath" -}}
{{ .Values.otel.mountPath }}/{{ .Values.otel.agentJar }}
{{- end -}}

{{- define "service.otelConfigPath" -}}
{{ .Values.otel.mountPath }}/{{ .Values.otel.configFile }}
{{- end -}}
