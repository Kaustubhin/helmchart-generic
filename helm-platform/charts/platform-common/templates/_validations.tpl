{{/* ------------------------------------------------------------------
     Fail-fast policy gate. Runs at render time, so a bad value breaks the
     pipeline instead of the cluster. Collect ALL errors before failing -
     one `fail` per mistake makes people fix things one round-trip at a time.
     ------------------------------------------------------------------ */}}
{{- define "platform-common.validate" -}}
{{- $e := list -}}

{{- if not (dig "image" "repository" "" .Values) -}}
  {{- $e = append $e "image.repository is required" -}}
{{- end -}}

{{- $tag := dig "image" "tag" "" .Values | default .Chart.AppVersion -}}
{{- if not (dig "image" "digest" "" .Values) -}}
  {{- if or (eq $tag "latest") (eq $tag "") -}}
    {{- $e = append $e "image.tag must be an immutable tag or image.digest must be set ('latest' is banned)" -}}
  {{- end -}}
{{- end -}}

{{- $allowed := dig "global" "allowedRegistries" (list) .Values -}}
{{- $reg := dig "image" "registry" "" .Values | default (dig "global" "imageRegistry" "" .Values) -}}
{{- if and (gt (len $allowed) 0) (not (has $reg $allowed)) -}}
  {{- $e = append $e (printf "image registry %q is not in global.allowedRegistries %v" $reg $allowed) -}}
{{- end -}}

{{- $res := .Values.resources | default dict -}}
{{- if or (not (dig "limits" "memory" "" $res)) (not (dig "requests" "cpu" "" $res)) -}}
  {{- $e = append $e "resources.requests.cpu and resources.limits.memory are required (no burstable-by-accident workloads)" -}}
{{- end -}}

{{- $psc := .Values.podSecurityContext | default dict -}}
{{- if not (eq (dig "runAsNonRoot" false $psc | toString) "true") -}}
  {{- $e = append $e "podSecurityContext.runAsNonRoot must be true" -}}
{{- end -}}

{{- $csc := .Values.containerSecurityContext | default dict -}}
{{- if eq (dig "allowPrivilegeEscalation" true $csc | toString) "true" -}}
  {{- $e = append $e "containerSecurityContext.allowPrivilegeEscalation must be false" -}}
{{- end -}}
{{- if not (has "ALL" (dig "capabilities" "drop" (list) $csc)) -}}
  {{- $e = append $e "containerSecurityContext.capabilities.drop must include ALL" -}}
{{- end -}}

{{- if dig "policy" "requireProbes" false .Values -}}
  {{- if not .Values.readinessProbe -}}
    {{- $e = append $e "readinessProbe is required when policy.requireProbes=true" -}}
  {{- end -}}
{{- end -}}

{{- if and (dig "autoscaling" "enabled" false .Values) (dig "policy" "requireHA" false .Values) -}}
{{- if lt (int (dig "autoscaling" "minReplicas" 1 .Values)) 2 -}}
  {{- $e = append $e "autoscaling.minReplicas must be >= 2 when policy.requireHA=true" -}}
{{- end -}}
{{- end -}}

{{- if $e -}}
{{- fail (printf "\n\n[%s] values validation failed:\n  - %s\n" .Chart.Name (join "\n  - " $e)) -}}
{{- end -}}
{{- end -}}
