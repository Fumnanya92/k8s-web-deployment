# Get the latest Ubuntu 22.04 LTS AMI dynamically
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Generate SSH Key Pair for EC2
resource "tls_private_key" "k8s" {
    algorithm = "RSA"
      rsa_bits  = 2048
}

resource "aws_key_pair" "k8s" {
    key_name   = var.key_name  # Use variable instead of hardcoded name
    public_key = tls_private_key.k8s.public_key_openssh
}

# Save the private key locally
resource "local_file" "techkey" {
    content  = tls_private_key.k8s.private_key_pem
    filename = "${var.key_name}.pem"  # Save the private key with dynamic filename
}


resource "aws_eip" "k8s_eip" {
    domain = "vpc"  # Specifies that this is for use in a VPC
}


# EC2 Instance Configuration
resource "aws_instance" "k8s_instance" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.k8s.key_name
  vpc_security_group_ids      = [var.security_group_id]
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/minikube.sh", {})

  tags = {
    Name = "k8s-instance"
  }
}

# Associate Elastic IP with the instance (optional for dedicated IP)
resource "aws_eip_association" "k8s_eip_association" {
    instance_id   = aws_instance.k8s_instance.id
      allocation_id = aws_eip.k8s_eip.id
}
