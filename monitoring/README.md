# Monitoring (Prometheus + Grafana)

This project uses **kube-prometheus-stack** (Prometheus Operator + Prometheus + Alertmanager + Grafana).

## Install (Helm)

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f monitoring/kube-prometheus-stack-values.yaml
```

## Access Grafana

```bash
kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d; echo
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Open `http://localhost:3000` (user: `admin`).

## Verify app metrics

After deploying the app:

```bash
kubectl -n devops-demo get svc devops-demo-api
kubectl -n devops-demo port-forward svc/devops-demo-api 8000:80
curl http://localhost:8000/metrics
```

