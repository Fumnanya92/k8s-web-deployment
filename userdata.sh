#!/usr/bin/env bash
set -euxo pipefail


TAG="v0.6"
DH_USER="${DOCKERHUB_USERNAME}"
WEB_PORT=80
PROM_PORT=9090

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


if docker pull docker.io/$${DH_USER}/gandalf-web:$${TAG}; then
  IMAGE_TAG="$${TAG}"
else
  echo "Tag $${TAG} not found, falling back to latest"
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

###############################################################################
# 3.x  Run Grafana on port 3000
###############################################################################
# 3.x.a  Provision Prometheus DS
mkdir -p /opt/grafana/provisioning/datasources
cat >/opt/grafana/provisioning/datasources/prometheus.yml <<EOF
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    version: 1
    editable: false
EOF

# 3.x.b  Launch Grafana
docker pull grafana/grafana:latest
docker run -d \
  --name grafana \
  --restart unless-stopped \
  -p 3000:3000 \
  -v /opt/grafana/provisioning/datasources:/etc/grafana/provisioning/datasources \
  -e GF_SECURITY_ADMIN_PASSWORD="prom-operator" \
  grafana/grafana:latest

echo "Grafana is running on http://<VM_IP>:3000  (admin/prom-operator)"

# 3.x.c  Update Watchtower to monitor grafana too
docker rm -f watchtower 2>/dev/null || true
docker pull containrrr/watchtower:latest
docker run -d \
  --name watchtower \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower:latest \
  --interval 300 \
  gandalf-web prometheus grafana

echo "Watchtower is monitoring gandalf-web, prometheus & grafana"


echo "Bootstrap complete!"
echo "Services started!"
echo "→ Gandalf Web: http://$(curl -s ifconfig.me)/gandalf"
echo "→ Colombo Time: http://$(curl -s ifconfig.me)/colombo"
echo "→ Prometheus : http://$(curl -s ifconfig.me):$${PROM_PORT}"
