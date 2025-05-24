#!/usr/bin/env bash
set -euxo pipefail

###############################################################################
# 0.  Variables injected by Terraform
###############################################################################
TAG="${IMAGE_TAG}"
DH_USER="${DOCKERHUB_USERNAME}"
LB_POOL_START="${STATIC_POOL_START}"
LB_POOL_END="${STATIC_POOL_END}"
LB_IP_APP="${STATIC_APP_IP}"

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
su - "$OS_USER" -c 'minikube start --driver=docker --wait=true && minikube addons enable metrics-server'

###############################################################################
# 3.  Extra cluster configuration (MetalLB, Helm, monitoring, Gandalf)
###############################################################################
su - "$OS_USER" -c "
set -euxo pipefail

# ——— MetalLB ———
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-native.yaml

# 2. Wait until both deployments are available
kubectl -n metallb-system rollout status deploy/controller --timeout=180s

# wait until the webhook service actually has a ready pod behind it
until kubectl -n metallb-system get endpoints metallb-webhook-service -ojsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null | grep -qE '[0-9]'; do
  echo "Waiting for metallb-webhook-service endpoints…" ; sleep 2
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
EOSU

# ——— Helm + repos ———
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# ——— Monitoring stack ———
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.service.type=NodePort

# ——— Gandalf chart ———
helm upgrade --install gandalf /root/gandalf-chart \
  --namespace default --create-namespace \
  --set image.repository=docker.io/$${DH_USER}/gandalf-web \
  --set image.tag=$${TAG} \
  --set service.type=LoadBalancer \
  --set service.loadBalancerIP=$${LB_IP_APP}
"

echo "User-data bootstrap complete – cluster, monitoring and Gandalf are up."
