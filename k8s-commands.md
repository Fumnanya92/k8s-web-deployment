# Kubernetes & Minikube Commands Reference

## 🟢 Minikube & Cluster Setup
```sh
# Start Minikube (Docker driver)
minikube start --driver=docker

# Enable metrics-server addon
minikube addons enable metrics-server

# Check node status
kubectl get nodes
kubectl get nodes -o wide
```

---

## 🟡 Docker Image Build & Load
```sh
# Build Docker image (no cache)
docker build --no-cache -t gandalf-web:0.3 .

# Load image into Minikube
minikube image load gandalf-web:0.3
```

---

## 🟠 Manual Kubernetes Deployment (kubectl apply)
```sh
# Apply all manifests in k8s directory
kubectl apply -f k8s/

# Apply ServiceMonitor only
kubectl apply -f monitoring/gandalf-servicemonitor.yaml
```

---

## 🟣 Helm Workflow
```sh
# Install or upgrade Helm release
helm install gandalf ./gandalf-chart --namespace default --create-namespace
helm upgrade gandalf ./gandalf-chart --set image.tag=0.4

# Rollback Helm release
helm rollback gandalf 1
```

---

## 🔵 Application Management
```sh
# Patch deployment with new image
kubectl set image deploy/gandalf-web web=gandalf-web:0.3

# Check rollout status
kubectl rollout status deploy/gandalf-web

# Check resources by label
kubectl get all -l app.kubernetes.io/instance=gandalf -n default

# Check deployment image
kubectl get deploy gandalf-web -o yaml | grep image:
```

---

## 🟤 Service Access
```sh
# Get service info
kubectl get svc -n default
kubectl get svc gandalf-web -o wide

# Access service via minikube
minikube service gandalf-web --url
minikube service gandalf --url
minikube service monitoring-grafana -n monitoring --url

# Port-forward service
kubectl port-forward svc/gandalf-web 8080:80
kubectl port-forward svc/gandalf 8080:80 -n default
```

---

## 🟠 Prometheus & Monitoring
```sh
# Port-forward Prometheus UI
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090

# Check ServiceMonitor
kubectl get servicemonitor -n monitoring

# Delete ServiceMonitor (if needed)
kubectl delete servicemonitor gandalf-monitor -n monitoring
```

---

## 🟣 Grafana Dashboard
```sh
# Check for dashboard ConfigMap
kubectl get configmap -n monitoring | grep dashboard

# Check ConfigMap details
kubectl get configmap <dashboard-configmap-name> -n monitoring -o yaml
```

---

## ⚫ General Troubleshooting
```sh
# Check pod status
kubectl get pods -n default
kubectl get pods -n monitoring

# Delete a pod (to force restart)
kubectl delete pod <pod-name>
```

---

## 🟤 Other Useful Commands
```sh
# Expose a pod as a LoadBalancer Service (example)
kubectl run nginx --image=nginx:alpine --port=80
kubectl expose pod nginx --port=80 --type=LoadBalancer --name=nginx-lb --load-balancer-ip=192.168.49.241

# Verify the Service
kubectl get svc nginx-lb
```

checking logs
sudo tail -n 100 /var/log/cloud-init-output.log


---

## 📝 References
- Minikube static IP guide: https://minikube.sigs.k8s.io/docs/tutorials/static_ip/?utm_source
- MetalLB & Minikube tutorial: https://medium.com/@shoaib_masood/metallb-network-loadbalancer-minikube-335d846dfdbe
- Minikube port access on Windows: https://minikube.sigs.k8s.io/docs/handbook/accessing/#access-to-ports-1024-on-windows-requires-root-permission

---

**Tip:**
- Replace `<dashboard-configmap-name>` and `<pod-name>` with actual resource names as needed.
- Use `--namespace` or `-n` flag as appropriate for your resources.