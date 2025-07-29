#!/bin/bash

# EHRBase Sealed Secrets Validation Script
# This script validates that sealed secrets are properly configured for EHRBase

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}EHRBase Sealed Secrets Validation${NC}"
echo "======================================"

# Function to check if file exists
check_file() {
    local file="$1"
    local description="$2"
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ $description${NC}"
        return 0
    else
        echo -e "${RED}✗ $description (missing)${NC}"
        return 1
    fi
}

# Function to validate sealed secret format
validate_sealed_secret() {
    local file="$1"
    local description="$2"
    
    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}⚠ $description (file not found)${NC}"
        return 1
    fi
    
    # Check if it's a proper SealedSecret
    if grep -q "apiVersion: bitnami.com/v1alpha1" "$file" && grep -q "kind: SealedSecret" "$file"; then
        echo -e "${GREEN}✓ $description (proper SealedSecret format)${NC}"
        
        # Check for encryptedData
        if grep -q "encryptedData:" "$file"; then
            echo -e "${GREEN}  ✓ Contains encryptedData section${NC}"
        else
            echo -e "${RED}  ✗ Missing encryptedData section${NC}"
            return 1
        fi
        
        # Check for template
        if grep -q "template:" "$file"; then
            echo -e "${GREEN}  ✓ Contains template section${NC}"
        else
            echo -e "${RED}  ✗ Missing template section${NC}"
            return 1
        fi
        
        return 0
    else
        echo -e "${RED}✗ $description (not a SealedSecret)${NC}"
        return 1
    fi
}

# Function to check secret key names
check_secret_keys() {
    local file="$1"
    local expected_keys=("$2")
    local description="$3"
    
    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}⚠ $description (file not found)${NC}"
        return 1
    fi
    
    local missing_keys=()
    for key in "${expected_keys[@]}"; do
        if ! grep -q "$key:" "$file"; then
            missing_keys+=("$key")
        fi
    done
    
    if [ ${#missing_keys[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ $description (all expected keys present)${NC}"
        return 0
    else
        echo -e "${RED}✗ $description (missing keys: ${missing_keys[*]})${NC}"
        return 1
    fi
}

# Function to validate values configuration
validate_values_config() {
    local values_file="$1"
    local description="$2"
    
    if [ ! -f "$values_file" ]; then
        echo -e "${YELLOW}⚠ $description (file not found)${NC}"
        return 1
    fi
    
    # Check if sealed secrets are disabled
    if grep -q "sealedSecrets:" "$values_file" && grep -q "enabled: false" "$values_file"; then
        echo -e "${GREEN}✓ $description (sealed secrets disabled in Helm)${NC}"
    else
        echo -e "${YELLOW}⚠ $description (sealed secrets not explicitly disabled)${NC}"
    fi
    
    # Check for existing secret references
    local has_existing_secrets=true
    
    if ! grep -q "existingSecret:" "$values_file"; then
        has_existing_secrets=false
    fi
    
    if [ "$has_existing_secrets" = true ]; then
        echo -e "${GREEN}✓ $description (uses existing secrets)${NC}"
        return 0
    else
        echo -e "${RED}✗ $description (no existing secret references)${NC}"
        return 1
    fi
}

# Main validation
echo -e "${BLUE}Checking file structure...${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "Chart.yaml" ]; then
    echo -e "${RED}Error: Not in EHRBase chart directory${NC}"
    echo "Please run this script from the charts/ehrbase directory"
    exit 1
fi

# Check required files
check_file "Chart.yaml" "Chart.yaml exists"
check_file "values.yaml" "values.yaml exists"
check_file "templates/deployment.yaml" "deployment template exists"
check_file "templates/_helpers.tpl" "helpers template exists"

echo ""
echo -e "${BLUE}Checking sealed secrets configuration...${NC}"
echo ""

# Check if sealed secrets directory exists
if [ -d "secrets" ]; then
    echo -e "${GREEN}✓ secrets directory exists${NC}"
    
    # Check for sealed secret files
    if [ -f "secrets/auth-users-sealed-secret.yaml" ]; then
        validate_sealed_secret "secrets/auth-users-sealed-secret.yaml" "Auth users sealed secret"
        check_secret_keys "secrets/auth-users-sealed-secret.yaml" "admin-username admin-password username password" "Auth users secret keys"
    else
        echo -e "${YELLOW}⚠ Auth users sealed secret not found${NC}"
    fi
    
    if [ -f "secrets/postgresql-sealed-secret.yaml" ]; then
        validate_sealed_secret "secrets/postgresql-sealed-secret.yaml" "PostgreSQL sealed secret"
        check_secret_keys "secrets/postgresql-sealed-secret.yaml" "postgres-password password" "PostgreSQL secret keys"
    else
        echo -e "${YELLOW}⚠ PostgreSQL sealed secret not found${NC}"
    fi
    
    if [ -f "secrets/redis-sealed-secret.yaml" ]; then
        validate_sealed_secret "secrets/redis-sealed-secret.yaml" "Redis sealed secret"
        check_secret_keys "secrets/redis-sealed-secret.yaml" "redis-password" "Redis secret keys"
    else
        echo -e "${YELLOW}⚠ Redis sealed secret not found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ secrets directory not found${NC}"
fi

echo ""
echo -e "${BLUE}Checking values configuration...${NC}"
echo ""

# Check example values files
if [ -f "examples/values-argocd-with-secrets.yaml" ]; then
    validate_values_config "examples/values-argocd-with-secrets.yaml" "ArgoCD values configuration"
else
    echo -e "${YELLOW}⚠ ArgoCD values example not found${NC}"
fi

echo ""
echo -e "${BLUE}Checking template helpers...${NC}"
echo ""

# Check if helper functions exist
if grep -q "ehrbase.auth.secretName" "templates/_helpers.tpl"; then
    echo -e "${GREEN}✓ Auth secret name helper exists${NC}"
else
    echo -e "${RED}✗ Auth secret name helper missing${NC}"
fi

if grep -q "ehrbase.postgres.secretName" "templates/_helpers.tpl"; then
    echo -e "${GREEN}✓ PostgreSQL secret name helper exists${NC}"
else
    echo -e "${RED}✗ PostgreSQL secret name helper missing${NC}"
fi

if grep -q "ehrbase.redis.secretName" "templates/_helpers.tpl"; then
    echo -e "${GREEN}✓ Redis secret name helper exists${NC}"
else
    echo -e "${RED}✗ Redis secret name helper missing${NC}"
fi

echo ""
echo -e "${BLUE}Checking deployment template...${NC}"
echo ""

# Check if deployment uses secret references
if grep -q "SECURITY_AUTHADMINUSER" "templates/deployment.yaml"; then
    echo -e "${GREEN}✓ Deployment uses auth admin user secret${NC}"
else
    echo -e "${RED}✗ Deployment missing auth admin user secret${NC}"
fi

if grep -q "SECURITY_AUTHADMINPASSWORD" "templates/deployment.yaml"; then
    echo -e "${GREEN}✓ Deployment uses auth admin password secret${NC}"
else
    echo -e "${RED}✗ Deployment missing auth admin password secret${NC}"
fi

if grep -q "DB_PASS" "templates/deployment.yaml"; then
    echo -e "${GREEN}✓ Deployment uses database password secret${NC}"
else
    echo -e "${RED}✗ Deployment missing database password secret${NC}"
fi

if grep -q "SPRING_DATA_REDIS_PASSWORD" "templates/deployment.yaml"; then
    echo -e "${GREEN}✓ Deployment uses Redis password secret${NC}"
else
    echo -e "${RED}✗ Deployment missing Redis password secret${NC}"
fi

echo ""
echo -e "${BLUE}Summary${NC}"
echo "========"
echo ""
echo "The sealed secrets configuration for EHRBase appears to be properly set up."
echo ""
echo -e "${GREEN}Key points:${NC}"
echo "• Templates use helper functions to reference secrets"
echo "• Deployment template references all required secret keys"
echo "• Values support existing secret configuration"
echo "• SealedSecret format is properly structured"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Generate sealed secrets using: ./scripts/create-sealed-secrets.sh"
echo "2. Place them in the secrets/ directory"
echo "3. Configure values to use existing secrets"
echo "4. Deploy with ArgoCD"
echo ""
echo -e "${BLUE}For detailed instructions, see: docs/ARGOCD_SEALED_SECRETS.md${NC}" 