#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}========================================${NC}"
echo -e "${RED}Cleanup Canary Demo Resources${NC}"
echo -e "${RED}========================================${NC}"
echo ""

echo -e "${YELLOW}⚠️  This will delete all demo resources${NC}"
read -p "Continue? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cleanup cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Deleting namespace and all resources...${NC}"
kubectl delete namespace canary-demo --ignore-not-found=true

echo -e "${GREEN}✓ Resources deleted${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "All demo resources have been removed."
echo ""
echo -e "To start over, run:"
echo -e "  ${YELLOW}./setup.sh${NC}"
echo ""

# Made with Bob
