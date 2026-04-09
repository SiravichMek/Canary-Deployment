#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Kubernetes Canary Deployment Demo Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}docker not found. Please install Docker.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# Check if Istio is installed
echo -e "${YELLOW}Checking Istio installation...${NC}"
if ! kubectl get namespace istio-system &> /dev/null; then
    echo -e "${YELLOW}Istio not found. Installing Istio...${NC}"
    
    # Download Istio
    curl -L https://istio.io/downloadIstio | sh -
    cd istio-*
    export PATH=$PWD/bin:$PATH
    
    # Install Istio
    istioctl install --set profile=demo -y
    
    echo -e "${GREEN}✓ Istio installed${NC}"
else
    echo -e "${GREEN}✓ Istio already installed${NC}"
fi
echo ""

# Create namespace
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl apply -f ../k8s/namespace.yaml
echo -e "${GREEN}✓ Namespace created${NC}"
echo ""

# Build Docker images
echo -e "${YELLOW}Building Docker images...${NC}"
cd ../app

echo "Building v1.0.0..."
docker build -t demo-app:v1.0.0 \
  --build-arg APP_VERSION=v1.0.0 \
  -f Dockerfile .

echo "Building v2.0.0..."
docker build -t demo-app:v2.0.0 \
  --build-arg APP_VERSION=v2.0.0 \
  -f Dockerfile .

echo -e "${GREEN}✓ Docker images built${NC}"
echo ""

# Load images to kind/minikube if needed
if kubectl config current-context | grep -q "kind\|minikube"; then
    echo -e "${YELLOW}Loading images to cluster...${NC}"
    
    if kubectl config current-context | grep -q "kind"; then
        kind load docker-image demo-app:v1.0.0
        kind load docker-image demo-app:v2.0.0
    elif kubectl config current-context | grep -q "minikube"; then
        minikube image load demo-app:v1.0.0
        minikube image load demo-app:v2.0.0
    fi
    
    echo -e "${GREEN}✓ Images loaded to cluster${NC}"
    echo ""
fi

# Apply ConfigMaps
echo -e "${YELLOW}Applying ConfigMaps...${NC}"
kubectl apply -f ../k8s/configmaps/
echo -e "${GREEN}✓ ConfigMaps applied${NC}"
echo ""

# Apply Istio Gateway and DestinationRule
echo -e "${YELLOW}Configuring Istio...${NC}"
kubectl apply -f ../istio/gateway.yaml
kubectl apply -f ../istio/destinationrule.yaml
echo -e "${GREEN}✓ Istio configured${NC}"
echo ""

# Apply monitoring (if Prometheus operator is installed)
echo -e "${YELLOW}Setting up monitoring...${NC}"
if kubectl get crd servicemonitors.monitoring.coreos.com &> /dev/null; then
    kubectl apply -f ../monitoring/prometheus/
    echo -e "${GREEN}✓ Monitoring configured${NC}"
else
    echo -e "${YELLOW}⚠ Prometheus Operator not found. Skipping monitoring setup.${NC}"
    echo -e "${YELLOW}  Install with: helm install prometheus prometheus-community/kube-prometheus-stack${NC}"
fi
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Next steps:"
echo -e "  1. Deploy v1: ${YELLOW}./deploy-v1.sh${NC}"
echo -e "  2. Deploy canary: ${YELLOW}./deploy-canary.sh${NC}"
echo -e "  3. Shift traffic: ${YELLOW}./shift-traffic.sh${NC}"
echo ""

# Made with Bob
