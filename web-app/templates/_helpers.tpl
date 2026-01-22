{{/*
Return the name of the chart
*/}}
{{- define "web-app.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{/*
Return the full name of the chart (release name + chart name)
*/}}
{{- define "web-app.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
