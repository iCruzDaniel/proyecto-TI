# main.tf - Configuración principal de Terraform

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

# Configurar el proveedor de DigitalOcean
provider "digitalocean" {
  token = var.do_token
  spaces_access_id  = var.access_id
  spaces_secret_key = var.secret_key
}

# Variables
variable "do_token" {
  description = "Token de API de DigitalOcean"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Nombre de la clave SSH en DigitalOcean"
  type        = string
  default     = "mi-clave-ssh"
}

variable "docker_api1_image" {
  description = "Imagen Docker de la API 1"
  type        = string
  default     = "tu-usuario/api1:latest"
}

variable "docker_api2_image" {
  description = "Imagen Docker de la API 2"
  type        = string
  default     = "tu-usuario/api2:latest"
}

variable "app_docker_image" {
  description = "Imagen Docker de la App"
  type        = string
  default     = "tu-usuario/app:latest"
}

# Crear VPC (Red Privada Virtual)
resource "digitalocean_vpc" "main" {
  name     = "vpc-main"
  region   = "nyc3"
  ip_range = "10.10.0.0/16"
}

# Base de datos MySQL
resource "digitalocean_database_cluster" "mysql" {
  name       = "mysql-cluster"
  engine     = "mysql"
  version    = "8"
  size       = "db-s-1vcpu-1gb"
  region     = "nyc3"
  node_count = 1

  private_network_uuid = digitalocean_vpc.main.id
}

# Bucket para almacenamiento multimedia
resource "digitalocean_spaces_bucket" "media" {
  name   = "mi-bucket-media-${random_string.bucket_suffix.result}"
  region = "nyc3"
  acl    = "private"
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Droplets para las APIs (mínimo 2 como solicitas)
resource "digitalocean_droplet" "api_servers" {
  count  = 2
  image  = "ubuntu-22-04-x64"
  name   = "api-server-${count.index + 1}"
  region = "nyc3"
  size   = "s-1vcpu-1gb"
  
  vpc_uuid = digitalocean_vpc.main.id
  ssh_keys = [data.digitalocean_ssh_key.main.id]

  tags = ["api-server"]

  # Script de inicialización básico
  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y python3 python3-pip
    pip3 install ansible
  EOF
}

# Obtener la clave SSH existente
data "digitalocean_ssh_key" "main" {
  name = var.ssh_key_name
}

# Load Balancer
resource "digitalocean_loadbalancer" "api_lb" {
  name   = "api-load-balancer"
  region = "nyc3"
  vpc_uuid = digitalocean_vpc.main.id

  forwarding_rule {
    entry_protocol  = "http"
    entry_port      = 80
    target_protocol = "http"
    target_port     = 80
  }

  healthcheck {
    protocol = "http"
    port     = 80
    path     = "/health"
  }

  droplet_ids = digitalocean_droplet.api_servers[*].id
}

# App Platform (tu aplicación principal)
resource "digitalocean_app" "main_app" {
  spec {
    name   = "mi-aplicacion"
    region = "nyc3"

    service {
      name               = "web"
      instance_count     = 1
      instance_size_slug = "basic-xxs"

      image {
        registry_type = "DOCKER_HUB"
        registry      = "tu-usuario"
        repository    = "app"
        tag           = "latest"
      }

      http_port = 8080

      # Variables de entorno para conectar con el load balancer
      env {
        key   = "API_BASE_URL"
        value = "http://${digitalocean_loadbalancer.api_lb.ip}"
      }

      env {
        key   = "DATABASE_URL"
        value = digitalocean_database_cluster.mysql.uri
        type  = "SECRET"
      }
    }
  }
}

# Outputs para referencias importantes
output "load_balancer_ip" {
  description = "IP del Load Balancer"
  value       = digitalocean_loadbalancer.api_lb.ip
}

output "app_url" {
  description = "URL de la aplicación"
  value       = digitalocean_app.main_app.live_url
}

output "database_connection" {
  description = "Cadena de conexión de la base de datos"
  value       = digitalocean_database_cluster.mysql.uri
  sensitive   = true
}

output "bucket_name" {
  description = "Nombre del bucket"
  value       = digitalocean_spaces_bucket.media.name
}

output "droplet_ips" {
  description = "IPs de los droplets"
  value = {
    for i, droplet in digitalocean_droplet.api_servers :
    "api-server-${i + 1}" => {
      public_ip  = droplet.ipv4_address
      private_ip = droplet.ipv4_address_private
    }
  }
}