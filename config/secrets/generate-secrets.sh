#!/bin/bash

# MTV Secret Generation Script
# This script generates Kubernetes secrets for MTV migration

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== MTV Secret Generation Script ===${NC}"
echo ""

# Function to prompt for input
prompt_input() {
    local prompt="$1"
    local var_name="$2"
    local is_secret="$3"
    
    if [ "$is_secret" = "true" ]; then
        read -s -p "$prompt: " input
        echo ""
    else
        read -p "$prompt: " input
    fi
    
    if [ -z "$input" ]; then
        echo -e "${RED}Error: Input cannot be empty${NC}"
        exit 1
    fi
    
    eval "$var_name='$input'"
}

# Generate vCenter credentials
generate_vcenter_secrets() {
    echo -e "${YELLOW}Generating vCenter Credentials Secret${NC}"
    
    prompt_input "vCenter Host" VCHOST false
    prompt_input "vCenter Username" VCUSER false
    prompt_input "vCenter Password" VCPASS true
    prompt_input "Datacenter Name" VCDATACENTER false
    prompt_input "vCenter Port (default: 443)" VCPORT false
    
    # Create secret
    oc create secret generic vcenter-credentials \
        --from-literal=username="$VCUSER" \
        --from-literal=password="$VCPASS" \
        --from-literal=vcenter_host="$VCHOST" \
        --from-literal=vcenter_port="${VCPORT:-443}" \
        --from-literal=insecure_skip_verify="true" \
        --from-literal=datacenter="$VCDATACENTER" \
        -n openshift-mtv
    
    echo -e "${GREEN}vCenter credentials secret created successfully${NC}"
    echo ""
}

# Generate OpenShift credentials
generate_openshift_secrets() {
    echo -e "${YELLOW}Generating OpenShift Credentials Secret${NC}"
    
    prompt_input "OpenShift API URL" OC_API false
    prompt_input "OpenShift Username" OC_USER false
    prompt_input "OpenShift Password" OC_PASS true
    prompt_input "Cluster Name" CLUSTER_NAME false
    
    # Create secret
    oc create secret generic openshift-credentials \
        --from-literal=api_url="$OC_API" \
        --from-literal=username="$OC_USER" \
        --from-literal=password="$OC_PASS" \
        --from-literal=cluster_name="$CLUSTER_NAME" \
        -n openshift-mtv
    
    echo -e "${GREEN}OpenShift credentials secret created successfully${NC}"
    echo ""
}

# Generate database credentials
generate_database_secrets() {
    echo -e "${YELLOW}Generating Database Credentials Secret${NC}"
    
    prompt_input "Database Type (mysql/postgresql/sqlserver/oracle)" DB_TYPE false
    prompt_input "Database Host" DB_HOST false
    prompt_input "Database Port" DB_PORT false
    prompt_input "Database Username" DB_USER false
    prompt_input "Database Password" DB_PASS true
    prompt_input "Database Name" DB_NAME false
    
    # Create secret
    oc create secret generic "${DB_TYPE}-credentials" \
        --from-literal=username="$DB_USER" \
        --from-literal=password="$DB_PASS" \
        --from-literal=database="$DB_NAME" \
        --from-literal=host="$DB_HOST" \
        --from-literal=port="$DB_PORT" \
        -n production
    
    echo -e "${GREEN}Database credentials secret created successfully${NC}"
    echo ""
}

# Generate application credentials
generate_app_secrets() {
    echo -e "${YELLOW}Generating Application Credentials Secret${NC}"
    
    prompt_input "Application API Key" APP_API_KEY true
    prompt_input "Application Secret" APP_SECRET true
    prompt_input "Encryption Key" ENCRYPTION_KEY true
    prompt_input "JWT Secret" JWT_SECRET true
    
    # Create secret
    oc create secret generic app-config \
        --from-literal=app_api_key="$APP_API_KEY" \
        --from-literal=app_secret="$APP_SECRET" \
        --from-literal=encryption_key="$ENCRYPTION_KEY" \
        --from-literal=jwt_secret="$JWT_SECRET" \
        -n production
    
    echo -e "${GREEN}Application credentials secret created successfully${NC}"
    echo ""
}

# Main menu
echo "Select secret type to generate:"
echo "1) vCenter Credentials"
echo "2) OpenShift Credentials"
echo "3) Database Credentials"
echo "4) Application Credentials"
echo "5) All Secrets"
echo "6) Exit"
read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        generate_vcenter_secrets
        ;;
    2)
        generate_openshift_secrets
        ;;
    3)
        generate_database_secrets
        ;;
    4)
        generate_app_secrets
        ;;
    5)
        generate_vcenter_secrets
        generate_openshift_secrets
        generate_database_secrets
        generate_app_secrets
        ;;
    6)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}=== Secret Generation Complete ===${NC}"
echo ""
echo "Verify created secrets:"
echo "oc get secrets -n openshift-mtv"
echo "oc get secrets -n production"