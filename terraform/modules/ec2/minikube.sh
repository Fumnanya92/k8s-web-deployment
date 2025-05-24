#!/usr/bin/env bash
set -euxo pipefail

###############################################################################
# 0.  Variables injected by Terraform
###############################################################################
TAG="v0.6"
DH_USER="${DOCKERHUB_USERNAME}"
LB_POOL_START="${STATIC_POOL_START}"
LB_POOL_END="${STATIC_POOL_END}"
LB_IP_APP="${STATIC_APP_IP}"
WEB_PORT=80
PROM_PORT=9090

###############################################################################
# 1.  System & Docker  (UNCHANGED from your working script)
###############################################################################
OS_USER="ubuntu"

apt-get update -y
apt-get upgrade -y
apt-get install -y ca-certificates curl gnupg lsb-release

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
     -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io \
                   docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker
usermod -aG docker "$OS_USER"

###############################################################################
# 2.  Run Gandalf Web on port 80
###############################################################################
if docker pull docker.io/$${DH_USER}/gandalf-web:$${TAG}; then
  IMAGE_TAG="$${TAG}"
else
  echo "⚠️  Tag $${TAG} not found, falling back to latest"
  docker pull docker.io/$${DH_USER}/gandalf-web:latest
  IMAGE_TAG="latest"
fi

# Always remove old container first
docker rm -f gandalf-web 2>/dev/null || true

# Start container
docker run -d \
  --name gandalf-web \
  --restart unless-stopped \
  -p $${WEB_PORT}:80 \
  docker.io/$${DH_USER}/gandalf-web:$${TAG}

###############################################################################
# 3.  Run Prometheus on port 9090
###############################################################################
mkdir -p /opt/prometheus
cat >/opt/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'gandalf-web'
    static_configs:
      - targets: ['localhost:$${WEB_PORT}']
EOF

docker pull prom/prometheus:latest
docker run -d \
  --name prometheus \
  --restart unless-stopped \
  --network host \
  -v /opt/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus:latest

docker rm -f watchtower 2>/dev/null || true
docker pull containrrr/watchtower:latest

docker run -d \
  --name watchtower \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower:latest \
  --interval 300 \
  gandalf-web prometheus

echo "✅ Watchtower is monitoring gandalf-web & prometheus"


###############################################################################
# 4.  Done
###############################################################################
echo "🎉 Services started!"
echo "→ Gandalf Web: http://$(curl -s ifconfig.me)/gandalf"
echo "→ Colombo Time: http://$(curl -s ifconfig.me)/colombo"
echo "→ Prometheus : http://$(curl -s ifconfig.me):$${PROM_PORT}"

###############################################################################
# 2.  kubectl + Minikube  (UNCHANGED logic, just inlined here)
###############################################################################
echo "Installing kubectl…"
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
kubectl version --client -o yaml | grep gitVersion

curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
dpkg -i minikube_latest_amd64.deb
rm minikube_latest_amd64.deb

# start cluster exactly the way that works for you
su - "$OS_USER" -c 'sudo minikube start --driver=docker --kubernetes-version=v1.32.0 --wait=true && sudo minikube addons enable metrics-server'

###############################################################################
# 3.  Extra cluster configuration (MetalLB, Helm, monitoring, Gandalf)
###############################################################################
su - "$OS_USER" -s /bin/bash <<EOM
set -euxo pipefail

# ——— MetalLB ———
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-native.yaml

# 2. Wait until both deployments are available
kubectl -n metallb-system rollout status deploy/controller --timeout=180s

# 3.c Wait for the webhook service endpoints
until kubectl -n metallb-system get endpoints metallb-webhook-service \
    -o jsonpath='{.subsets[0].addresses[0].ip}' >/dev/null 2>&1; do
  echo "Waiting for MetalLB webhook endpoint…"
  sleep 2
done
echo "Webhook is ready."


cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: minikube-pool
  namespace: metallb-system
spec:
  addresses:
  - $${LB_POOL_START}-$${LB_POOL_END}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2adv
  namespace: metallb-system
EOF

echo "MetalLB pool applied."
EOM

###############################################################################
# 3.e  Clone your repo so the chart is present
###############################################################################
echo "Ensuring Git repo for the Gandalf chart is up to date…"
apt-get install -y git
su - "$OS_USER" -c '
  if [ -d ~/k8s-web-deployment ]; then
    cd ~/k8s-web-deployment
    git pull --ff-only
  else
    git clone https://github.com/Fumnanya92/k8s-web-deployment.git ~/k8s-web-deployment
  fi
'

###############################################################################
# 4.  Helm, Prometheus stack & Gandalf chart                                  
###############################################################################
su - "$OS_USER" -s /bin/bash <<EOF
set -euxo pipefail

# 4.a Install Helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 4.b Add repos & update
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# ——— Monitoring stack ———
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.service.type=NodePort \
  --set prometheus.prometheusSpec.maximumStartupDurationSeconds=120

# ——— Gandalf chart ———
helm upgrade --install gandalf ~/k8s-web-deployment/gandalf-chart \
  --namespace default --create-namespace \
  --set image.repository=docker.io/$${DH_USER}/gandalf-web \
  --set image.tag=$${TAG} \
  --set service.type=LoadBalancer \
  --set service.loadBalancerIP=$${LB_IP_APP}


echo "User-data bootstrap complete – cluster, monitoring and Gandalf are up."
EOF

echo
echo "🎉 Bootstrap complete!"
echo "Run in a new SSH session:"
echo "  docker ps"
echo "  minikube status"
echo "  kubectl get svc gandalf -o wide"
