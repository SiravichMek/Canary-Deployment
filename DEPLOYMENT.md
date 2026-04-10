# Deployment Guide

Complete guide for deploying and managing the canary deployment system.

## 📋 Table of Contents

- [Initial Setup](#initial-setup)
- [Deployment Workflow](#deployment-workflow)
- [Environment Promotion](#environment-promotion)
- [Rollback Procedures](#rollback-procedures)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)

## Initial Setup

### 1. Install Prerequisites

```bash
# Install Argo Rollouts
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Verify installation
kubectl get pods -n argo-rollouts

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 2. Install Istio

```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio with demo profile
istioctl install --set profile=demo -y

# Verify installation
kubectl get pods -n istio-system
```

### 3. Install Prometheus (Optional)

```bash
# Install Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# Verify installation
kubectl get pods -n monitoring
```

### 4. Configure ArgoCD

```bash
# Login to ArgoCD
argocd login <ARGOCD_SERVER> --username admin --password <PASSWORD>

# Add Git repository
argocd repo add https://github.com/your-org/k8s-canary-demo.git \
  --username <GIT_USERNAME> \
  --password <GIT_TOKEN>
```

### 5. Deploy Applications

```bash
# Apply AppProject
kubectl apply -f argo/appproject.yaml

# Deploy to environments
kubectl apply -f argo/application-dev.yaml
kubectl apply -f argo/application-staging.yaml
kubectl apply -f argo/application-prod.yaml
```

## Deployment Workflow

### Development Deployment

```bash
# 1. Build and push image
docker build -t your-registry/demo-app:v1.1.0-dev app/
docker push your-registry/demo-app:v1.1.0-dev

# 2. Update kustomization
vim overlays/dev/kustomization.yaml
# Change: newTag: v1.1.0-dev

# 3. Commit and push
git add overlays/dev/kustomization.yaml
git commit -m "Deploy v1.1.0-dev to development"
git push origin develop

# 4. Monitor deployment
kubectl argo rollouts get rollout dev-demo-app -n canary-demo-dev --watch
```

### Staging Deployment

```bash
# 1. Tag image as RC
docker tag your-registry/demo-app:v1.1.0-dev your-registry/demo-app:v1.1.0-rc
docker push your-registry/demo-app:v1.1.0-rc

# 2. Update kustomization
vim overlays/staging/kustomization.yaml
# Change: newTag: v1.1.0-rc

# 3. Commit and push
git add overlays/staging/kustomization.yaml
git commit -m "Deploy v1.1.0-rc to staging"
git push origin staging

# 4. Monitor deployment
kubectl argo rollouts get rollout staging-demo-app -n canary-demo-staging --watch
```

### Production Deployment

```bash
# 1. Tag final release
docker tag your-registry/demo-app:v1.1.0-rc your-registry/demo-app:v1.1.0
docker push your-registry/demo-app:v1.1.0

# 2. Update kustomization
vim overlays/prod/kustomization.yaml
# Change: newTag: v1.1.0

# 3. Commit and push
git add overlays/prod/kustomization.yaml
git commit -m "Deploy v1.1.0 to production"
git push origin main

# 4. Monitor deployment
kubectl argo rollouts get rollout demo-app -n canary-demo --watch
```

## Environment Promotion

### Dev → Staging

```bash
# 1. Verify dev deployment
kubectl argo rollouts status dev-demo-app -n canary-demo-dev

# 2. Create RC image
docker tag your-registry/demo-app:v1.1.0-dev your-registry/demo-app:v1.1.0-rc
docker push your-registry/demo-app:v1.1.0-rc

# 3. Update staging
vim overlays/staging/kustomization.yaml
git add overlays/staging/kustomization.yaml
git commit -m "Promote v1.1.0 to staging"
git push origin staging
```

### Staging → Production

```bash
# 1. Verify staging deployment
kubectl argo rollouts status staging-demo-app -n canary-demo-staging

# 2. Create production release
docker tag your-registry/demo-app:v1.1.0-rc your-registry/demo-app:v1.1.0
docker push your-registry/demo-app:v1.1.0

# 3. Update production
vim overlays/prod/kustomization.yaml
git add overlays/prod/kustomization.yaml
git commit -m "Release v1.1.0 to production"
git push origin main
```

## Rollback Procedures

### Automatic Rollback

Automatic rollback occurs when:
- Success rate < 95%
- Error rate > 5%
- P95 latency > 500ms
- 3 consecutive analysis failures

**No action needed** - Argo Rollouts handles it automatically.

### Manual Rollback

#### Quick Rollback (Abort Current Rollout)

```bash
# Abort the current rollout
kubectl argo rollouts abort demo-app -n canary-demo

# Verify rollback
kubectl argo rollouts status demo-app -n canary-demo
```

#### Full Rollback (Revert to Previous Version)

```bash
# 1. Identify previous version
git log --oneline overlays/prod/kustomization.yaml

# 2. Revert to previous commit
git revert HEAD

# 3. Or manually update to previous version
vim overlays/prod/kustomization.yaml
# Change newTag to previous version

# 4. Commit and push
git add overlays/prod/kustomization.yaml
git commit -m "Rollback to v1.0.0"
git push origin main

# 5. Monitor rollback
kubectl argo rollouts get rollout demo-app -n canary-demo --watch
```

## Monitoring

### Real-time Monitoring

```bash
# Argo Rollouts Dashboard
kubectl argo rollouts dashboard
# Access at http://localhost:3100

# ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Access at https://localhost:8080

# Watch rollout progress
kubectl argo rollouts get rollout demo-app -n canary-demo --watch
```

### Check Analysis Results

```bash
# List analysis runs
kubectl get analysisrun -n canary-demo

# Describe specific analysis
kubectl describe analysisrun demo-app-<hash>-<step> -n canary-demo

# View analysis logs
kubectl logs -n canary-demo -l analysisrun=demo-app-<hash>
```

### Verify Traffic Distribution

```bash
# Check VirtualService weights
kubectl get virtualservice demo-app -n canary-demo -o yaml | grep weight

# Test traffic distribution
for i in {1..100}; do
  curl -s http://<GATEWAY_URL>/version | jq -r .version
done | sort | uniq -c
```

### Monitor Metrics

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090

# Query success rate
curl -s 'http://localhost:9090/api/v1/query?query=sum(rate(http_requests_total{namespace="canary-demo",status_code!~"5.."}[2m]))/sum(rate(http_requests_total{namespace="canary-demo"}[2m]))'
```

## Troubleshooting

### Rollout Stuck

```bash
# Check rollout status
kubectl argo rollouts status demo-app -n canary-demo

# Check for errors
kubectl describe rollout demo-app -n canary-demo

# Check controller logs
kubectl logs -n argo-rollouts -l app.kubernetes.io/name=argo-rollouts
```

### Analysis Failing

```bash
# Check analysis run details
kubectl get analysisrun -n canary-demo
kubectl describe analysisrun <name> -n canary-demo

# Verify Prometheus connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://prometheus-operated.monitoring.svc.cluster.local:9090/-/healthy
```

### ArgoCD Out of Sync

```bash
# Check sync status
argocd app get demo-app-prod

# Force sync
argocd app sync demo-app-prod --force

# Or via kubectl
kubectl patch application demo-app-prod -n argocd \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n canary-demo

# View pod logs
kubectl logs -l app=demo-app -n canary-demo

# Describe pod for events
kubectl describe pod <pod-name> -n canary-demo
```

### Traffic Not Routing

```bash
# Verify VirtualService
kubectl get virtualservice demo-app -n canary-demo -o yaml

# Check DestinationRule
kubectl get destinationrule demo-app -n canary-demo -o yaml

# View Istio proxy logs
kubectl logs -l app=demo-app -c istio-proxy -n canary-demo
```

## Best Practices

1. **Always test in lower environments first** (Dev → Staging → Production)
2. **Use semantic versioning** (v1.2.3 for releases, v1.2.3-rc for candidates)
3. **Monitor during business hours** for production deployments
4. **Document all changes** with clear commit messages
5. **Keep rollout conservative** in production - don't skip steps
6. **Test rollback procedures** regularly in staging
7. **Maintain deployment logs** and analysis results
8. **Review and update** analysis templates based on incidents

---

**Remember: Safety first! When in doubt, rollback and investigate.**