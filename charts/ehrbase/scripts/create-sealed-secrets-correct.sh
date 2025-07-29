#!/bin/bash

# EHRBase Sealed Secrets Generator (Corrected)
# This script creates properly encrypted SealedSecret files with correct base64 encoding

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}EHRBase Sealed Secrets Generator (Corrected)${NC}"
echo "=================================================="

# Check if kubeseal is installed
if ! command -v kubeseal &> /dev/null; then
    echo -e "${RED}Error: kubeseal is not installed${NC}"
    echo "Please install kubeseal: https://github.com/bitnami-labs/sealed-secrets#installation"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

# Function to encode string to base64
base64_encode() {
    echo -n "$1" | base64
}

# Function to generate sealed secret with proper base64 encoding
generate_sealed_secret() {
    local secret_name=$1
    local namespace=$2
    local scope=$3
    local output_file=$4
    shift 4
    local secret_data=("$@")
    
    echo -e "${YELLOW}Generating sealed secret for: ${secret_name}${NC}"
    
    # Create temporary secret file with base64-encoded data
    cat > /tmp/temp-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${secret_name}
  namespace: ${namespace}
type: Opaque
data:
EOF
    
    # Add secret data with base64 encoding
    for data in "${secret_data[@]}"; do
        echo "  ${data}" >> /tmp/temp-secret.yaml
    done
    
    echo -e "${BLUE}Created temporary secret with base64-encoded data:${NC}"
    cat /tmp/temp-secret.yaml
    
    # Generate sealed secret
    if [ "$scope" = "cluster-wide" ]; then
        kubeseal --format=yaml --scope=cluster-wide < /tmp/temp-secret.yaml > "$output_file"
    else
        kubeseal --format=yaml --scope=namespace-wide < /tmp/temp-secret.yaml > "$output_file"
    fi
    
    echo -e "${GREEN}✓ Created: ${output_file}${NC}"
    echo ""
}

# Main script
echo "This script creates properly encrypted SealedSecret files for EHRBase."
echo -e "${YELLOW}IMPORTANT: Values will be base64-encoded before encryption!${NC}"
echo ""

# Get namespace
read -p "Enter the namespace for EHRBase: " namespace
namespace=${namespace:-ehrbase}

# Get scope
echo "Select the scope for sealed secrets:"
echo "1) namespace-wide (recommended)"
echo "2) cluster-wide"
read -p "Enter your choice (1 or 2): " scope_choice

case $scope_choice in
    1)
        scope="namespace-wide"
        ;;
    2)
        scope="cluster-wide"
        ;;
    *)
        echo -e "${RED}Invalid choice. Using namespace-wide.${NC}"
        scope="namespace-wide"
        ;;
esac

# Get passwords
echo ""
echo -e "${BLUE}Enter the passwords for EHRBase:${NC}"
read -s -p "Admin password: " admin_password
echo ""
read -s -p "User password: " user_password
echo ""
read -s -p "PostgreSQL admin password: " postgres_admin_password
echo ""
read -s -p "PostgreSQL user password: " postgres_user_password
echo ""
read -s -p "Redis password: " redis_password
echo ""

# Create output directory
output_dir="sealed-secrets"
mkdir -p "$output_dir"

echo ""
echo -e "${GREEN}Generating sealed secrets for namespace: ${namespace} with scope: ${scope}${NC}"
echo ""

# Generate auth sealed secret with base64 encoding
echo -e "${BLUE}Creating auth users secret with base64 encoding...${NC}"
generate_sealed_secret \
    "ehrbase-auth-users" \
    "$namespace" \
    "$scope" \
    "$output_dir/auth-users-sealed-secret.yaml" \
    "admin-username: $(base64_encode "ehrbase-admin")" \
    "admin-password: $(base64_encode "$admin_password")" \
    "username: $(base64_encode "ehrbase-user")" \
    "password: $(base64_encode "$user_password")"

# Generate PostgreSQL sealed secret with base64 encoding
echo -e "${BLUE}Creating PostgreSQL secret with base64 encoding...${NC}"
generate_sealed_secret \
    "ehrbase-postgresql" \
    "$namespace" \
    "$scope" \
    "$output_dir/postgresql-sealed-secret.yaml" \
    "postgres-password: $(base64_encode "$postgres_admin_password")" \
    "password: $(base64_encode "$postgres_user_password")"

# Generate Redis sealed secret with base64 encoding
echo -e "${BLUE}Creating Redis secret with base64 encoding...${NC}"
generate_sealed_secret \
    "ehrbase-redis" \
    "$namespace" \
    "$scope" \
    "$output_dir/redis-sealed-secret.yaml" \
    "redis-password: $(base64_encode "$redis_password")"

# Clean up
rm -f /tmp/temp-secret.yaml

echo -e "${GREEN}✓ All sealed secrets generated successfully!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Review the generated files in the '$output_dir' directory"
echo "2. Commit these files to your Git repository"
echo "3. Update your values.yaml to use existing secrets:"
echo ""
echo "   sealedSecrets:"
echo "     enabled: false  # Disable auto-generation"
echo ""
echo "   auth:"
echo "     type: basic"
echo "     basic:"
echo "       existingSecret: ehrbase-auth-users"
echo ""
echo "   postgresql:"
echo "     auth:"
echo "       existingSecret: ehrbase-postgresql"
echo ""
echo "   redis:"
echo "     auth:"
echo "       existingSecret: ehrbase-redis"
echo ""
echo -e "${YELLOW}Note: The generated files are encrypted and safe to commit to Git!${NC}"
echo ""
echo -e "${BLUE}Verification:${NC}"
echo "You can verify the base64 encoding was correct by checking the temporary secret:"
echo "The values should be base64-encoded before encryption." 