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
  region = "us-east-2"  # Change this to your preferred region
}

# Create SSH key pair
resource "tls_private_key" "swarm_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "swarm_key_pair" {
  key_name   = "swarm-key-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  public_key = tls_private_key.swarm_key.public_key_openssh

  # Save private key using provisioner
  provisioner "local-exec" {
    command = "echo '${tls_private_key.swarm_key.private_key_pem}' > ./swarm-key.pem && chmod 400 ./swarm-key.pem"
  }
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
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
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
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
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

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y apt-transport-https ca-certificates curl software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
              add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              apt-get update
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
              
              # Start Docker registry
              docker run -d -p 5000:5000 --restart=always --name registry registry:2
              
              # Initialize Docker Swarm
              PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
              PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
              docker swarm init --advertise-addr $PRIVATE_IP
              
              # Create the application stack
              cat > docker-compose.yml << 'EOL'
              version: '3.8'
              services:
                postgres:
                  image: postgres:17.0
                  environment:
                    - POSTGRES_PASSWORD=petclinic
                    - POSTGRES_USER=petclinic
                    - POSTGRES_DB=petclinic
                  networks:
                    - petclinic-network
                  deploy:
                    replicas: 1
                    placement:
                      constraints: [node.role == manager]

                petclinic:
                  image: localhost:5000/petclinic:latest
                  ports:
                    - "8080:8080"
                  environment:
                    - SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/petclinic
                    - SPRING_DATASOURCE_USERNAME=petclinic
                    - SPRING_DATASOURCE_PASSWORD=petclinic
                    - SPRING_DATASOURCE_DRIVER-CLASS-NAME=org.postgresql.Driver
                    - SPRING_PROFILES_ACTIVE=postgres
                  networks:
                    - petclinic-network
                  depends_on:
                    - postgres
                  deploy:
                    replicas: 2
                    placement:
                      constraints: [node.role == worker]

              networks:
                petclinic-network:
                  driver: overlay
              EOL
              
              # Clone and build the application
              git clone https://github.com/spring-projects/spring-petclinic.git /tmp/petclinic
              cd /tmp/petclinic

              # Create Dockerfile if it doesn't exist
              cat > Dockerfile << 'EOL'
              FROM eclipse-temurin:17-jdk-jammy
              WORKDIR /app
              COPY .mvn/ .mvn
              COPY mvnw pom.xml ./
              RUN ./mvnw dependency:go-offline
              COPY src ./src
              RUN ./mvnw package -DskipTests
              CMD ["java", "-jar", "target/*.jar"]
              EOL

              # Build and push the image
              docker build -t localhost:5000/petclinic:latest .
              docker push localhost:5000/petclinic:latest
              
              # Deploy the stack
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