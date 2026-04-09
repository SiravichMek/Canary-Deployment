#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deploying Canary Version (v2)${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Deploy v2
echo -e "${YELLOW}Deploying v2 deployment...${NC}"
kubectl apply -f ../k8s/deployments/v2-deployment.yaml
echo -e "${GREEN}✓ v2 deployment created${NC}"
echo ""

# Wait for deployment to be ready
echo -e "${YELLOW}Waiting for canary pods to be ready...${NC}"
kubectl wait --for=condition=ready pod \
  -l app=demo-app,version=v2 \
  -n canary-demo \
  --timeout=300s

echo -e "${GREEN}✓ Canary pods are ready${NC}"
echo ""

# Apply 10% canary traffic
echo -e "${YELLOW}Configuring traffic routing (10% canary)...${NC}"
kubectl apply -f ../istio/virtualservice/01-canary-10.yaml
echo -e "${GREEN}✓ Traffic shifted to 10% canary${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Canary Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Current traffic distribution:"
echo -e "  v1 (stable): ${GREEN}90%${NC}"
echo -e "  v2 (canary): ${YELLOW}10%${NC}"
echo ""
echo -e "Monitor the deployment:"
echo -e "  ${YELLOW}kubectl get pods -n canary-demo -l app=demo-app${NC}"
echo -e "  ${YELLOW}kubectl logs -f -l app=demo-app,version=v2 -n canary-demo${NC}"
echo ""
echo -e "Test the canary:"
echo -e "  ${YELLOW}./test-traffic.sh${NC}"
echo ""
echo -e "Next steps:"
echo -e "  1. Monitor metrics and errors"
echo -e "  2. If stable, shift more traffic: ${YELLOW}./shift-traffic.sh 25${NC}"
echo -e "  3. If issues detected, rollback: ${YELLOW}./rollback.sh${NC}"
echo ""

# Made with Bob
