#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deploying Stable Version (v1)${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Deploy v1
echo -e "${YELLOW}Deploying v1 deployment...${NC}"
kubectl apply -f ../k8s/deployments/v1-deployment.yaml
echo -e "${GREEN}✓ v1 deployment created${NC}"
echo ""

# Deploy service
echo -e "${YELLOW}Creating service...${NC}"
kubectl apply -f ../k8s/service.yaml
echo -e "${GREEN}✓ Service created${NC}"
echo ""

# Apply initial VirtualService (100% v1)
echo -e "${YELLOW}Configuring traffic routing (100% v1)...${NC}"
kubectl apply -f ../istio/virtualservice/00-initial.yaml
echo -e "${GREEN}✓ VirtualService configured${NC}"
echo ""

# Wait for deployment to be ready
echo -e "${YELLOW}Waiting for pods to be ready...${NC}"
kubectl wait --for=condition=ready pod \
  -l app=demo-app,version=v1 \
  -n canary-demo \
  --timeout=300s

echo -e "${GREEN}✓ All pods are ready${NC}"
echo ""

# Get Istio ingress gateway URL
echo -e "${YELLOW}Getting application URL...${NC}"
INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')

if [ -z "$INGRESS_HOST" ]; then
    INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
fi

if [ -z "$INGRESS_HOST" ]; then
    echo -e "${YELLOW}⚠ LoadBalancer not available. Using NodePort...${NC}"
    INGRESS_HOST=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
fi

export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Application URL: ${YELLOW}http://${GATEWAY_URL}${NC}"
echo -e "API Version: ${YELLOW}http://${GATEWAY_URL}/api/version${NC}"
echo -e "Health Check: ${YELLOW}http://${GATEWAY_URL}/health${NC}"
echo ""
echo -e "View pods:"
echo -e "  ${YELLOW}kubectl get pods -n canary-demo${NC}"
echo ""
echo -e "View logs:"
echo -e "  ${YELLOW}kubectl logs -f -l app=demo-app,version=v1 -n canary-demo${NC}"
echo ""
echo -e "Next step: Deploy canary version"
echo -e "  ${YELLOW}./deploy-canary.sh${NC}"
echo ""

# Made with Bob
