#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get Istio ingress gateway URL
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

# Number of requests
REQUESTS=${1:-100}

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testing Traffic Distribution${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Gateway URL: ${YELLOW}${GATEWAY_URL}${NC}"
echo -e "Sending ${YELLOW}${REQUESTS}${NC} requests..."
echo ""

# Initialize counters
v1_count=0
v2_count=0
error_count=0

# Send requests and count versions
for i in $(seq 1 $REQUESTS); do
    response=$(curl -s "${GATEWAY_URL}/api/version" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        version=$(echo $response | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        
        if [ "$version" == "v1.0.0" ]; then
            ((v1_count++))
            echo -ne "${GREEN}.${NC}"
        elif [ "$version" == "v2.0.0" ]; then
            ((v2_count++))
            echo -ne "${YELLOW}.${NC}"
        else
            ((error_count++))
            echo -ne "${RED}x${NC}"
        fi
    else
        ((error_count++))
        echo -ne "${RED}x${NC}"
    fi
    
    # New line every 50 requests
    if [ $((i % 50)) -eq 0 ]; then
        echo ""
    fi
done

echo ""
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Results${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Calculate percentages
v1_percent=$(awk "BEGIN {printf \"%.1f\", ($v1_count/$REQUESTS)*100}")
v2_percent=$(awk "BEGIN {printf \"%.1f\", ($v2_count/$REQUESTS)*100}")
error_percent=$(awk "BEGIN {printf \"%.1f\", ($error_count/$REQUESTS)*100}")

echo -e "Total requests: ${YELLOW}${REQUESTS}${NC}"
echo ""
echo -e "v1 (stable):  ${GREEN}${v1_count}${NC} requests (${v1_percent}%)"
echo -e "v2 (canary):  ${YELLOW}${v2_count}${NC} requests (${v2_percent}%)"
echo -e "Errors:       ${RED}${error_count}${NC} requests (${error_percent}%)"
echo ""

# Visual bar chart
echo -e "Distribution:"
v1_bar=$(printf '█%.0s' $(seq 1 $((v1_count * 50 / REQUESTS))))
v2_bar=$(printf '█%.0s' $(seq 1 $((v2_count * 50 / REQUESTS))))

echo -e "v1: ${GREEN}${v1_bar}${NC}"
echo -e "v2: ${YELLOW}${v2_bar}${NC}"
echo ""

# Health check
if [ $error_count -gt $((REQUESTS / 20)) ]; then
    echo -e "${RED}⚠️  High error rate detected! Consider rollback.${NC}"
else
    echo -e "${GREEN}✓ Traffic distribution looks healthy${NC}"
fi
echo ""

# Made with Bob
