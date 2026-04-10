# Istio Integration with Argo Rollouts

## Overview

Argo Rollouts integrates with Istio to dynamically control traffic splitting during canary deployments. The integration allows Argo Rollouts to automatically modify Istio's VirtualService weights without manual intervention.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Argo Rollouts Controller                  │
│  - Manages canary deployment steps                          │
│  - Automatically updates VirtualService weights             │
│  - Monitors analysis results                                │
└─────────────────────────┬───────────────────────────────────┘
                          │ Updates weights
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Istio VirtualService                      │
│  - Routes traffic based on weights                          │
│  - Splits between stable and canary                         │
└─────────────────────────┬───────────────────────────────────┘
                          │ Routes to
                          ▼
┌──────────────────────────────────────────────────────────────┐
│              Kubernetes Services                             │
│  ┌─────────────────────┐    ┌─────────────────────┐        │
│  │  demo-app-stable    │    │  demo-app-canary    │        │
│  │  (Stable pods)      │    │  (Canary pods)      │        │
│  └─────────────────────┘    └─────────────────────┘        │
└──────────────────────────────────────────────────────────────┘
```

## Istio Manifests Explained

### 1. Gateway (`istio-gateway.yaml`)

**Purpose**: Entry point for external traffic into the mesh.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: demo-app-gateway
spec:
  selector:
    istio: ingressgateway  # Uses Istio's ingress gateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"  # Accept all hosts
```

**Key Points**:
- Defines how external traffic enters the service mesh
- Binds to Istio's ingress gateway pods
- Accepts HTTP traffic on port 80

### 2. VirtualService (`istio-virtualservice.yaml`)

**Purpose**: Defines traffic routing rules and weight distribution.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: demo-app  # Referenced by Argo Rollouts
spec:
  hosts:
  - "*"
  gateways:
  - demo-app-gateway  # Links to Gateway
  http:
  - name: primary  # Route name referenced by Rollout
    match:
    - uri:
        prefix: /
    route:
    - destination:
        host: demo-app-stable  # Stable service
        port:
          number: 80
      weight: 100  # Initially 100% to stable
    - destination:
        host: demo-app-canary  # Canary service
        port:
          number: 80
      weight: 0  # Initially 0% to canary
```

**Key Points**:
- **Argo Rollouts modifies these weights automatically**
- Route name `primary` must match Rollout configuration
- Weights are dynamically updated during canary progression
- Example progression: 100/0 → 90/10 → 75/25 → 50/50 → 0/100

### 3. DestinationRule (`istio-destinationrule.yaml`)

**Purpose**: Defines traffic policies and service subsets.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: demo-app  # Referenced by Argo Rollouts
spec:
  host: demo-app
  trafficPolicy:
    loadBalancer:
      simple: LEAST_REQUEST  # Load balancing algorithm
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 100
    outlierDetection:  # Circuit breaker
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
  subsets:
  - name: stable  # Referenced by Rollout
    labels:
      app: demo-app
  - name: canary  # Referenced by Rollout
    labels:
      app: demo-app
```

**Key Points**:
- Defines `stable` and `canary` subsets
- Subset names must match Rollout configuration
- Provides traffic policies (load balancing, circuit breaking)
- Argo Rollouts uses subsets to identify pod versions

## Argo Rollouts Integration

### Rollout Configuration

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: demo-app
spec:
  strategy:
    canary:
      # Link to Kubernetes services
      stableService: demo-app-stable
      canaryService: demo-app-canary
      
      # Istio integration configuration
      trafficRouting:
        istio:
          virtualService:
            name: demo-app  # VirtualService to modify
            routes:
            - primary  # Route name to update
          destinationRule:
            name: demo-app  # DestinationRule with subsets
            canarySubsetName: canary  # Subset for canary pods
            stableSubsetName: stable  # Subset for stable pods
      
      # Canary steps
      steps:
      - setWeight: 10  # Argo updates VirtualService to 90/10
      - pause:
          duration: 2m
      - setWeight: 25  # Argo updates VirtualService to 75/25
      # ... more steps
```

## How It Works

### Step-by-Step Flow

1. **Initial State**
   ```
   VirtualService weights: stable=100, canary=0
   All traffic → stable pods
   ```

2. **Canary Deployment Starts**
   ```
   - Argo Rollouts creates new canary pods
   - Canary pods get label matching canary subset
   ```

3. **Step 1: setWeight: 10**
   ```
   - Argo Rollouts updates VirtualService
   - New weights: stable=90, canary=10
   - 10% traffic → canary pods
   - 90% traffic → stable pods
   ```

4. **Analysis Runs**
   ```
   - Prometheus queries metrics from canary pods
   - If healthy: proceed to next step
   - If unhealthy: automatic rollback (weights back to 100/0)
   ```

5. **Step 2: setWeight: 25**
   ```
   - Argo Rollouts updates VirtualService again
   - New weights: stable=75, canary=25
   - 25% traffic → canary pods
   ```

6. **Continue Until Complete**
   ```
   - Progressive weight increases: 10 → 25 → 50 → 75 → 100
   - Final state: stable=0, canary=100
   - Old stable pods are terminated
   - Canary becomes new stable
   ```

## Key Integration Points

### 1. Service Mapping
```
Rollout.spec.strategy.canary.stableService → demo-app-stable
Rollout.spec.strategy.canary.canaryService → demo-app-canary
```

### 2. VirtualService Control
```
Rollout.spec.strategy.canary.trafficRouting.istio.virtualService.name → demo-app
Rollout.spec.strategy.canary.trafficRouting.istio.virtualService.routes → primary
```

### 3. Subset Identification
```
Rollout.spec.strategy.canary.trafficRouting.istio.destinationRule.name → demo-app
Rollout.spec.strategy.canary.trafficRouting.istio.destinationRule.stableSubsetName → stable
Rollout.spec.strategy.canary.trafficRouting.istio.destinationRule.canarySubsetName → canary
```

## Benefits

1. **Automated Traffic Control**: No manual VirtualService updates needed
2. **Fine-Grained Control**: Precise traffic splitting percentages
3. **Safe Rollbacks**: Instant traffic reversion on failures
4. **Zero Downtime**: Gradual traffic shift ensures availability
5. **Circuit Breaking**: Istio's outlier detection protects against bad pods

## Verification

### Check Current Weights
```bash
kubectl get virtualservice demo-app -n canary-demo -o yaml | grep -A 10 "route:"
```

### Monitor Traffic Distribution
```bash
# Watch rollout progress
kubectl argo rollouts get rollout demo-app -n canary-demo --watch

# Test actual traffic distribution
for i in {1..100}; do
  curl -s http://<GATEWAY_URL>/version | jq -r .version
done | sort | uniq -c
```

### View Istio Configuration
```bash
# Check VirtualService
kubectl get virtualservice demo-app -n canary-demo -o yaml

# Check DestinationRule
kubectl get destinationrule demo-app -n canary-demo -o yaml

# Check Gateway
kubectl get gateway demo-app-gateway -n canary-demo -o yaml
```

## Troubleshooting

### Traffic Not Splitting
```bash
# Verify VirtualService is being updated
kubectl get virtualservice demo-app -n canary-demo -o yaml | grep weight

# Check Argo Rollouts controller logs
kubectl logs -n argo-rollouts -l app.kubernetes.io/name=argo-rollouts

# Verify Istio proxy is routing correctly
kubectl logs -l app=demo-app -c istio-proxy -n canary-demo
```

### Rollout Not Progressing
```bash
# Check if VirtualService name matches
kubectl describe rollout demo-app -n canary-demo | grep -A 5 "Traffic Routing"

# Verify subset names match
kubectl get destinationrule demo-app -n canary-demo -o yaml | grep -A 2 "subsets:"
```

---

**Summary**: Argo Rollouts acts as a controller that automatically modifies Istio's VirtualService weights during canary deployments, enabling automated progressive delivery with instant rollback capabilities.