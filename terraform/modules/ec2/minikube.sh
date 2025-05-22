#!/bin/bash

# This script install all prerequisite software needed for kops to create and manage k8s cluster
# Update and upgrade packages
sudo apt update -y && sudo apt upgrade -y

# Install docker
curl -fsSL https://get.docker.com | sudo bash

# Add the current user to the docker group
sudo usermod -aG docker $USER && newgrp docker

# Display success message
echo "Docker installation is complete. Log out and log back in for the group changes to take effect."

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl_version=$(kubectl version --client --short)
echo "kubectl installed: $kubectl_version"

# Install AWS CLI
echo "Installing AWS CLI..."
sudo apt install unzip -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws_version=$(aws --version)
echo "AWS CLI installed: $aws_version"

# Clean up
rm -f kubectl awscliv2.zip 
rm -rf aws

curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
sudo dpkg -i minikube_latest_amd64.deb

minikube start

## To portforward when using aws ec2
# kubectl port-forward --address 0.0.0.0 service/hello-minikube 7080:8080

# To start minikube from local environment
# minikube start --apiserver-ips=<EC2_PUBLIC_IP> --apiserver-name=<EC2_PUBLIC_DNS>

# 
minikube start --apiserver-ips=54.241.143.197 --apiserver-name=ec2-54-241-143-197.us-west-1.compute.amazonaws.com

minikube addons enable metrics-server