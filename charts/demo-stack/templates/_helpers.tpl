{{- define "demo-stack.name" -}}
demo-{{ .Values.slug }}
{{- end }}

{{- define "demo-stack.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: demo-factory
demo-factory/slug: {{ .Values.slug }}
demo-factory/tier: {{ .Values.tier }}
demo-factory/expires-at: {{ .Values.expiresAt | quote }}
{{- end }}

{{- define "demo-stack.selectorLabels" -}}
app.kubernetes.io/part-of: demo-factory
demo-factory/slug: {{ .Values.slug }}
{{- end }}

{{- define "demo-stack.tierConfig" -}}
{{- index .Values.tiers .Values.tier }}
{{- end }}

{{- define "demo-stack.host" -}}
demo-{{ .Values.slug }}.{{ .Values.domain }}
{{- end }}
