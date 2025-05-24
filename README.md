# Gandalf Web Server

A simple, modern web server built with **Python** and **Flask**. It features:
- Gandalf’s picture at `/gandalf`
- The current time in Colombo, Sri Lanka at `/colombo`
- Prometheus metrics at `/metrics`

It’s designed for secure, containerized deployment on Kubernetes (Minikube + MetalLB) and also runs as standalone Docker services (Gandalf, Prometheus, Grafana, Watchtower) on an EC2 VM via Terraform + cloud-init.

---

## Features

- **Homepage:** Gandalf’s picture  
- **Colombo Page:** Stylish display of current Colombo time  
- **Prometheus Metrics:**  
  - `/metrics` endpoint  
  - Counters: `gandalf_requests_total`, `colombo_requests_total`  
- **Kubernetes-ready:** Static IP + only port 80 open  
- **Containerized:** Non-root Docker image  
- **Infrastructure as Code:** Terraform modules for VPC & EC2  
- **Security:** Resource limits, probes, no secrets in repo  
- **CI/CD:** GitHub Actions for Docker Hub & Helm chart releases  

---

## Requirements

- Python 3.x + Flask, prometheus_client, pytz  
- Docker  
- Minikube  
- Helm  
- Terraform  
- AWS account (static EIP & EC2)  

---

## Local Kubernetes (Minikube + MetalLB)

### 1. Helm Prerequisite

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
````

### 2. Clone & Build

```bash
git clone <repo-url>
cd k8s-web-deployment
docker build -t gandalf-web:0.3 .
```

### 3. Minikube Setup

```bash
minikube start --driver=docker
minikube image load gandalf-web:0.3
```

### 4. Apply Manifests

```bash
kubectl apply -f k8s/
```

This covers Deployment, Service, ServiceMonitor, etc.

### 5. Access

* **Port-forward:**
  `kubectl port-forward svc/gandalf-web 8080:80` → [http://localhost:8080](http://localhost:8080)
* **NodePort:**
  `minikube service gandalf-web --url`
* **LoadBalancer (MetalLB):**
  `minikube tunnel` + `kubectl get svc gandalf-web`

---

## MetalLB Configuration

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-native.yaml
kubectl apply -f metallb-config.yaml
```

```yaml
# metallb-config.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: minikube-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.49.240-192.168.49.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2adv
  namespace: metallb-system
```

---

## Monitoring (Prometheus & Grafana)

### Install via Helm

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.service.type=NodePort \
  --set prometheus.prometheusSpec.maximumStartupDurationSeconds=120
```

### Access

* **Prometheus:**
  `kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090` → [http://localhost:9090](http://localhost:9090)
* **Grafana:**
  `minikube service monitoring-grafana -n monitoring --url` → login `admin/prom-operator`

### ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: gandalf-monitor
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames: ["default"]
  selector:
    matchLabels: {app: gandalf-web}
  endpoints:
    - port: http
      path: /metrics
      interval: 15s
```

```bash
kubectl apply -f k8s/gandalf-servicemonitor.yaml
```

---

## Generating & Visualizing Metrics

1. **Query in Prometheus UI**
   `gandalf_requests_total`
   `colombo_requests_total`

2. **Drive Traffic:**

   ```bash
   for i in {1..5}; do curl -s http://localhost:8080/gandalf; done
   for i in {1..3}; do curl -s http://localhost:8080/colombo; done
   ```

3. **Grafana Dashboard**
   Import **ID 1860** for API request rates.

4. **Alerting**

   * In Grafana panel → **Alert**
   * Expr: `sum(rate(colombo_requests_total[1m])) > 1`
   * Notify if sustained for 2m.

---

## VM-based Docker Deployment (Terraform + cloud-init)

### Terraform Modules

* **`modules/vpc/`**: VPC, subnets, IGW, NAT, SG
* **`modules/ec2/`**: EC2 instance with EIP, user-data script

### `root/main.tf`

```hcl
module "vpc" { … }
module "ec2" {
  source            = "./modules/ec2"
  subnet_id         = module.vpc.public_subnet_1_id
  vpc_id            = module.vpc.vpc_id
  security_group_id = module.vpc.security_group_id
  key_name          = var.key_name
  public_subnet_id  = module.vpc.public_subnet_1_id
  dockerhub_user    = var.dockerhub_user
  image_tag         = var.image_tag
  app_private_ip    = var.app_private_ip
  grafana_private_ip = var.grafana_private_ip
}
```

### Cloud-Init / User-Data

The EC2 boots and runs:

1. **Docker**
2. **Gandalf Web**
3. **Prometheus**
4. **Grafana**
5. **Watchtower**

*(See `/modules/ec2/minikube.sh` in repo for full script).*

### Outputs

Terraform will emit:

* `instance_public_ip`
* `gandalf_web_url = "http://${aws_eip.app.public_ip}/gandalf"`
* `prometheus_url  = "http://${aws_eip.app.public_ip}:9090"`
* `grafana_url     = "http://${aws_eip.app.public_ip}:3000"`

---

## CI/CD (GitHub Actions)

Triggers on tag push (`v*`):

```yaml
jobs:
  build-and-push:
    uses: docker/build-push-action@v5
    with:
      push: true
      tags: |
        docker.io/${{ secrets.DOCKERHUB_USERNAME }}/gandalf-web:${{ github.ref_name }}
        docker.io/${{ secrets.DOCKERHUB_USERNAME }}/gandalf-web:latest
  helm-package:
    run: |
      helm dependency update gandalf-chart
      helm package gandalf-chart --app-version ${{ github.ref_name }} --version ${{ github.ref_name }}
```

Use on-cluster:

```bash
helm upgrade --install gandalf ./gandalf-chart --set image.tag=v0.5
```

---

## Common Errors & Fixes

* **Minikube driver issues:** prefer `--driver=docker` over `none` unless expert setup
* **CNI plugins missing:** install `containernetworking-plugins` for `none` driver
* **ServiceMonitor not picked up:** ensure labels/namespaces match
* **Pod CrashLoop:** check logs & resource limits

---

![Dashboard Preview](image-1.png)

---

## References

* [MetalLB docs](https://metallb.universe.tf/)
* [Minikube load balancer tutorial](https://minikube.sigs.k8s.io/docs/tutorials/loadbalancer/)
* [Grafana alerting](https://grafana.com/docs/grafana/latest/alerting/)

---

## License

MIT

```

Let me know if you’d like any further tweaks or if I missed anything!
```
