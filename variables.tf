variable "grafanacloud_metrics_url" {
  description = "URL for Grafana Cloud metrics endpoint"
  type        = string
  sensitive   = true
}

variable "grafanacloud_metrics_username" {
  description = "Username for Grafana Cloud metrics authentication"
  type        = string
  sensitive   = true
}

variable "grafanacloud_metrics_password" {
  description = "Password for Grafana Cloud metrics access"
  type        = string
  sensitive   = true
}

variable "grafanacloud_logs_url" {
  description = "URL for Grafana Cloud logs endpoint"
  type        = string
  sensitive   = true
}

variable "grafanacloud_logs_username" {
  description = "Username for Grafana Cloud logs authentication"
  type        = string
  sensitive   = true
}

variable "grafanacloud_logs_password" {
  description = "Password for Grafana Cloud logs access"
  type        = string
  sensitive   = true
}

variable "grafanacloud_fleet_management_url" {
  description = "URL for Grafana Cloud Fleet Management endpoint"
  type        = string
  sensitive   = true
}

variable "grafanacloud_fleet_management_username" {
  description = "Username for Grafana Cloud Fleet Management authentication"
  type        = string
  sensitive   = true
}

variable "grafanacloud_fleet_management_password" {
  description = "Password for Grafana Cloud Fleet Management access"
  type        = string
  sensitive   = true
} 