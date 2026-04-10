# Kubernetes GitOps Canary Deployment

A production-ready GitOps implementation with automated canary deployments using ArgoCD, Argo Rollouts, and Istio.

![Kubernetes](https://img.shields.io/badge/kubernetes-v1.24+-blue.svg)
![ArgoCD](https://img.shields.io/badge/argocd-v2.8+-blue.svg)
![Argo Rollouts](https://img.shields.io/badge/argo--rollouts-v1.6+-blue.svg)
![Istio](https://img.shields.io/badge/istio-v1.18+-blue.svg)

## 🎯 Overview

This project demonstrates a complete GitOps workflow with:
- **GitOps with ArgoCD** - Declarative deployments from Git
- **Progressive Canary** - Automated traffic shifting with Argo Rollouts
- **Automated Analysis** - Prometheus-based health checks and rollback
- **Multi-Environment** - Dev, staging, and production configurations
- **Istio Traffic Management** - Dynamic traffic splitting and circuit breaking

## 📁 Project Structure

```
k8s-canary-demo/
├── app/                    # Node.js application
├── base/                   # Base Kubernetes manifests
│   ├── namespace.yaml
│   ├── rollout.yaml       # Argo Rollout
│   ├── services.yaml
│   ├── analysis-templates.yaml
│   └── kustomization.yaml
├── overlays/              # Environment-specific configs
│   ├── dev/
│   ├── staging/
│   └── prod/
├── argo/                  # ArgoCD Applications
│   ├── appproject.yaml
│   ├── application-dev.yaml
│   ├── application-staging.yaml
│   └── application-prod.yaml
├── istio/                 # Istio configurations
│   ├── istio-gateway.yaml
│   ├── istio-virtualservice.yaml
│   └── istio-destinationrule.yaml
└── prometheus/            # Monitoring configs
    ├── servicemonitor.yaml
    ├── alertrules.yaml
    └── grafana/
```

## 🚀 Quick Start

### Step 1: Install Prerequisites

```bash
# Install Argo Rollouts
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Install Istio (if not already installed)
istioctl install --set profile=demo -y

# Verify installations
kubectl get pods -n argo-rollouts
kubectl get pods -n argocd
kubectl get pods -n istio-system
```

### Step 2: Initialize Project - Deploy v1.0.0

```bash
# 1. Build and push initial version
docker build -t your-registry/demo-app:v1.0.0 app/
docker push your-registry/demo-app:v1.0.0

# 2. Configure ArgoCD
kubectl apply -f argo/appproject.yaml

# 3. Deploy initial version to production
kubectl apply -f argo/application-prod.yaml

# 4. Wait for initial deployment to complete
kubectl wait --for=condition=available --timeout=300s deployment/demo-app -n canary-demo

# 5. Verify v1.0.0 is running
kubectl get pods -n canary-demo -l app=demo-app
kubectl argo rollouts status demo-app -n canary-demo

# 6. Test the application
export GATEWAY_URL=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$GATEWAY_URL/version
# Expected output: {"version":"v1.0.0"}
```

### Step 3: Access Dashboards

```bash
# ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access at https://localhost:8080
# Get password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Argo Rollouts Dashboard
kubectl argo rollouts dashboard
# Access at http://localhost:3100
```

## 🔄 GitOps Workflow

### Deployment Process

```
1. Update image tag in overlays/{env}/kustomization.yaml
2. Commit and push to Git
3. ArgoCD automatically syncs changes
4. Argo Rollouts performs canary deployment
5. Analysis runs at each step
6. Auto-promotes if healthy, rolls back if not
```

### Environment Strategy

| Environment | Branch | Replicas | Canary Steps | Analysis |
|------------|--------|----------|--------------|----------|
| **Dev** | develop | 2 | 2 (20%, 50%) | Relaxed |
| **Staging** | staging | 3 | 3 (10%, 25%, 50%) | Standard |
| **Production** | main | 5 | 4 (10%, 25%, 50%, 75%) | Strict |

### Testing Canary Deployment (v1.0.0 → v2.0.0)

Now that v1.0.0 is running, let's deploy v2.0.0 using canary strategy:

```bash
# 1. Build and push new version
docker build -t your-registry/demo-app:v2.0.0 app/
docker push your-registry/demo-app:v2.0.0

# 2. Update kustomization to trigger canary
vim overlays/prod/kustomization.yaml
# Change: newTag: v2.0.0

# 3. Commit and push to trigger GitOps
git add overlays/prod/kustomization.yaml
git commit -m "Deploy v2.0.0 to production (canary)"
git push origin main

# 4. Watch canary deployment progress
kubectl argo rollouts get rollout demo-app -n canary-demo --watch

# You'll see:
# - Step 1: 10% traffic to v2.0.0 (canary)
# - Analysis runs for 2 minutes
# - Step 2: 25% traffic to v2.0.0
# - Analysis runs for 2 minutes
# - Step 3: 50% traffic to v2.0.0
# - Analysis runs for 3 minutes
# - Step 4: 75% traffic to v2.0.0
# - Analysis runs for 2 minutes
# - Step 5: 100% traffic to v2.0.0 (promotion complete)

# 5. Test traffic distribution during canary
for i in {1..20}; do
  curl -s http://$GATEWAY_URL/version | jq -r .version
done | sort | uniq -c
# You'll see mix of v1.0.0 and v2.0.0 responses

# 6. Check analysis results
kubectl get analysisrun -n canary-demo
kubectl describe analysisrun <name> -n canary-demo
```

### Observing Automatic Rollback

If the canary version has issues, it will automatically rollback:

```bash
# Simulate a bad deployment (high error rate)
# The analysis will fail and trigger automatic rollback to v1.0.0

# Watch the rollback happen
kubectl argo rollouts get rollout demo-app -n canary-demo --watch

# Verify rollback to v1.0.0
curl http://$GATEWAY_URL/version
# Output: {"version":"v1.0.0"}
```

## 📊 Monitoring & Analysis

### Analysis Metrics

- **Success Rate**: ≥95% (prod/staging), ≥90% (dev)
- **Error Rate**: ≤5% (prod/staging), ≤10% (dev)
- **Latency P95**: ≤500ms
- **Comparative**: Canary ≤1.5x stable (production only)

### Automatic Rollback Triggers

- Success rate < threshold
- Error rate > threshold
- P95 latency > 500ms
- 3 consecutive analysis failures
- Pod restarts detected

### Access Dashboards

```bash
# Argo Rollouts Dashboard
kubectl argo rollouts dashboard
# Access at http://localhost:3100

# ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access at https://localhost:8080

# Prometheus (if installed)
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
```

## 🛠️ Operations

### Manual Promotion

```bash
kubectl argo rollouts promote demo-app -n canary-demo
```

### Manual Rollback

```bash
kubectl argo rollouts abort demo-app -n canary-demo
```

### Check Status

```bash
# Rollout status
kubectl argo rollouts status demo-app -n canary-demo

# Analysis runs
kubectl get analysisrun -n canary-demo

# View details
kubectl describe analysisrun <name> -n canary-demo
```

## 🔧 Customization

### Modify Canary Steps

Edit `overlays/{env}/rollout-patch.yaml`:

```yaml
spec:
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause:
          duration: 5m
```

### Adjust Analysis Thresholds

Edit `base/analysis-templates.yaml`:

```yaml
metrics:
- name: success-rate
  successCondition: result >= 0.98
  failureLimit: 5
```

### Change Resources

Edit `overlays/prod/resources-patch.yaml`:

```yaml
spec:
  template:
    spec:
      containers:
      - name: demo-app
        resources:
          limits:
            memory: "1Gi"
            cpu: "1000m"
```

## 🚨 Troubleshooting

### Rollout Stuck

```bash
kubectl argo rollouts status demo-app -n canary-demo
kubectl describe rollout demo-app -n canary-demo
kubectl logs -n argo-rollouts -l app.kubernetes.io/name=argo-rollouts
```

### Analysis Failing

```bash
kubectl get analysisrun -n canary-demo
kubectl describe analysisrun <name> -n canary-demo
```

### ArgoCD Not Syncing

```bash
kubectl get application -n argocd
argocd app sync demo-app-prod
```

## 📚 References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Argo Rollouts Documentation](https://argoproj.github.io/argo-rollouts/)
- [GitOps Principles](https://opengitops.dev/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Kustomize Documentation](https://kustomize.io/)

## 📄 License

MIT License

---

**Made with ❤️ for GitOps and Progressive Delivery**
