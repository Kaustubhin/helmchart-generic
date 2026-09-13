{{/* ------------------------------------------------------------------
     Naming
     ------------------------------------------------------------------ */}}
{{- define "platform-common.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "platform-common.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "platform-common.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* ------------------------------------------------------------------
     Labels. selectorLabels are IMMUTABLE on a Deployment - never add
     anything volatile (version, commit sha) to them.
     ------------------------------------------------------------------ */}}
{{- define "platform-common.selectorLabels" -}}
app.kubernetes.io/name: {{ include "platform-common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "platform-common.labels" -}}
helm.sh/chart: {{ include "platform-common.chart" . }}
{{ include "platform-common.selectorLabels" . }}
app.kubernetes.io/version: {{ dig "image" "tag" "" .Values | default .Chart.AppVersion | quote }}
app.kubernetes.io/component: {{ .Values.component | default "service" }}
app.kubernetes.io/part-of: {{ .Values.partOf | default .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with (dig "global" "commonLabels" (dict) .Values) }}
{{ toYaml . }}
{{- end }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "platform-common.annotations" -}}
{{- $a := merge (dict) (.Values.commonAnnotations | default dict) (dig "global" "commonAnnotations" (dict) .Values) -}}
{{- with $a }}{{ toYaml . }}{{- end }}
{{- end -}}

{{/* ------------------------------------------------------------------
     Image reference: registry/repository:tag or registry/repository@digest
     `dig` gives nil-safe access into .Values.global, which does not exist
     unless somebody set it.
     ------------------------------------------------------------------ */}}
{{- define "platform-common.image" -}}
{{- $registry := .Values.image.registry | default (dig "global" "imageRegistry" "" .Values) -}}
{{- $repo := .Values.image.repository -}}
{{- $ref := "" -}}
{{- if .Values.image.digest -}}
{{- $ref = printf "%s@%s" $repo .Values.image.digest -}}
{{- else -}}
{{- $ref = printf "%s:%s" $repo (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}
{{- if $registry -}}
{{- printf "%s/%s" $registry $ref -}}
{{- else -}}
{{- $ref -}}
{{- end -}}
{{- end -}}

{{- define "platform-common.serviceAccountName" -}}
{{- if dig "serviceAccount" "create" false .Values -}}
{{- default (include "platform-common.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" (dig "serviceAccount" "name" "" .Values) -}}
{{- end -}}
{{- end -}}

{{/* ------------------------------------------------------------------
     Render a value that may itself contain Go template syntax.
     Lets consumers write:  host: "{{ .Release.Name }}.apps.example.com"
     usage: {{ include "platform-common.tpl" (dict "value" .Values.x "ctx" $) }}
     ------------------------------------------------------------------ */}}
{{- define "platform-common.tpl" -}}
{{- $v := .value -}}
{{- if typeIs "string" $v -}}
{{- tpl $v .ctx -}}
{{- else -}}
{{- tpl ($v | toYaml) .ctx -}}
{{- end -}}
{{- end -}}

{{/* ------------------------------------------------------------------
     API-version shims: survive cluster upgrades without forking the chart.
     ------------------------------------------------------------------ */}}
{{- define "platform-common.capabilities.hpa.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "autoscaling/v2" -}}
autoscaling/v2
{{- else -}}
autoscaling/v2beta2
{{- end -}}
{{- end -}}

{{- define "platform-common.capabilities.pdb.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "policy/v1" -}}
policy/v1
{{- else -}}
policy/v1beta1
{{- end -}}
{{- end -}}
