# ArgoCD + Sealed Secrets Workflow

This guide explains how ArgoCD and sealed secrets work together for secure GitOps deployments.

## Overview

**Yes, ArgoCD should pick up and apply sealed secrets!** Here's how the complete workflow works:

## Architecture

```
Git Repository
├── charts/ehrbase/                    # Helm chart
├── apps/ehrbase/
│   ├── Application.yaml              # ArgoCD application
│   ├── values.yaml                   # Helm values
│   └── sealed-secrets/               # Encrypted secrets
│       ├── auth-users-sealed-secret.yaml
│       ├── postgresql-sealed-secret.yaml
│       └── redis-sealed-secret.yaml
└── (other apps...)
```

## Workflow Steps

### 1. Generate Sealed Secrets Locally
```bash
# Create encrypted secrets using kubeseal
./scripts/create-sealed-secrets.sh

# This creates files like:
# sealed-secrets/auth-users-sealed-secret.yaml (ENCRYPTED)
# sealed-secrets/postgresql-sealed-secret.yaml (ENCRYPTED)
# sealed-secrets/redis-sealed-secret.yaml (ENCRYPTED)
```

### 2. Commit to Git Repository
```bash
# Move sealed secrets to your GitOps repo
mv sealed-secrets/* apps/ehrbase/sealed-secrets/

# Commit the encrypted files
git add apps/ehrbase/sealed-secrets/
git commit -m "Add sealed secrets for EHRBase"
git push
```

### 3. ArgoCD Detects Changes
- ArgoCD monitors your Git repository
- Detects new SealedSecret resources
- Applies them to your cluster automatically

### 4. Sealed Secrets Controller Decrypts
- Controller sees the SealedSecret resources
- Decrypts them using cluster's private key
- Creates actual Kubernetes Secret resources

### 5. Application Uses Secrets
- EHRBase deployment references the secrets
- Secrets are mounted as environment variables
- Application starts with proper credentials

## Repository Structure

```
your-gitops-repo/
├── apps/
│   └── ehrbase/
│       ├── Application.yaml                    # ArgoCD application
│       ├── values-argocd-with-secrets.yaml    # Helm values (uses existing secrets)
│       └── sealed-secrets/                    # Encrypted secrets (committed to Git)
│           ├── auth-users-sealed-secret.yaml
│           ├── postgresql-sealed-secret.yaml
│           └── redis-sealed-secret.yaml
└── charts/
    └── ehrbase/                               # Your helm chart
```

## ArgoCD Application Configuration

```yaml
# apps/ehrbase/Application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ehrbase
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-gitops-repo.git
    targetRevision: HEAD
    path: charts/ehrbase
    helm:
      valueFiles:
        - ../../apps/ehrbase/values-argocd-with-secrets.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: ehrbase
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Helm Values (Using Existing Secrets)

```yaml
# apps/ehrbase/values-argocd-with-secrets.yaml
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

## What ArgoCD Applies

When ArgoCD syncs, it applies these resources in order:

1. **SealedSecret resources** (from `sealed-secrets/` directory)
2. **Helm chart resources** (deployments, services, etc.)
3. **Kubernetes Secret resources** (created by controller)

## Verification

### Check ArgoCD Status
```bash
# Check application status
argocd app get ehrbase

# Check sync status
argocd app sync ehrbase

# View application logs
argocd app logs ehrbase
```

### Check Sealed Secrets
```bash
# Check if sealed secrets were applied
kubectl get sealedsecrets -n ehrbase

# Check if secrets were created
kubectl get secrets -n ehrbase

# Check sealed secret status
kubectl describe sealedsecret ehrbase-auth-users -n ehrbase
```

### Check Application
```bash
# Check if application is using secrets
kubectl describe deployment ehrbase -n ehrbase

# Check environment variables
kubectl get pods -n ehrbase -o yaml | grep -A 10 env:
```

## Troubleshooting

### Sealed Secrets Not Applied
```bash
# Check if ArgoCD can access the files
argocd app get ehrbase --hard-refresh

# Check sealed secrets controller
kubectl logs -n kube-system deployment/sealed-secrets-controller
```

### Secrets Not Created
```bash
# Check sealed secret status
kubectl describe sealedsecret ehrbase-auth-users -n ehrbase

# Check controller logs
kubectl logs -n kube-system deployment/sealed-secrets-controller
```

### Application Can't Find Secrets
```bash
# Verify secret names match
kubectl get secrets -n ehrbase
kubectl describe deployment ehrbase -n ehrbase
```

## Security Benefits

✅ **Encrypted in Git** - SealedSecret files are encrypted
✅ **Automatic application** - ArgoCD applies everything
✅ **Automatic decryption** - Controller handles decryption
✅ **No plaintext passwords** in Git repository
✅ **Audit trail** - All changes tracked in Git
✅ **Rollback capability** - Easy to revert changes

## Best Practices

1. **Generate sealed secrets locally** - Use `kubeseal` CLI
2. **Commit encrypted files** - Only sealed secrets go in Git
3. **Use existing secrets** - Configure Helm to use decrypted secrets
4. **Monitor sync status** - Check ArgoCD application status
5. **Verify decryption** - Ensure secrets are created properly
6. **Test rollbacks** - Verify you can revert changes

## Summary

**Yes, ArgoCD should and will pick up sealed secrets!** The workflow is:

1. Generate encrypted secrets locally
2. Commit them to Git
3. ArgoCD applies them automatically
4. Controller decrypts them
5. Application uses the decrypted secrets

This provides a secure, automated GitOps workflow where sensitive data is encrypted in Git but automatically available to your applications in the cluster. 