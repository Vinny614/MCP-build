#!/bin/bash

# Cleanup script - destroys all Azure resources created by Terraform

set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo ""
print_warning "==================================================================="
print_warning "                    RESOURCE CLEANUP                              "
print_warning "==================================================================="
echo ""
print_warning "This script will DESTROY all Azure resources created by Terraform."
print_warning "This action is IRREVERSIBLE!"
echo ""

# Check if terraform directory exists
if [ ! -d "infrastructure/terraform" ]; then
    print_error "Terraform directory not found. Are you in the project root?"
    exit 1
fi

# Show what will be destroyed
echo "Resources that will be destroyed:"
cd infrastructure/terraform
terraform show -no-color | head -n 50
echo "..."
echo ""

# Confirmation prompt
read -p "Are you sure you want to destroy all resources? (type 'yes' to confirm): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Final confirmation
echo ""
print_warning "FINAL WARNING: This will delete all resources!"
read -p "Type 'destroy' to proceed: " FINAL_CONFIRM

if [ "$FINAL_CONFIRM" != "destroy" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Destroy resources
echo ""
echo "Destroying resources..."
terraform destroy -auto-approve

cd ../..

# Clean up local files
if [ -f deployment-outputs.json ]; then
    rm deployment-outputs.json
    echo "Removed deployment-outputs.json"
fi

if [ -f src/deploy.zip ]; then
    rm src/deploy.zip
    echo "Removed src/deploy.zip"
fi

echo ""
echo "Cleanup completed successfully!"
echo "All Azure resources have been destroyed."
