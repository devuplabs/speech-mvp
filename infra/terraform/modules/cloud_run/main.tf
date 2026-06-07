terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.25.0, < 7.0.0"
    }
  }
}

locals {
  api_service_name    = "${var.name_prefix}-api-${var.environment}"
  worker_service_name = "${var.name_prefix}-worker-${var.environment}"
  web_service_name    = "${var.name_prefix}-web-${var.environment}"
}

resource "google_cloud_run_v2_service" "api" {
  name                = local.api_service_name
  location            = var.region
  project             = var.project_id
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = var.deletion_protection

  template {
    service_account = var.runtime_service_account_email

    scaling {
      min_instance_count = var.api_min_instances
      max_instance_count = var.api_max_instances
    }

    vpc_access {
      connector = var.vpc_connector_id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      name  = "api"
      image = var.api_image

      ports {
        container_port = 8080
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }
      env {
        name  = "JURISDICTION"
        value = var.jurisdiction
      }
      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "CLOUD_SQL_CONNECTION_NAME"
        value = var.cloud_sql_connection_name
      }
      env {
        name  = "DB_HOST"
        value = var.cloud_sql_private_ip
      }
      env {
        name  = "DB_NAME"
        value = var.cloud_sql_database
      }
      env {
        name  = "DB_USER"
        value = var.cloud_sql_app_user
      }
      env {
        name  = "LLM_CLOUD_TASKS_QUEUE"
        value = "${var.name_prefix}-llm-${var.environment}"
      }
      env {
        name  = "RUNTIME_SERVICE_ACCOUNT"
        value = var.runtime_service_account_email
      }
      env {
        name  = "SONA_MODE"
        value = "api"
      }
      env {
        name  = "INFERENCE_OPENAI_BASE_URL"
        value = var.inference_openai_base_url
      }
      env {
        name  = "GCP_REGION"
        value = var.region
      }
      env {
        name  = "WORKER_SERVICE_URL"
        value = google_cloud_run_v2_service.worker.uri
      }

      dynamic "env" {
        for_each = var.enable_web ? [1] : []
        content {
          name  = "CORS_ORIGINS"
          value = google_cloud_run_v2_service.web[0].uri
        }
      }

      # Public web origin used to build invite / intake links (Auth·05/16).
      dynamic "env" {
        for_each = var.enable_web ? [1] : []
        content {
          name  = "SONA_WEB_BASE_URL"
          value = google_cloud_run_v2_service.web[0].uri
        }
      }

      # Transactional email (Postmark) — only wired when configured.
      dynamic "env" {
        for_each = var.postmark_from_email != "" ? [1] : []
        content {
          name  = "POSTMARK_FROM_EMAIL"
          value = var.postmark_from_email
        }
      }

      dynamic "env" {
        for_each = var.postmark_token_secret_resource_id != "" ? [1] : []
        content {
          name = "POSTMARK_API_TOKEN"
          value_source {
            secret_key_ref {
              secret  = var.postmark_token_secret_resource_id
              version = "latest"
            }
          }
        }
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = var.db_password_secret_resource_id
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }
}

resource "google_cloud_run_v2_service" "worker" {
  name                = local.worker_service_name
  location            = var.region
  project             = var.project_id
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = var.deletion_protection

  template {
    service_account = var.runtime_service_account_email

    scaling {
      min_instance_count = var.worker_min_instances
      max_instance_count = var.worker_max_instances
    }

    vpc_access {
      connector = var.vpc_connector_id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      name  = "worker"
      image = var.api_image

      ports {
        container_port = 8080
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }
      env {
        name  = "JURISDICTION"
        value = var.jurisdiction
      }
      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "CLOUD_SQL_CONNECTION_NAME"
        value = var.cloud_sql_connection_name
      }
      env {
        name  = "DB_HOST"
        value = var.cloud_sql_private_ip
      }
      env {
        name  = "DB_NAME"
        value = var.cloud_sql_database
      }
      env {
        name  = "DB_USER"
        value = var.cloud_sql_app_user
      }
      env {
        name  = "SONA_MODE"
        value = "worker"
      }
      env {
        name  = "INFERENCE_OPENAI_BASE_URL"
        value = var.inference_openai_base_url
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = var.db_password_secret_resource_id
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }
}

# Flutter web (static nginx). No VPC/DB; image replaced by sona-web-dev-deploy after first apply.
resource "google_cloud_run_v2_service" "web" {
  count               = var.enable_web ? 1 : 0
  name                = local.web_service_name
  location            = var.region
  project             = var.project_id
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = var.deletion_protection

  template {
    scaling {
      min_instance_count = var.web_min_instances
      max_instance_count = var.web_max_instances
    }

    containers {
      name  = "web"
      image = var.web_image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version,
    ]
  }
}

resource "google_cloud_run_v2_service_iam_member" "api_public" {
  count    = var.allow_unauthenticated_api ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "web_public" {
  count    = var.enable_web && var.allow_unauthenticated_web ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.web[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Cloud Tasks → worker (OIDC as runtime SA).
resource "google_cloud_run_v2_service_iam_member" "worker_tasks_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.worker.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.runtime_service_account_email}"
}
