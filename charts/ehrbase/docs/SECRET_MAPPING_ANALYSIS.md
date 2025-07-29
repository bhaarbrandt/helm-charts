# Secret Mapping Analysis: Sealed Secrets vs Values Configuration

This document provides a detailed analysis of how sealed secrets will correctly replace the values configuration for EHRBase.

## 🔍 **Current Values Configuration**

From your `values.yaml`:

```yaml
auth:
  basic:
    adminUsername: ehrbase-admin
    adminPassword: ""
    username: ehrbase-user
    password: ""
    existingSecret: ""
    existingSecretAdminUsernameKey: admin-username
    existingSecretAdminPasswordKey: admin-password
    existingSecretUsernameKey: username
    existingSecretPasswordKey: password
```

## 🔧 **How Sealed Secrets Will Replace This**

### 1. **Secret Name Resolution**

**Helper Function:**
```yaml
{{- define "ehrbase.auth.secretName" -}}
{{- default (printf "%s-auth-users" (include "ehrbase.fullname" .)) .Values.auth.basic.existingSecret }}
{{- end }}
```

**What happens when you set `existingSecret: "ehrbase-auth-users"`:**
- The helper function will return `"ehrbase-auth-users"` (your sealed secret name)
- Instead of the default `"<release-name>-auth-users"`

### 2. **Secret Key Mapping**

**Helper Functions:**
```yaml
{{- define "ehrbase.auth.secretAdminUsernameKey" -}}
{{- default "admin-username" .Values.auth.basic.existingSecretAdminUsernameKey }}
{{- end }}

{{- define "ehrbase.auth.secretAdminPasswordKey" -}}
{{- default "admin-password" .Values.auth.basic.existingSecretAdminPasswordKey }}
{{- end }}

{{- define "ehrbase.auth.secretUsernameKey" -}}
{{- default "username" .Values.auth.basic.existingSecretUsernameKey }}
{{- end }}

{{- define "ehrbase.auth.secretPasswordKey" -}}
{{- default "password" .Values.auth.basic.existingSecretPasswordKey }}
{{- end }}
```

**Your sealed secret keys match perfectly:**
- `admin-username` ✅
- `admin-password` ✅  
- `username` ✅
- `password` ✅

## 📋 **Exact Mapping Table**

| Values Config | Helper Function | Sealed Secret Key | Result |
|---------------|-----------------|-------------------|---------|
| `existingSecret: "ehrbase-auth-users"` | `ehrbase.auth.secretName` | N/A | Secret name: `ehrbase-auth-users` |
| `existingSecretAdminUsernameKey: "admin-username"` | `ehrbase.auth.secretAdminUsernameKey` | `admin-username` | ✅ **Perfect Match** |
| `existingSecretAdminPasswordKey: "admin-password"` | `ehrbase.auth.secretAdminPasswordKey` | `admin-password` | ✅ **Perfect Match** |
| `existingSecretUsernameKey: "username"` | `ehrbase.auth.secretUsernameKey` | `username` | ✅ **Perfect Match** |
| `existingSecretPasswordKey: "password"` | `ehrbase.auth.secretPasswordKey` | `password` | ✅ **Perfect Match** |

## 🔄 **Deployment Template Usage**

**In `deployment.yaml`:**
```yaml
env:
  - name: SECURITY_AUTHADMINUSER
    valueFrom:
      secretKeyRef:
        name: {{ include "ehrbase.auth.secretName" . }}           # "ehrbase-auth-users"
        key: {{ include "ehrbase.auth.secretAdminUsernameKey" . }} # "admin-username"
  
  - name: SECURITY_AUTHADMINPASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "ehrbase.auth.secretName" . }}            # "ehrbase-auth-users"
        key: {{ include "ehrbase.auth.secretAdminPasswordKey" . }} # "admin-password"
  
  - name: SECURITY_AUTHUSER
    valueFrom:
      secretKeyRef:
        name: {{ include "ehrbase.auth.secretName" . }}        # "ehrbase-auth-users"
        key: {{ include "ehrbase.auth.secretUsernameKey" . }}  # "username"
  
  - name: SECURITY_AUTHPASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "ehrbase.auth.secretName" . }}         # "ehrbase-auth-users"
        key: {{ include "ehrbase.auth.secretPasswordKey" . }}   # "password"
```

## ✅ **Your Sealed Secret Structure**

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: ehrbase-auth-users  # ✅ Matches existingSecret value
spec:
  encryptedData:
    admin-username: AgBy...  # ✅ Matches existingSecretAdminUsernameKey
    admin-password: AgBy...  # ✅ Matches existingSecretAdminPasswordKey
    username: AgBy...        # ✅ Matches existingSecretUsernameKey
    password: AgBy...        # ✅ Matches existingSecretPasswordKey
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ehrbase
    type: Opaque
```

## 🎯 **Values Configuration for ArgoCD**

**Your `values-argocd-with-secrets.yaml` should be:**
```yaml
# Disable sealed secrets generation in Helm
sealedSecrets:
  enabled: false

# Use existing secrets (created by sealed secrets controller)
auth:
  type: basic
  basic:
    existingSecret: ehrbase-auth-users  # ✅ Points to your sealed secret
    # The key names are already correct by default, so you don't need to specify them:
    # existingSecretAdminUsernameKey: admin-username  # (default)
    # existingSecretAdminPasswordKey: admin-password  # (default)
    # existingSecretUsernameKey: username            # (default)
    # existingSecretPasswordKey: password            # (default)

postgresql:
  enabled: true
  auth:
    existingSecret: ehrbase-postgresql

redis:
  enabled: true
  auth:
    existingSecret: ehrbase-redis
```

## 🔍 **Verification Steps**

### 1. **Check Secret Creation**
```bash
# After ArgoCD applies your sealed secrets
kubectl get secret ehrbase-auth-users -n ehrbase -o yaml
```

**Expected output:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ehrbase-auth-users
  namespace: ehrbase
type: Opaque
data:
  admin-username: ZWhyYmFzZS1hZG1pbg==  # base64 decoded: ehrbase-admin
  admin-password: TXlBZG1pblBhc3N3b3Jk  # base64 decoded: your admin password
  username: ZWhyYmFzZS11c2Vy            # base64 decoded: ehrbase-user
  password: TXlVc2VyUGFzc3dvcmQ=        # base64 decoded: your user password
```

### 2. **Check Deployment Environment Variables**
```bash
kubectl get pod -n ehrbase -o yaml | grep -A 20 env:
```

**Expected output:**
```yaml
env:
- name: SECURITY_AUTHADMINUSER
  valueFrom:
    secretKeyRef:
      name: ehrbase-auth-users
      key: admin-username
- name: SECURITY_AUTHADMINPASSWORD
  valueFrom:
    secretKeyRef:
      name: ehrbase-auth-users
      key: admin-password
- name: SECURITY_AUTHUSER
  valueFrom:
    secretKeyRef:
      name: ehrbase-auth-users
      key: username
- name: SECURITY_AUTHPASSWORD
  valueFrom:
    secretKeyRef:
      name: ehrbase-auth-users
      key: password
```

## ✅ **Conclusion**

**YES, your sealed secrets will correctly replace the values configuration!**

The mapping is **perfect**:
- ✅ Secret names match
- ✅ Secret keys match exactly
- ✅ Helper functions use the correct defaults
- ✅ Deployment template will reference the right secrets
- ✅ Environment variables will be set correctly

Your sealed secrets configuration is **100% compatible** with the existing EHRBase chart structure. 