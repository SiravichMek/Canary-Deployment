# Kubernetes Canary Deployment Demo with Istio

A complete demonstration of canary deployment patterns in Kubernetes using Istio service mesh for automated traffic management and progressive delivery.

![Kubernetes](https://img.shields.io/badge/kubernetes-v1.24+-blue.svg)
![Istio](https://img.shields.io/badge/istio-v1.18+-blue.svg)
![Node.js](https://img.shields.io/badge/node.js-v18+-green.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## 🎯 Overview

This project demonstrates:
- **Progressive canary deployments** with automated traffic shifting
- **Istio service mesh** for advanced traffic management
- **Prometheus & Grafana** for monitoring and observability
- **Automated rollback** based on error rates and performance metrics
- **Production-ready patterns** for safe deployments

## 📋 Table of Contents

- [Features](#-features)
- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Detailed Setup](#-detailed-setup)
- [Demo Walkthrough](#-demo-walkthrough)
- [Monitoring](#-monitoring)
- [Troubleshooting](#-troubleshooting)
- [Project Structure](#-project-structure)

## ✨ Features

### Application
- Node.js/Express REST API with version endpoints
- Visual web interface showing version information
- Prometheus metrics integration
- Health check endpoints (liveness, readiness, startup)
- Configurable error injection for testing

### Deployment
- Progressive traffic shifting (10% → 25% → 50% → 75% → 100%)
- Automated rollback on errors
- Zero-downtime deployments
- Circuit breaker configuration
- Load balancing with Istio

### Monitoring
- Real-time metrics with Prometheus
- Grafana dashboards for visualization
- Alert rules for automated rollback
- Traffic distribution tracking
- Error rate and latency monitoring

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        External Traffic                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
                  ┌──────────────┐
                  │ Istio Gateway│
                  └──────┬───────┘
                         │
                         ▼
                ┌────────────────┐
                │ VirtualService │ ◄── Traffic Splitting
                └────────┬───────┘
                         │
                         ▼
                ┌────────────────┐
                │DestinationRule│ ◄── Version Routing
                └────────┬───────┘
                         │
                         ▼
                  ┌──────────────┐
                  │   Service    │
                  └──────┬───────┘
                         │
         ┌───────────────┴───────────────┐
         │                               │
         ▼                               ▼
┌─────────────────┐           ┌─────────────────┐
│  v1 Deployment  │           │  v2 Deployment  │
│   (3 replicas)  │           │   (1 replica)   │
└─────────────────┘           └─────────────────┘
         │                               │
         └───────────────┬───────────────┘
                         │
                         ▼
                  ┌──────────────┐
                  │  Prometheus  │
                  └──────┬───────┘
                         │
                         ▼
                  ┌──────────────┐
                  │   Grafana    │
                  └──────────────┘
```

## 📦 Prerequisites

- **Kubernetes cluster** (v1.24+)
  - Minikube, Kind, or cloud provider (GKE, EKS, AKS)
- **kubectl** configured and connected to your cluster
- **Docker** for building images
- **Istio** (v1.18+) - will be installed by setup script if not present
- **Helm** (optional, for Prometheus/Grafana)

### Optional
- **Prometheus Operator** for monitoring
- **Grafana** for dashboards

## 🚀 Quick Start

```bash
# 1. Clone the repository
git clone <repository-url>
cd k8s-canary-demo

# 2. Run setup script
cd scripts
./setup.sh

# 3. Deploy stable version (v1)
./deploy-v1.sh

# 4. Deploy canary version (v2)
./deploy-canary.sh

# 5. Test traffic distribution
./test-traffic.sh

# 6. Shift traffic progressively
./shift-traffic.sh 25
./shift-traffic.sh 50
./shift-traffic.sh 75
./shift-traffic.sh 100

# 7. Rollback if needed
./rollback.sh
```

## 🔧 Detailed Setup

### Step 1: Environment Setup

```bash
# Verify prerequisites
kubectl version --client
docker --version
istioctl version  # If Istio is already installed

# Create a Kubernetes cluster (if needed)
# For Minikube:
minikube start --cpus=4 --memory=8192

# For Kind:
kind create cluster --name canary-demo
```

### Step 2: Install Istio

The setup script will install Istio automatically, or you can install manually:

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

### Step 3: Build and Deploy

```bash
cd scripts

# Run complete setup
./setup.sh

# This will:
# - Create namespace with Istio injection
# - Build Docker images (v1 and v2)
# - Configure Istio Gateway and DestinationRule
# - Set up monitoring (if Prometheus Operator is available)
```

### Step 4: Deploy Application

```bash
# Deploy stable version
./deploy-v1.sh

# Wait for pods to be ready
kubectl get pods -n canary-demo -w

# Get application URL
kubectl get svc -n istio-system istio-ingressgateway
```

## 🎬 Demo Walkthrough

### Scenario: Rolling out a new feature safely

#### 1. Initial State - 100% Stable (v1)

```bash
./deploy-v1.sh
```

- All traffic goes to v1 (blue interface)
- 3 replicas running
- Baseline metrics established

#### 2. Deploy Canary - 10% Traffic

```bash
./deploy-canary.sh
```

- v2 deployed with 1 replica (red interface)
- 10% of traffic routed to v2
- Monitor for errors and performance

```bash
# Test traffic distribution
./test-traffic.sh 100

# Expected output:
# v1: ~90 requests (90%)
# v2: ~10 requests (10%)
```

#### 3. Progressive Rollout

```bash
# Increase to 25%
./shift-traffic.sh 25

# Monitor metrics
kubectl logs -f -l app=demo-app,version=v2 -n canary-demo

# Continue if stable
./shift-traffic.sh 50
./shift-traffic.sh 75
./shift-traffic.sh 100
```

#### 4. Rollback (if issues detected)

```bash
# Immediate rollback to v1
./rollback.sh

# This will:
# - Revert traffic to 100% v1
# - Scale down v2 to 0 replicas
# - Preserve logs for investigation
```

### Testing Different Scenarios

#### Simulate High Error Rate

```bash
# Update v2 ConfigMap to inject errors
kubectl patch configmap demo-app-v2-config -n canary-demo \
  --type merge -p '{"data":{"ERROR_RATE":"0.1"}}'

# Restart v2 pods
kubectl rollout restart deployment demo-app-v2 -n canary-demo

# Deploy and watch alerts trigger
./deploy-canary.sh
```

#### Load Testing

```bash
# Get gateway URL
export GATEWAY_URL=$(kubectl -n istio-system get service istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):80

# Run load test
cd ../tests
node load-test.js

# Or with custom parameters
GATEWAY_URL=$GATEWAY_URL DURATION=120 RPS=50 node load-test.js
```

## 📊 Monitoring

### Access Grafana Dashboard

```bash
# Port forward Grafana (if using Prometheus Operator)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open browser: http://localhost:3000
# Default credentials: admin/prom-operator
```

### Key Metrics to Monitor

1. **Request Rate by Version**
   - Track traffic distribution
   - Verify traffic shifting

2. **Error Rate**
   - Should be < 5% for canary
   - Triggers automatic rollback if exceeded

3. **Response Time (p95)**
   - Compare v1 vs v2
   - Should not exceed 2x stable version

4. **Pod Health**
   - CPU and memory usage
   - Restart count

### Prometheus Queries

```promql
# Request rate by version
sum(rate(http_requests_total{namespace="canary-demo"}[1m])) by (version)

# Error rate
sum(rate(http_request_errors_total{namespace="canary-demo"}[5m])) by (version) 
/ 
sum(rate(http_requests_total{namespace="canary-demo"}[5m])) by (version)

# p95 latency
histogram_quantile(0.95, 
  sum(rate(http_request_duration_seconds_bucket{namespace="canary-demo"}[5m])) by (version, le)
)
```

## 🔍 Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n canary-demo

# View pod logs
kubectl logs -l app=demo-app,version=v2 -n canary-demo

# Describe pod for events
kubectl describe pod <pod-name> -n canary-demo
```

### Traffic Not Routing Correctly

```bash
# Verify VirtualService
kubectl get virtualservice demo-app -n canary-demo -o yaml

# Check DestinationRule
kubectl get destinationrule demo-app -n canary-demo -o yaml

# View Istio proxy logs
kubectl logs -l app=demo-app -c istio-proxy -n canary-demo
```

### Cannot Access Application

```bash
# Check Istio Gateway
kubectl get gateway -n canary-demo

# Verify ingress gateway service
kubectl get svc -n istio-system istio-ingressgateway

# For Minikube, use tunnel
minikube tunnel

# For Kind, use port-forward
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80
```

### Monitoring Not Working

```bash
# Check if Prometheus Operator is installed
kubectl get crd servicemonitors.monitoring.coreos.com

# Install Prometheus stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# Verify ServiceMonitor
kubectl get servicemonitor -n canary-demo
```

## 📁 Project Structure

```
k8s-canary-demo/
├── app/                          # Node.js application
│   ├── src/
│   │   ├── index.js             # Main application
│   │   ├── routes/              # API routes
│   │   └── middleware/          # Metrics middleware
│   ├── package.json
│   └── Dockerfile
├── k8s/                          # Kubernetes manifests
│   ├── namespace.yaml
│   ├── deployments/
│   │   ├── v1-deployment.yaml
│   │   └── v2-deployment.yaml
│   ├── service.yaml
│   └── configmaps/
├── istio/                        # Istio configurations
│   ├── gateway.yaml
│   ├── destinationrule.yaml
│   └── virtualservice/          # Progressive traffic configs
│       ├── 00-initial.yaml      # 100% v1
│       ├── 01-canary-10.yaml    # 10% v2
│       ├── 02-canary-25.yaml    # 25% v2
│       ├── 03-canary-50.yaml    # 50% v2
│       ├── 04-canary-75.yaml    # 75% v2
│       └── 05-full-v2.yaml      # 100% v2
├── monitoring/                   # Monitoring configs
│   ├── prometheus/
│   │   ├── servicemonitor.yaml
│   │   └── alertrules.yaml
│   └── grafana/
│       └── dashboard.json
├── scripts/                      # Automation scripts
│   ├── setup.sh
│   ├── deploy-v1.sh
│   ├── deploy-canary.sh
│   ├── shift-traffic.sh
│   ├── rollback.sh
│   ├── test-traffic.sh
│   └── cleanup.sh
├── tests/                        # Testing utilities
│   ├── load-test.js
│   └── verify-canary.sh
└── README.md
```

## 🎓 Learning Resources

### Key Concepts Demonstrated

1. **Canary Deployments**
   - Progressive traffic shifting
   - Risk mitigation strategies
   - Automated rollback

2. **Istio Service Mesh**
   - Traffic management
   - Observability
   - Security policies

3. **Kubernetes Patterns**
   - Health checks
   - Resource management
   - ConfigMaps and Secrets

4. **Observability**
   - Metrics collection
   - Alerting
   - Distributed tracing

### Further Reading

- [Istio Documentation](https://istio.io/latest/docs/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Progressive Delivery](https://www.weave.works/blog/what-is-progressive-delivery-all-about)
- [SRE Principles](https://sre.google/sre-book/table-of-contents/)

## 🧹 Cleanup

```bash
# Remove all demo resources
cd scripts
./cleanup.sh

# Or manually
kubectl delete namespace canary-demo
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- Istio community for excellent service mesh capabilities
- Kubernetes community for container orchestration
- Prometheus and Grafana for monitoring solutions

---

**Happy Deploying! 🚀**

For questions or issues, please open an issue on GitHub.
