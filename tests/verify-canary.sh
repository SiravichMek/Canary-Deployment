#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Verifying Canary Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check namespace
echo -e "${YELLOW}Checking namespace...${NC}"
if kubectl get namespace canary-demo &> /dev/null; then
    echo -e "${GREEN}✓ Namespace exists${NC}"
else
    echo -e "${RED}✗ Namespace not found${NC}"
    exit 1
fi
echo ""

# Check deployments
echo -e "${YELLOW}Checking deployments...${NC}"
v1_ready=$(kubectl get deployment demo-app-v1 -n canary-demo -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
v2_ready=$(kubectl get deployment demo-app-v2 -n canary-demo -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")

echo -e "v1 ready replicas: ${GREEN}${v1_ready}${NC}"
echo -e "v2 ready replicas: ${YELLOW}${v2_ready}${NC}"

if [ "$v1_ready" -gt 0 ]; then
    echo -e "${GREEN}✓ v1 deployment is running${NC}"
else
    echo -e "${RED}✗ v1 deployment not ready${NC}"
fi

if [ "$v2_ready" -gt 0 ]; then
    echo -e "${GREEN}✓ v2 deployment is running${NC}"
else
    echo -e "${YELLOW}⚠ v2 deployment not ready (may not be deployed yet)${NC}"
fi
echo ""

# Check service
echo -e "${YELLOW}Checking service...${NC}"
if kubectl get service demo-app -n canary-demo &> /dev/null; then
    echo -e "${GREEN}✓ Service exists${NC}"
    kubectl get service demo-app -n canary-demo
else
    echo -e "${RED}✗ Service not found${NC}"
    exit 1
fi
echo ""

# Check Istio resources
echo -e "${YELLOW}Checking Istio resources...${NC}"

if kubectl get gateway demo-app-gateway -n canary-demo &> /dev/null; then
    echo -e "${GREEN}✓ Gateway exists${NC}"
else
    echo -e "${RED}✗ Gateway not found${NC}"
fi

if kubectl get virtualservice demo-app -n canary-demo &> /dev/null; then
    echo -e "${GREEN}✓ VirtualService exists${NC}"
    
    # Get current traffic split
    echo ""
    echo -e "${YELLOW}Current traffic configuration:${NC}"
    kubectl get virtualservice demo-app -n canary-demo -o jsonpath='{.spec.http[0].route[*].destination.subset}' | tr ' ' '\n' | while read subset; do
        weight=$(kubectl get virtualservice demo-app -n canary-demo -o jsonpath="{.spec.http[0].route[?(@.destination.subset=='$subset')].weight}")
        echo -e "  $subset: ${weight}%"
    done
else
    echo -e "${RED}✗ VirtualService not found${NC}"
fi

if kubectl get destinationrule demo-app -n canary-demo &> /dev/null; then
    echo -e "${GREEN}✓ DestinationRule exists${NC}"
else
    echo -e "${RED}✗ DestinationRule not found${NC}"
fi
echo ""

# Check pod health
echo -e "${YELLOW}Checking pod health...${NC}"
kubectl get pods -n canary-demo -l app=demo-app

echo ""
unhealthy=$(kubectl get pods -n canary-demo -l app=demo-app --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)
if [ "$unhealthy" -eq 0 ]; then
    echo -e "${GREEN}✓ All pods are healthy${NC}"
else
    echo -e "${RED}✗ $unhealthy unhealthy pods found${NC}"
fi
echo ""

# Test connectivity
echo -e "${YELLOW}Testing connectivity...${NC}"
INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')

if [ -z "$INGRESS_HOST" ]; then
    INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
fi

if [ -z "$INGRESS_HOST" ]; then
    INGRESS_HOST=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
fi

GATEWAY_URL="http://${INGRESS_HOST}:${INGRESS_PORT}"

echo -e "Testing: ${GATEWAY_URL}/health"
if curl -s -f "${GATEWAY_URL}/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Application is accessible${NC}"
    
    # Get version info
    version_info=$(curl -s "${GATEWAY_URL}/api/version")
    echo ""
    echo -e "${YELLOW}Version info:${NC}"
    echo "$version_info" | grep -o '"version":"[^"]*"' | cut -d'"' -f4
else
    echo -e "${RED}✗ Application is not accessible${NC}"
fi
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Verification Complete${NC}"
echo -e "${GREEN}========================================${NC}"

# Made with Bob
