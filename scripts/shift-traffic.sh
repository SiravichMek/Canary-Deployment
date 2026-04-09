#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get percentage from argument or default to next stage
PERCENTAGE=${1:-25}

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Shifting Traffic to Canary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Validate percentage
case $PERCENTAGE in
    10)
        CONFIG_FILE="../istio/virtualservice/01-canary-10.yaml"
        V1_PERCENT=90
        V2_PERCENT=10
        ;;
    25)
        CONFIG_FILE="../istio/virtualservice/02-canary-25.yaml"
        V1_PERCENT=75
        V2_PERCENT=25
        ;;
    50)
        CONFIG_FILE="../istio/virtualservice/03-canary-50.yaml"
        V1_PERCENT=50
        V2_PERCENT=50
        ;;
    75)
        CONFIG_FILE="../istio/virtualservice/04-canary-75.yaml"
        V1_PERCENT=25
        V2_PERCENT=75
        ;;
    100)
        CONFIG_FILE="../istio/virtualservice/05-full-v2.yaml"
        V1_PERCENT=0
        V2_PERCENT=100
        ;;
    *)
        echo -e "${RED}Invalid percentage. Use: 10, 25, 50, 75, or 100${NC}"
        exit 1
        ;;
esac

echo -e "${YELLOW}Applying traffic configuration...${NC}"
kubectl apply -f $CONFIG_FILE
echo -e "${GREEN}✓ Traffic configuration applied${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Traffic Shift Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Current traffic distribution:"
echo -e "  v1 (stable): ${GREEN}${V1_PERCENT}%${NC}"
echo -e "  v2 (canary): ${YELLOW}${V2_PERCENT}%${NC}"
echo ""

if [ "$PERCENTAGE" -eq 100 ]; then
    echo -e "${GREEN}🎉 Canary rollout complete! v2 is now serving 100% of traffic.${NC}"
    echo ""
    echo -e "Optional: Scale down v1 deployment"
    echo -e "  ${YELLOW}kubectl scale deployment demo-app-v1 --replicas=0 -n canary-demo${NC}"
    echo ""
else
    echo -e "Monitor the deployment for issues:"
    echo -e "  ${YELLOW}kubectl get pods -n canary-demo${NC}"
    echo -e "  ${YELLOW}kubectl logs -f -l app=demo-app,version=v2 -n canary-demo${NC}"
    echo ""
    echo -e "Next steps:"
    
    case $PERCENTAGE in
        10)
            echo -e "  Continue rollout: ${YELLOW}./shift-traffic.sh 25${NC}"
            ;;
        25)
            echo -e "  Continue rollout: ${YELLOW}./shift-traffic.sh 50${NC}"
            ;;
        50)
            echo -e "  Continue rollout: ${YELLOW}./shift-traffic.sh 75${NC}"
            ;;
        75)
            echo -e "  Complete rollout: ${YELLOW}./shift-traffic.sh 100${NC}"
            ;;
    esac
    
    echo -e "  Rollback if needed: ${YELLOW}./rollback.sh${NC}"
    echo ""
fi

# Made with Bob
