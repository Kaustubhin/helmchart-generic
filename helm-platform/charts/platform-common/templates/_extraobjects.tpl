{{/* ------------------------------------------------------------------
     Escape hatch. Lets a consuming team ship an arbitrary manifest
     (VPA, ServiceMonitor, Kyverno exception, SealedSecret...) through
     values.yaml instead of forking the chart. Each entry is rendered
     through `tpl`, so it can reference .Release / .Values.
     ------------------------------------------------------------------ */}}
{{- define "platform-common.extraObjects" -}}
{{- range $i, $obj := (.Values.extraObjects | default list) }}
---
{{ include "platform-common.tpl" (dict "value" $obj "ctx" $) }}
{{- end }}
{{- end -}}
