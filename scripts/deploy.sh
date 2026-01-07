#!/bin/bash

# Deployment script for MCP Server on Azure
# This script automates the deployment process

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if logged in to Azure
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    print_info "All prerequisites met!"
}

# Deploy infrastructure
deploy_infrastructure() {
    print_info "Deploying infrastructure with Terraform..."
    
    cd infrastructure/terraform
    
    # Initialize Terraform
    print_info "Initializing Terraform..."
    terraform init
    
    # Validate configuration
    print_info "Validating Terraform configuration..."
    terraform validate
    
    # Plan deployment
    print_info "Planning deployment..."
    terraform plan -out=tfplan
    
    # Apply deployment
    print_info "Applying Terraform configuration..."
    terraform apply tfplan
    
    # Save outputs
    print_info "Saving outputs..."
    terraform output -json > ../../deployment-outputs.json
    
    cd ../..
    
    print_info "Infrastructure deployment completed!"
}

# Build application package
build_app() {
    print_info "Building application package..."
    
    cd src
    
    # Clean previous builds
    rm -f deploy.zip
    
    # Create deployment package
    print_info "Creating deployment package..."
    zip -r deploy.zip . \
        -x "*.pyc" \
        -x "__pycache__/*" \
        -x "*.git*" \
        -x "venv/*" \
        -x ".venv/*"
    
    cd ..
    
    print_info "Application package created: src/deploy.zip"
}

# Deploy application
deploy_app() {
    print_info "Deploying application to Azure Web App..."
    
    # Get deployment info from Terraform outputs
    if [ ! -f deployment-outputs.json ]; then
        print_error "deployment-outputs.json not found. Please run infrastructure deployment first."
        exit 1
    fi
    
    RESOURCE_GROUP=$(jq -r '.resource_group_name.value' deployment-outputs.json)
    WEB_APP_NAME=$(jq -r '.web_app_name.value' deployment-outputs.json)
    
    print_info "Resource Group: $RESOURCE_GROUP"
    print_info "Web App: $WEB_APP_NAME"
    
    # Deploy the package
    print_info "Uploading application package..."
    az webapp deployment source config-zip \
        --resource-group "$RESOURCE_GROUP" \
        --name "$WEB_APP_NAME" \
        --src src/deploy.zip
    
    # Configure startup command
    print_info "Configuring startup command..."
    az webapp config set \
        --resource-group "$RESOURCE_GROUP" \
        --name "$WEB_APP_NAME" \
        --startup-file "gunicorn --bind=0.0.0.0:8000 --timeout 600 app:flask_app"
    
    # Restart the app
    print_info "Restarting web app..."
    az webapp restart \
        --resource-group "$RESOURCE_GROUP" \
        --name "$WEB_APP_NAME"
    
    print_info "Application deployment completed!"
}

# Test deployment
test_deployment() {
    print_info "Testing deployment..."
    
    if [ ! -f deployment-outputs.json ]; then
        print_error "deployment-outputs.json not found."
        exit 1
    fi
    
    WEB_APP_URL=$(jq -r '.web_app_url.value' deployment-outputs.json)
    APIM_URL=$(jq -r '.apim_gateway_url.value' deployment-outputs.json)
    
    # Test Web App health endpoint
    print_info "Testing Web App health endpoint..."
    if curl -f -s "$WEB_APP_URL/health" > /dev/null; then
        print_info "✓ Web App is healthy"
    else
        print_warning "✗ Web App health check failed"
    fi
    
    # Test APIM (requires subscription key)
    print_info "APIM Gateway URL: $APIM_URL"
    print_warning "To test APIM, you need to get a subscription key:"
    echo "  az apim subscription list --resource-group \$(jq -r '.resource_group_name.value' deployment-outputs.json) --service-name \$(echo $APIM_URL | cut -d'/' -f3 | cut -d'.' -f1)"
    
    print_info "Testing completed!"
}

# Print deployment information
print_deployment_info() {
    print_info "==================================================================="
    print_info "                    DEPLOYMENT COMPLETED                           "
    print_info "==================================================================="
    
    if [ -f deployment-outputs.json ]; then
        echo ""
        print_info "Web App URL: $(jq -r '.web_app_url.value' deployment-outputs.json)"
        print_info "APIM Gateway URL: $(jq -r '.apim_gateway_url.value' deployment-outputs.json)"
        print_info "APIM Developer Portal: $(jq -r '.apim_developer_portal_url.value' deployment-outputs.json)"
        echo ""
        print_info "Next steps:"
        echo "  1. Get APIM subscription key"
        echo "  2. Test the API endpoints"
        echo "  3. Configure custom domain (optional)"
        echo "  4. Set up monitoring alerts"
        echo ""
    fi
    
    print_info "==================================================================="
}

# Main deployment flow
main() {
    print_info "Starting MCP Server deployment to Azure..."
    echo ""
    
    # Parse command line arguments
    SKIP_INFRA=false
    SKIP_APP=false
    SKIP_TEST=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-infra)
                SKIP_INFRA=true
                shift
                ;;
            --skip-app)
                SKIP_APP=true
                shift
                ;;
            --skip-test)
                SKIP_TEST=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --skip-infra    Skip infrastructure deployment"
                echo "  --skip-app      Skip application deployment"
                echo "  --skip-test     Skip deployment testing"
                echo "  --help          Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Run deployment steps
    check_prerequisites
    
    if [ "$SKIP_INFRA" = false ]; then
        deploy_infrastructure
    else
        print_warning "Skipping infrastructure deployment"
    fi
    
    if [ "$SKIP_APP" = false ]; then
        build_app
        deploy_app
    else
        print_warning "Skipping application deployment"
    fi
    
    if [ "$SKIP_TEST" = false ]; then
        test_deployment
    else
        print_warning "Skipping deployment testing"
    fi
    
    print_deployment_info
    
    print_info "Deployment completed successfully!"
}

# Run main function
main "$@"
