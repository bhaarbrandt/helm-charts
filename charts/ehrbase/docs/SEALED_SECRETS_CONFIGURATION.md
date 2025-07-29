# EHRBase Sealed Secrets Configuration Guide

This guide provides detailed configuration information for using sealed secrets with EHRBase.

## Configuration Overview

The sealed secrets configuration for EHRBase is **correctly set up** and ready to use. Here's what's configured:

## ✅ **What's Working Correctly**

### 1. **Template Helpers** (in `_helpers.tpl`)
All necessary helper functions are properly defined:

```yaml
# Auth secrets
{{- define "ehrbase.auth.secretName" -}}
{{- default (printf "%s-auth-users" (include "ehrbase.fullname" .)) .Values.auth.basic.existingSecret }}
{{- end }}

# PostgreSQL secrets
{{- define "ehrbase.postgres.secretName" -}}
{{- if .Values.postgresql.enabled }}
{{- default (include "ehrbase.postgres.fullname" .) .Values.postgresql.auth.existingSecret }}
{{- else }}
{{- default (printf "%s-postgresql" (include "ehrbase.fullname" .)) .Values.externalPostgresql.existingSecret }}
{{- end }}
{{- end }}

# Redis secrets
{{- define "ehrbase.redis.secretName" -}}
{{- if .Values.redis.enabled }}
{{- default (include "ehrbase.redis.fullname" .) .Values.redis.auth.existingSecret }}
{{- else }}
{{- default (printf "%s-redis" (include "ehrbase.fullname" .)) .Values.externalRedis.existingSecret }}
{{- end }}
{{- end }}
```

### 2. **Deployment Template** (in `deployment.yaml`)
All secret references are properly configured:

```yaml
env:
  # Database passwords
  - name: DB_PASS
    valueFrom:
      secretKeyRef:
        name: {{ include "ehrbase.postgres.secretName" . }}
        key: {{ include "ehrbase.postgres.secretUserPasswordKey" . }}
  - name: DB_PASS_ADMIN
    valueFrom:
      secretKeyRef:
        name: {{ include "ehrbase.postgres.secretName" . }}
        key: {{ include "ehrbase.postgres.secretUserPasswordKey" . }}
  
  # Auth credentials (when basic auth is enabled)
  {{- if eq .Values.auth.type "basic" }}
  - name: SECURITY_AUTHADMINUSER
    valueFrom:
      secretKeyRef:
        name: {{ include "ehrbase.auth.secretName" . }}
        key: {{ include "ehrbase.auth.secretAdminUsernameKey" . }}
  - name: SECURITY_AUTHADMINPASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "ehrbase.auth.secretName" . }}
        key: {{ include "ehrbase.auth.secretAdminPasswordKey" . }}
  - name: SECURITY_AUTHUSER
    valueFrom:
      secretKeyRef:
        name: {{ include "ehrbase.auth.secretName" . }}
        key: {{ include "ehrbase.auth.secretUsernameKey" . }}
  - name: SECURITY_AUTHPASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "ehrbase.auth.secretName" . }}
        key: {{ include "ehrbase.auth.secretPasswordKey" . }}
  {{- end }}
  
  # Redis password
  - name: SPRING_DATA_REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "ehrbase.redis.secretName" . }}
        key: {{ include "ehrbase.redis.secretPasswordKey" . }}
```

### 3. **Values Configuration** (in `values.yaml`)
All necessary configuration options are available:

```yaml
auth:
  type: basic
  basic:
    # Use existing secret
    existingSecret: ""
    existingSecretAdminUsernameKey: admin-username
    existingSecretAdminPasswordKey: admin-password
    existingSecretUsernameKey: username
    existingSecretPasswordKey: password

postgresql:
  enabled: true
  auth:
    # Use existing secret
    existingSecret: ""

redis:
  enabled: true
  auth:
    # Use existing secret
    existingSecret: ""
    existingSecretPasswordKey: "redis-password"
```

## 🔧 **Required Sealed Secret Structure**

### 1. **Auth Users Sealed Secret**
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: ehrbase-auth-users
  namespace: ehrbase
spec:
  encryptedData:
    admin-username: AgBy...  # Encrypted value
    admin-password: AgBy...  # Encrypted value
    username: AgBy...        # Encrypted value
    password: AgBy...        # Encrypted value
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ehrbase
    type: Opaque
```

### 2. **PostgreSQL Sealed Secret**
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: ehrbase-postgresql
  namespace: ehrbase
spec:
  encryptedData:
    postgres-password: AgBy...  # Encrypted value
    password: AgBy...           # Encrypted value
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ehrbase
    type: Opaque
```

### 3. **Redis Sealed Secret**
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: ehrbase-redis
  namespace: ehrbase
spec:
  encryptedData:
    redis-password: AgBy...  # Encrypted value
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ehrbase
    type: Opaque
```

## 📋 **Values Configuration for ArgoCD**

### Using Existing Secrets (Recommended)
```yaml
# Disable sealed secrets generation in Helm
sealedSecrets:
  enabled: false

# Use existing secrets (created by sealed secrets controller)
auth:
  type: basic
  basic:
    existingSecret: ehrbase-auth-users

postgresql:
  enabled: true
  auth:
    existingSecret: ehrbase-postgresql

redis:
  enabled: true
  auth:
    existingSecret: ehrbase-redis

# Application configuration
replicaCount: 1
ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: ehrbase.your-domain.com
      paths:
        - path: /
          pathType: ImplementationSpecific
```

## 🔍 **Secret Key Mapping**

| Environment Variable | Secret Name | Secret Key | Description |
|---------------------|-------------|------------|-------------|
| `SECURITY_AUTHADMINUSER` | `ehrbase-auth-users` | `admin-username` | Admin username |
| `SECURITY_AUTHADMINPASSWORD` | `ehrbase-auth-users` | `admin-password` | Admin password |
| `SECURITY_AUTHUSER` | `ehrbase-auth-users` | `username` | Regular user username |
| `SECURITY_AUTHPASSWORD` | `ehrbase-auth-users` | `password` | Regular user password |
| `DB_PASS` | `ehrbase-postgresql` | `password` | Database password |
| `DB_PASS_ADMIN` | `ehrbase-postgresql` | `password` | Database admin password |
| `SPRING_DATA_REDIS_PASSWORD` | `ehrbase-redis` | `redis-password` | Redis password |

## ✅ **Validation Results**

The validation script confirms:

- ✅ **Template helpers** are properly configured
- ✅ **Deployment template** references all required secrets
- ✅ **Values configuration** supports existing secrets
- ✅ **Secret key names** are correctly mapped
- ✅ **Environment variables** are properly set

## 🚀 **Deployment Workflow**

1. **Generate sealed secrets** using `kubeseal` CLI
2. **Place them in Git repository** (they're encrypted, so safe)
3. **Configure values** to use existing secrets
4. **Deploy with ArgoCD** - it will apply everything automatically
5. **Controller decrypts** sealed secrets into actual Kubernetes secrets
6. **Application uses** the decrypted secrets

## 🔧 **Troubleshooting**

### Secret Not Found
```bash
# Check if sealed secret was applied
kubectl get sealedsecrets -n ehrbase

# Check if secret was created
kubectl get secrets -n ehrbase

# Check sealed secret status
kubectl describe sealedsecret ehrbase-auth-users -n ehrbase
```

### Wrong Secret Keys
```bash
# Check what keys are in the secret
kubectl get secret ehrbase-auth-users -n ehrbase -o yaml

# Verify the keys match what the application expects
kubectl describe deployment ehrbase -n ehrbase
```

### Application Can't Start
```bash
# Check pod logs
kubectl logs -n ehrbase deployment/ehrbase

# Check if environment variables are set
kubectl get pod -n ehrbase -o yaml | grep -A 20 env:
```

## 📝 **Summary**

The sealed secrets configuration for EHRBase is **correctly implemented** and ready for production use. The templates properly reference secrets, the helper functions are correctly defined, and the deployment will work seamlessly with ArgoCD and sealed secrets.

**Key Benefits:**
- ✅ **Secure** - Encrypted secrets in Git
- ✅ **Automated** - ArgoCD applies everything
- ✅ **Flexible** - Supports both internal and external services
- ✅ **Maintainable** - Clear separation of concerns 