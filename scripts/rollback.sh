#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}========================================${NC}"
echo -e "${RED}Rolling Back to Stable Version${NC}"
echo -e "${RED}========================================${NC}"
echo ""

echo -e "${YELLOW}⚠️  This will revert all traffic to v1 (stable version)${NC}"
read -p "Continue? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Rollback cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Reverting traffic to 100% v1...${NC}"
kubectl apply -f ../istio/virtualservice/00-initial.yaml
echo -e "${GREEN}✓ Traffic reverted to stable version${NC}"
echo ""

echo -e "${YELLOW}Scaling down canary deployment...${NC}"
kubectl scale deployment demo-app-v2 --replicas=0 -n canary-demo
echo -e "${GREEN}✓ Canary deployment scaled down${NC}"
echo ""

echo -e "${RED}========================================${NC}"
echo -e "${RED}Rollback Complete!${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "Current state:"
echo -e "  v1 (stable): ${GREEN}100% traffic${NC}"
echo -e "  v2 (canary): ${RED}0% traffic (scaled to 0)${NC}"
echo ""
echo -e "View current pods:"
echo -e "  ${YELLOW}kubectl get pods -n canary-demo${NC}"
echo ""
echo -e "Check logs for issues:"
echo -e "  ${YELLOW}kubectl logs -l app=demo-app,version=v2 -n canary-demo --tail=100${NC}"
echo ""
echo -e "To completely remove canary deployment:"
echo -e "  ${YELLOW}kubectl delete deployment demo-app-v2 -n canary-demo${NC}"
echo ""

# Made with Bob
