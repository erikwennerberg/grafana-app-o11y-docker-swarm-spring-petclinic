# PetClinic Application on Docker Swarm with Grafana Monitoring

This is a fork of the Spring Boot petclinic app pre-monitored with Grafana Alloy for Grafana Cloud. 
This projects has:
- a terraform that will spin up an EC2 instance with Docker Swarm on it, the petclinic app with postgres, and Grafana Alloy for monitoring
- a docker compose file that will deploy this setup on your local
- the petclinic source code + Dockerfile to build a petclinic image with logback + the Grafana Loki appender

## Prerequisites

The following items should be installed in your system:

- Terraform
- Docker
- AWS CLI
- A JDK if you want to re-build/change the petclinic app


## Run Petclinic locally

Run docker compose up

## Run Petclinic on AWS

1. Set the following terraform variables before or during the terraforming:
   TF_VAR_grafanacloud_metrics_url
   TF_VAR_grafanacloud_metrics_username
   TF_VAR_grafanacloud_metrics_password
   TF_VAR_grafanacloud_logs_url
   TF_VAR_grafanacloud_logs_username
   TF_VAR_grafanacloud_logs_password
   TF_VAR_grafanacloud_fleet_management_url
   TF_VAR_grafanacloud_fleet_management_username
   TF_VAR_grafanacloud_fleet_management_password

   You can get the values of these on your grafana.com account for Loki and Prometheus, and for the rest it will be in the fleet management section of Grafana.

2. terraform plan
3. terraform apply


## Understanding the Spring Petclinic application with a few diagrams

[See the presentation here](https://speakerdeck.com/michaelisvy/spring-petclinic-sample-application)
