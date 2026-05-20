locals {
  model_mount_path = "/models"
  model_local_path = "${local.model_mount_path}/${var.model_gcs_prefix}"
  gcs_uri          = "gs://${var.models_bucket_name}/${var.model_gcs_prefix}"
}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.this.endpoint}"
  token                  = data.google_client_config.this.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.this.master_auth[0].cluster_ca_certificate)
}

resource "kubernetes_namespace" "vllm" {
  metadata {
    name = "vllm"
  }

  depends_on = [google_container_node_pool.gpu]
}

resource "kubernetes_service_account" "vllm" {
  metadata {
    name      = "vllm"
    namespace = kubernetes_namespace.vllm.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.gke_nodes.email
    }
  }
}

resource "google_service_account_iam_member" "vllm_workload_identity" {
  service_account_id = google_service_account.gke_nodes.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${kubernetes_namespace.vllm.metadata[0].name}/${kubernetes_service_account.vllm.metadata[0].name}]"
}

resource "kubernetes_deployment" "vllm" {
  metadata {
    name      = "vllm-gemma"
    namespace = kubernetes_namespace.vllm.metadata[0].name
    labels = {
      app = "vllm"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "vllm"
      }
    }

    template {
      metadata {
        labels = {
          app = "vllm"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.vllm.metadata[0].name

        init_container {
          name  = "sync-model"
          image = "gcr.io/google.com/cloudsdktool/google-cloud-cli:alpine"

          command = [
            "/bin/sh",
            "-c",
            "gcloud storage cp -r ${local.gcs_uri} ${local.model_mount_path}/",
          ]

          volume_mount {
            name       = "model-data"
            mount_path = local.model_mount_path
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "2"
              memory = "4Gi"
            }
          }
        }

        container {
          name  = "vllm"
          image = var.vllm_container_image

          args = [
            "--model", local.model_local_path,
            "--host", "0.0.0.0",
            "--port", tostring(var.vllm_service_port),
            "--tensor-parallel-size", "1",
          ]

          port {
            container_port = var.vllm_service_port
            name           = "http"
          }

          resources {
            limits = {
              "nvidia.com/gpu" = tostring(var.gpu_accelerator_count)
            }
            requests = {
              "nvidia.com/gpu" = tostring(var.gpu_accelerator_count)
              cpu              = "4"
              memory           = "24Gi"
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = var.vllm_service_port
            }
            initial_delay_seconds = 120
            period_seconds        = 15
            timeout_seconds       = 5
            failure_threshold     = 12
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = var.vllm_service_port
            }
            initial_delay_seconds = 300
            period_seconds        = 30
          }

          volume_mount {
            name       = "model-data"
            mount_path = local.model_mount_path
            read_only  = true
          }
        }

        volume {
          name = "model-data"
          empty_dir {
            size_limit = "80Gi"
          }
        }

        toleration {
          key      = "nvidia.com/gpu"
          operator = "Exists"
          effect   = "NoSchedule"
        }

        node_selector = {
          workload = "vllm"
        }
      }
    }
  }

  depends_on = [
    google_container_node_pool.gpu,
    google_service_account_iam_member.vllm_workload_identity,
  ]
}

resource "kubernetes_service" "vllm" {
  metadata {
    name      = "vllm"
    namespace = kubernetes_namespace.vllm.metadata[0].name
    annotations = {
      "networking.gke.io/load-balancer-type" = "Internal"
    }
    labels = {
      app = "vllm"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = "vllm"
    }

    port {
      name        = "http"
      port        = var.vllm_service_port
      target_port = var.vllm_service_port
      protocol    = "TCP"
    }
  }

  depends_on = [kubernetes_deployment.vllm]
}
