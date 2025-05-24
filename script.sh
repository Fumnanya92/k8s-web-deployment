#!/usr/bin/env bash
set -euxo pipefail

###############################################################################
# 0.  Manual-test variables                                                   
###############################################################################
TAG="v0.8"                   # Gandalf image tag
DH_USER="fumnanya92"         # DockerHub user
IP_POOL_START="10.0.1.241"   # MetalLB pool start
IP_POOL_END="10.0.1.242"     # MetalLB pool end
APP_LB_IP="10.0.1.241"       # Gandalf Service LoadBalancer IP
OS_USER="ubuntu"
###############################################################################

###############################################################################
# 1.  System & Docker (unchanged)                                             
###############################################################################
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
# 2.  kubectl + Minikube (unchanged)                                          
###############################################################################
echo "Installing kubectl…"
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
kubectl version --client

echo "Installing Minikube…"
curl -Lo minikube.deb https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
dpkg -i minikube.deb
rm minikube.deb

su - "$OS_USER" -c 'sudo minikube start --driver=none --kubernetes-version=v1.32.0 --wait=true && sudo minikube addons enable metrics-server'

###############################################################################
# 3.  MetalLB                                                               
###############################################################################
su - "$OS_USER" -s /bin/bash <<EOM
set -euxo pipefail

# 3.a Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-native.yaml

# 3.b Wait for controller (includes webhook)
kubectl -n metallb-system rollout status deploy/controller --timeout=180s

# 3.c Wait for the webhook service endpoints
until kubectl -n metallb-system get endpoints metallb-webhook-service \
    -o jsonpath='{.subsets[0].addresses[0].ip}' >/dev/null 2>&1; do
  echo "Waiting for MetalLB webhook endpoint…"
  sleep 2
done

# 3.d Apply pool & advertisement
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: minikube-pool
  namespace: metallb-system
spec:
  addresses:
    - "${IP_POOL_START}-${IP_POOL_END}"
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2adv
  namespace: metallb-system
EOF

echo "MetalLB pool ${IP_POOL_START}-${IP_POOL_END} applied."
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

# 4.c Deploy kube-prometheus-stack
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.service.type=NodePort \
  --set prometheus.prometheusSpec.maximumStartupDurationSeconds=120

# 4.d Deploy Gandalf chart
helm upgrade --install gandalf ~/k8s-web-deployment/gandalf-chart \
  --namespace default --create-namespace \
  --set image.repository=docker.io/${DH_USER}/gandalf-web \
  --set image.tag=${TAG} \
  --set service.type=LoadBalancer \
  --set service.loadBalancerIP=${APP_LB_IP}

echo "Helm releases deployed: monitoring & gandalf"
EOF

echo
echo "🎉 Bootstrap complete!"
echo "Run in a new SSH session:"
echo "  docker ps"
echo "  minikube status"
echo "  kubectl get svc gandalf -o wide"
echo "Gandalf is at http://${APP_LB_IP} and Grafana at http://${APP_LB_IP}:31000"
