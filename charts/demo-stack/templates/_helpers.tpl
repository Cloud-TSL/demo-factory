{{- define "demo-stack.prefix" -}}
{{ .Values.namePrefix | default "demo" }}
{{- end }}

{{- define "demo-stack.name" -}}
{{ include "demo-stack.prefix" . }}-{{ .Values.slug }}
{{- end }}

{{- define "demo-stack.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: demo-factory
demo-factory/slug: {{ .Values.slug }}
demo-factory/tier: {{ .Values.tier }}
{{- if .Values.expiresAt }}
demo-factory/expires-at: {{ .Values.expiresAt | quote }}
{{- end }}
{{- end }}

{{- define "demo-stack.selectorLabels" -}}
app.kubernetes.io/part-of: demo-factory
demo-factory/slug: {{ .Values.slug }}
{{- end }}

{{- define "demo-stack.tierConfig" -}}
{{- index .Values.tiers .Values.tier }}
{{- end }}

{{- define "demo-stack.host" -}}
{{ include "demo-stack.prefix" . }}-{{ .Values.slug }}.{{ .Values.domain }}
{{- end }}
