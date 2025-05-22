# Gandalf Web Server

This project is a simple web server application built using **Python** and **Flask**. It provides a visually pleasing, modern homepage that displays Gandalf's picture and the current time in Colombo, Sri Lanka. The app also exposes Prometheus metrics for observability.

## Features

- **Homepage:** Shows Gandalf's picture and the current time in Colombo, Sri Lanka, on a single, centered, and aesthetically pleasing page.
- **Prometheus Metrics:** 
  - Total number of requests to the homepage (`/`), which includes Gandalf's picture and Colombo time.
- **Runs on a static IP** with only port 80 open.
- **Containerized with Docker** and deployed to Minikube.
- **Infrastructure provisioned using Terraform.**
- **Security best practices:** Minimal image, non-root user, only required ports open.

## Requirements

- Python 3.x
- Flask
- prometheus_client
- pytz
- Docker (for containerization)
- Minikube (for local Kubernetes deployment)
- Terraform (for infrastructure provisioning)
- Access to a cloud provider (for static IP and VM provisioning)

## Setup Instructions

### 1. Clone the Repository
```bash
git clone <repository-url>
cd k8s-web-deployment
```

### 2. Provision Infrastructure with Terraform
```bash
cd terraform
terraform init
terraform validate
terraform apply -auto-approve
```

### 3. Install the Required Python Packages
```bash
pip install -r requirements.txt
```

### 4. Build the Docker Image
```bash
docker build -t gandalf-web-server .
```

### 5. Install Minikube
SSH into your provisioned EC2 instance and run:
```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
minikube start --driver=docker
```

### 6. Deploy to Minikube
```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

### 7. Access the Application
Use Minikube's service tunneling to access the application:
```bash
minikube service <service-name>
```
- The homepage (`/`) displays Gandalf's picture and Colombo time, both centered and styled.
- Prometheus metrics are available at `/metrics`.

## Metrics

- Prometheus scrapes metrics from the `/metrics` endpoint.
- Metrics exported:
  - `gandalf_requests_total`: Total number of requests to the homepage (includes Gandalf's picture).
  - `colombo_requests_total`: Total number of requests to the homepage (includes Colombo time).
- See `k8s/prometheus-config.yaml` for an example Prometheus configuration.

## Prometheus Deployment

1. **Provision a VM** in your cloud provider (e.g., AWS EC2, GCP Compute Engine).
2. **Install Prometheus** on the VM (manual or automated via Ansible/Terraform).
3. **Configure Prometheus** to scrape your application's `/metrics` endpoint.
4. **Secure Prometheus** (firewall, authentication, etc.).

## Security & Best Practices

- Only port 80 is exposed via the Kubernetes Service.
- Docker image uses a non-root user and minimal base image.
- No sensitive data is stored in the repository.
- Kubernetes manifests use resource limits and readiness/liveness probes.

## Automation

- Infrastructure and deployment are automated using Terraform.
- All configuration files are version-controlled.

## License

This project is licensed under the MIT License.