terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
  }
}

provider "aws" {
  region  = "us-east-2"  # Change this to your preferred region
}

# Create SSH key pair
resource "tls_private_key" "swarm_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "swarm_key_pair" {
  key_name   = "swarm-key-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  public_key = tls_private_key.swarm_key.public_key_openssh
}

# Save private key to file
resource "local_file" "private_key" {
  content         = tls_private_key.swarm_key.private_key_pem
  filename        = "swarm-key.pem"
  file_permission = "0400"
}

# Security group for the EC2 instance
resource "aws_security_group" "swarm_sg" {
  name        = "swarm-security-group"
  description = "Security group for Docker Swarm"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Add Alloy port
  ingress {
    from_port   = 12345
    to_port     = 12345
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# EC2 instance for Docker Swarm
resource "aws_instance" "swarm_manager" {
  ami           = "ami-0376da4f943e28a68"  # Ubuntu 22.04 LTS
  instance_type = "t2.medium"
  key_name      = aws_key_pair.swarm_key_pair.key_name

  security_groups = [aws_security_group.swarm_sg.name]

  # Copy docker-compose.yml to the server
  provisioner "file" {
    source      = "docker-compose.yml"
    destination = "/tmp/docker-compose.yml"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.swarm_key.private_key_pem
      host        = self.public_ip
    }
  }

  # Copy Alloy configuration to the server
  provisioner "file" {
    source      = "config.alloy"
    destination = "/tmp/config.alloy"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.swarm_key.private_key_pem
      host        = self.public_ip
    }
  }

  user_data = <<-EOF
#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Configure Docker daemon for metrics and experimental features
cat > /etc/docker/daemon.json << 'EOL'
{
  "metrics-addr" : "0.0.0.0:9323",
  "experimental" : true
}
EOL

# Restart Docker to apply the new configuration
systemctl restart docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Copy docker-compose.yml and Alloy config to the final location
cp /tmp/docker-compose.yml /home/ubuntu/docker-compose.yml

# Create Alloy configuration directory and copy config
sudo mkdir -p /etc/alloy
cp /tmp/config.alloy /etc/alloy/config.alloy

# Set proper permissions for Alloy config
sudo chown -R root:root /etc/alloy

# Set Grafana Cloud environment variables
cat > /etc/environment << EOL
GRAFANACLOUD_METRICS_URL="${var.grafanacloud_metrics_url}"
GRAFANACLOUD_METRICS_USERNAME="${var.grafanacloud_metrics_username}"
GRAFANACLOUD_METRICS_PASSWORD="${var.grafanacloud_metrics_password}"
GRAFANACLOUD_LOGS_URL="${var.grafanacloud_logs_url}"
GRAFANACLOUD_LOGS_USERNAME="${var.grafanacloud_logs_username}"
GRAFANACLOUD_LOGS_PASSWORD="${var.grafanacloud_logs_password}"
GRAFANACLOUD_FLEET_MANAGEMENT_URL="${var.grafanacloud_fleet_management_url}"
GRAFANACLOUD_FLEET_MANAGEMENT_USERNAME="${var.grafanacloud_fleet_management_username}"
GRAFANACLOUD_FLEET_MANAGEMENT_PASSWORD="${var.grafanacloud_fleet_management_password}"
OTEL_EXPORTER_OTLP_PROTOCOL="${var.otel_exporter_otlp_protocol}"
OTEL_EXPORTER_OTLP_ENDPOINT="${var.otel_exporter_otlp_endpoint}"
OTEL_EXPORTER_OTLP_HEADERS="${var.otel_exporter_otlp_headers}"
EOL

# Source the environment variables
set -a
source /etc/environment
set +a

# Create a systemd service override to ensure Docker daemon has access to environment variables
mkdir -p /etc/systemd/system/docker.service.d/
cat > /etc/systemd/system/docker.service.d/override.conf << EOL
[Service]
EnvironmentFile=/etc/environment
EOL

# Reload systemd and restart Docker to apply the environment variables
systemctl daemon-reload
systemctl restart docker

# Initialize Docker Swarm
docker swarm init

# Deploy the stack
cd /home/ubuntu
docker stack deploy -c docker-compose.yml petclinic
EOF

  tags = {
    Name = "Docker Swarm Manager"
  }
}

# Output the public IP of the instance
output "swarm_manager_public_ip" {
  value = aws_instance.swarm_manager.public_ip
}

# Output the application URL
output "application_url" {
  value = "http://${aws_instance.swarm_manager.public_ip}:8080"
}

# Output the Swarm join token for workers
output "swarm_join_token" {
  value = "Run this command on worker nodes: docker swarm join --token $(docker swarm join-token worker -q) ${aws_instance.swarm_manager.private_ip}:2377"
}

# Output SSH connection information
output "ssh_connection" {
  value = "ssh -i swarm-key.pem ubuntu@${aws_instance.swarm_manager.public_ip}"
} 