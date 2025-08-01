{{/*
Expand the name of the chart.
*/}}
{{- define "ehrbase.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ehrbase.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "ehrbase.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ehrbase.labels" -}}
helm.sh/chart: {{ include "ehrbase.chart" . }}
{{ include "ehrbase.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ehrbase.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ehrbase.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ehrbase.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ehrbase.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the basic authentication secret name
*/}}
{{- define "ehrbase.auth.secretName" -}}
{{- default (printf "%s-auth-users" (include "ehrbase.fullname" .)) .Values.auth.basic.existingSecret }}
{{- end }}

{{/*
Return the admin username key to be retrieved from the basic authentication secret
*/}}
{{- define "ehrbase.auth.secretAdminUsernameKey" -}}
{{- default "admin-username" .Values.auth.basic.existingSecretAdminUsernameKey }}
{{- end }}

{{/*
Return the admin password key to be retrieved from the basic authentication secret
*/}}
{{- define "ehrbase.auth.secretAdminPasswordKey" -}}
{{- default "admin-password" .Values.auth.basic.existingSecretAdminPasswordKey }}
{{- end }}

{{/*
Return the username key to be retrieved from the basic authentication secret
*/}}
{{- define "ehrbase.auth.secretUsernameKey" -}}
{{- default "username" .Values.auth.basic.existingSecretUsernameKey }}
{{- end }}

{{/*
Return the password key to be retrieved from the basic authentication secret
*/}}
{{- define "ehrbase.auth.secretPasswordKey" -}}
{{- default "password" .Values.auth.basic.existingSecretPasswordKey }}
{{- end }}

{{/*
Return the EHRbase port based on TLS configuration
*/}}
{{- define "ehrbase.port" -}}
{{- ternary .Values.containerPorts.https .Values.containerPorts.http .Values.tls.enabled }}
{{- end }}

{{/*
Return the EHRbase port name based on TLS configuration
*/}}
{{- define "ehrbase.portName" -}}
{{- ternary "https" "http" .Values.tls.enabled }}
{{- end }}

{{/*
Return the PostgreSQL fullname
*/}}
{{- define "ehrbase.postgres.fullname" -}}
{{- default (printf "%s-postgresql" (include "ehrbase.fullname" .)) .Values.postgresql.fullnameOverride }}
{{- end }}

{{/*
Return the PostgreSQL host
*/}}
{{- define "ehrbase.postgres.host" -}}
{{- if .Values.postgresql.enabled }}
{{- ternary (printf "%-primary" (include "ehrbase.postgres.fullname" .)) (include "ehrbase.postgres.fullname" .) (eq .Values.postgresql.architecture "replication") }}
{{- else }}
{{- .Values.externalPostgresql.host }}
{{- end }}
{{- end }}

{{/*
Return the PostgreSQL port
*/}}
{{- define "ehrbase.postgres.port" -}}
{{- ternary .Values.postgresql.primary.service.ports.postgresql .Values.externalPostgresql.port .Values.postgresql.enabled }}
{{- end }}

{{/*
Return the PostgreSQL database name
*/}}
{{- define "ehrbase.postgres.database" -}}
{{- ternary .Values.postgresql.auth.database .Values.externalPostgresql.database .Values.postgresql.enabled }}
{{- end }}

{{/*
Return the PostgreSQL JDBC URL
*/}}
{{- define "ehrbase.postgres.url" -}}
{{- printf "jdbc:postgresql://%s:%s/%s" (include "ehrbase.postgres.host" .) (include "ehrbase.postgres.port" .) (include "ehrbase.postgres.database" .) }}
{{- end }}

{{/*
Return the PostgreSQL admin user
*/}}
{{- define "ehrbase.postgres.adminUser" -}}
{{- ternary "postgres" .Values.externalPostgresql.user .Values.postgresql.enabled }}
{{- end }}

{{/*
Return the PostgreSQL user
*/}}
{{- define "ehrbase.postgres.user" -}}
{{- ternary .Values.postgresql.auth.username .Values.externalPostgresql.username .Values.postgresql.enabled }}
{{- end }}

{{/*
Return the passwords secret for PostgreSQL
*/}}
{{- define "ehrbase.postgres.secretName" -}}
{{- if .Values.postgresql.enabled }}
{{- default (include "ehrbase.postgres.fullname" .) .Values.postgresql.auth.existingSecret }}
{{- else }}
{{- default (printf "%s-postgresql" (include "ehrbase.fullname" .)) .Values.externalPostgresql.existingSecret }}
{{- end }}
{{- end }}

{{/*
Return the admin password key to be retrieved from the PostgreSQL secret
*/}}
{{- define "ehrbase.postgres.secretAdminPasswordKey" -}}
{{- if .Values.postgresql.enabled }}
{{- default "password" .Values.postgresql.auth.secretKeys.adminPasswordKey }}
{{- else }}
{{- default "password" .Values.externalPostgresql.existingSecretPasswordKey }}
{{- end }}
{{- end }}

{{/*
Return the user password key to be retrieved from the PostgreSQL secret
*/}}
{{- define "ehrbase.postgres.secretUserPasswordKey" -}}
{{- $defaultKey := "password" }}
{{- if .Values.postgresql.enabled }}
{{- default $defaultKey .Values.postgresql.auth.secretKeys.userPasswordKey }}
{{- else }}
{{- default $defaultKey .Values.externalPostgresql.existingSecretPasswordKey }}
{{- end }}
{{- end }}

{{/*
Return the Redis fullname
*/}}
{{- define "ehrbase.redis.fullname" -}}
{{- default (printf "%s-redis" (include "ehrbase.fullname" .)) .Values.redis.fullnameOverride }}
{{- end }}

{{/*
Return the Redis host
*/}}
{{- define "ehrbase.redis.host" -}}
{{- ternary (printf "%s-master" (include "ehrbase.redis.fullname" .)) .Values.externalRedis.host .Values.redis.enabled -}}
{{- end }}

{{/*
Return the Redis port
*/}}
{{- define "ehrbase.redis.port" -}}
{{- ternary .Values.redis.master.service.ports.redis .Values.externalRedis.port .Values.redis.enabled -}}
{{- end }}

{{/*
Return the password secret for Redis
*/}}
{{- define "ehrbase.redis.secretName" -}}
{{- if .Values.redis.enabled }}
{{- default (include "ehrbase.redis.fullname" .) .Values.redis.auth.existingSecret }}
{{- else }}
{{- default (printf "%s-redis" (include "ehrbase.fullname" .)) .Values.externalRedis.existingSecret }}
{{- end }}
{{- end }}

{{/*
Return the password key to be retrieved from the Redis secret
*/}}
{{- define "ehrbase.redis.secretPasswordKey" -}}
{{- $defaultKey := "redis-password" }}
{{- if .Values.redis.enabled }}
{{- default $defaultKey .Values.redis.auth.existingSecretPasswordKey }}
{{- else }}
{{- default $defaultKey .Values.externalRedis.existingSecretPasswordKey }}
{{- end }}
{{- end }}

{{/*
Return the TLS secret name
*/}}
{{- define "ehrbase.tls.secretName" -}}
{{- default (printf "%s-internal-tls" (include "ehrbase.fullname" .)) .Values.tls.existingSecret }}
{{- end }}
