terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "docker" {
  host = "npipe:////./pipe/docker_engine"  # Windows Docker Desktop
  # host = "unix:///var/run/docker.sock"  # Linux/Mac
}

# Single network definition (removed duplicate)
resource "docker_network" "app_network" {
  name = "app-network"
  attachable = true
}

# PostgreSQL Database
resource "docker_image" "postgres" {
  name = "postgres:14"
}

resource "docker_container" "postgres_db" {
  name  = "pg-db"
  image = docker_image.postgres.name
  networks_advanced {
    name = docker_network.app_network.name
  }

  env = [
    "POSTGRES_USER=admin",
    "POSTGRES_PASSWORD=admin",
    "POSTGRES_DB=mydb",
    "POSTGRES_HOST_AUTH_METHOD=trust"  # For development only
  ]

  ports {
    internal = 5432
    external = 5432
  }

  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U admin -d mydb"]
    interval = "5s"
    timeout  = "5s"
    retries  = 10
  }
}

# Python Application
resource "docker_image" "python_app" {
  name = "python-app"
  build {
    context    = "${path.module}/app"
    dockerfile = "Dockerfile"
    # Force rebuild when files change
    build_args = {
      BUILD_DATE = timestamp()
    }
  }
}

resource "docker_container" "python_service" {
  name     = "python-service"
  image    = docker_image.python_app.image_id
  restart  = "unless-stopped"
  networks_advanced {
    name = docker_network.app_network.name
  }

  env = [
    "DATABASE_URL=postgres://admin:admin@pg-db:5432/mydb",
    "PYTHONUNBUFFERED=1"
  ]

  working_dir = "/app"

  # Wait for DB to be ready before starting
  depends_on = [
    docker_container.postgres_db
  ]

  # Better command handling
  command = ["python wait-for-postgres.py"]

  # Enable if you need to mount code for development
  # volumes {
  #   host_path      = abspath("${path.module}/app")
  #   container_path = "/app"
  # }
}