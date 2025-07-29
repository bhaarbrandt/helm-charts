# Correct Sealed Secret Creation Process

This example shows the **correct** way to create sealed secrets with proper base64 encoding.

## ❌ **What You Did (Incorrect)**

You created a secret like this:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ehrbase-users
type: Opaque
data:
  admin-username: <base64-encoded-admin-username>  # ❌ Placeholder, not actual base64
  admin-password: <base64-encoded-admin-password>  # ❌ Placeholder, not actual base64
  username: <base64-encoded-username>              # ❌ Placeholder, not actual base64
  password: <base64-encoded-password>              # ❌ Placeholder, not actual base64
```

## ✅ **Correct Process**

### Step 1: Create Temporary Secret with Actual Base64 Values

```bash
# Create a temporary secret file with REAL base64-encoded values
cat <<EOF > /tmp/auth-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ehrbase-auth-users
  namespace: ehrbase
type: Opaque
data:
  admin-username: ZWhyYmFzZS1hZG1pbg==
  admin-password: TXlBZG1pblBhc3N3b3JkMTIzIQ==
  username: ZWhyYmFzZS11c2Vy
  password: TXlVc2VyUGFzc3dvcmQxMjMh
EOF
```

**How to get the base64 values:**
```bash
# Encode your actual values
echo -n "ehrbase-admin" | base64
# Output: ZWhyYmFzZS1hZG1pbg==

echo -n "MyAdminPassword123!" | base64
# Output: TXlBZG1pblBhc3N3b3JkMTIzIQ==

echo -n "ehrbase-user" | base64
# Output: ZWhyYmFzZS11c2Vy

echo -n "MyUserPassword123!" | base64
# Output: TXlVc2VyUGFzc3dvcmQxMjMh
```

### Step 2: Generate Sealed Secret

```bash
# Use kubeseal to encrypt the base64-encoded secret
kubeseal --format=yaml < /tmp/auth-secret.yaml > sealed-auth-secret.yaml
```

### Step 3: Result - Properly Encrypted Sealed Secret

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: ehrbase-auth-users
  namespace: ehrbase
spec:
  encryptedData:
    admin-username: AgBy...  # Actually encrypted base64 value
    admin-password: AgBy...  # Actually encrypted base64 value
    username: AgBy...        # Actually encrypted base64 value
    password: AgBy...        # Actually encrypted base64 value
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ehrbase
    type: Opaque
```

## 🔧 **Complete Example with Real Values**

### 1. Create Temporary Secret
```bash
# Create temporary secret with real base64 values
cat <<EOF > /tmp/auth-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ehrbase-auth-users
  namespace: ehrbase
type: Opaque
data:
  admin-username: ZWhyYmFzZS1hZG1pbg==
  admin-password: TXlBZG1pblBhc3N3b3JkMTIzIQ==
  username: ZWhyYmFzZS11c2Vy
  password: TXlVc2VyUGFzc3dvcmQxMjMh
EOF
```

### 2. Create PostgreSQL Secret
```bash
cat <<EOF > /tmp/postgresql-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ehrbase-postgresql
  namespace: ehrbase
type: Opaque
data:
  postgres-password: TXlQb3N0Z3JlUGFzc3dvcmQxMjMh
  password: TXlQb3N0Z3JlUGFzc3dvcmQxMjMh
EOF
```

### 3. Create Redis Secret
```bash
cat <<EOF > /tmp/redis-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ehrbase-redis
  namespace: ehrbase
type: Opaque
data:
  redis-password: TXlSZWRpc1Bhc3N3b3JkMTIzIQ==
EOF
```

### 4. Generate Sealed Secrets
```bash
# Generate sealed secrets
kubeseal --format=yaml < /tmp/auth-secret.yaml > sealed-auth-secret.yaml
kubeseal --format=yaml < /tmp/postgresql-secret.yaml > sealed-postgresql-secret.yaml
kubeseal --format=yaml < /tmp/redis-secret.yaml > sealed-redis-secret.yaml

# Clean up temporary files
rm /tmp/auth-secret.yaml /tmp/postgresql-secret.yaml /tmp/redis-secret.yaml
```

## 🔍 **Verification**

### Check Base64 Encoding
```bash
# Verify base64 encoding
echo "ZWhyYmFzZS1hZG1pbg==" | base64 -d
# Should output: ehrbase-admin

echo "TXlBZG1pblBhc3N3b3JkMTIzIQ==" | base64 -d
# Should output: MyAdminPassword123!
```

### Check Sealed Secret Format
```bash
# Verify it's a proper SealedSecret
grep -q "apiVersion: bitnami.com/v1alpha1" sealed-auth-secret.yaml && \
grep -q "kind: SealedSecret" sealed-auth-secret.yaml && \
grep -q "encryptedData:" sealed-auth-secret.yaml && \
echo "✅ Valid SealedSecret format"
```

## 🎯 **Key Points**

1. **Base64 encoding is required** - Kubernetes secrets store data as base64
2. **Use actual base64 values** - Not placeholders like `<base64-encoded-admin-username>`
3. **kubeseal encrypts the base64** - The encrypted data contains the base64-encoded values
4. **Controller decrypts to base64** - The final Kubernetes secret will have base64 data
5. **Application decodes base64** - EHRBase will decode the base64 values automatically

## 🚀 **Quick Fix**

If you already have sealed secrets without proper base64 encoding:

1. **Delete the existing sealed secrets**
2. **Use the corrected script**: `./scripts/create-sealed-secrets-correct.sh`
3. **Or manually create them** using the process above
4. **Apply the new sealed secrets** to your cluster

The corrected sealed secrets will work perfectly with EHRBase! 