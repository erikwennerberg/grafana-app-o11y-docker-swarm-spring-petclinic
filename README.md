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

## Building the Petclinic Docker Image

The Petclinic image comes bundled with the Grafana OTEL java agent. To get the agent to send telemetry to your Grafana cloud instance, the image needs to be rebuilt with the right arguments as per the below. Those prameters will be generated on your org profile (https://grafana.com/orgs/<yourorg>/stacks/<orgid>/otlp-info) when you generate a new token for an OTLP endpoint.
docker build \
  --build-arg OTLP_PROTOCOL="<OTLP protocol>" \
  --build-arg OTLP_ENDPOINT="<Your Grafana Cloud OTLP Endpoint>" \
  --build-arg OTLP_HEADERS="<Your Grafana Cloud OTLP Auth header>" \
  -t spring-petclinic:latest .

  To use the docker image you built, don't forget to publish it to a repository and reference it in the docker compose file for the petclinic service.

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
