# Create a deployment for the service
resource "kubernetes_deployment" "this" {
  count = false == var.daemon_set ? 1 : 0

  lifecycle {
    ignore_changes = [spec.0.replicas]
  }

  metadata {
    name      = var.name
    namespace = var.namespace_name
  }

  spec {
    selector {
      match_labels = {
        app = var.name
      }
    }

    template {
      metadata {
        annotations = {
          "sidecar.istio.io/inject" = false
          "prometheus.io/port"      = 8877
          "prometheus.io/scrape"    = true
          "prometheus.io/path"      = "/metrics"
        }

        labels = {
          terraform = "true",
          app       = var.name
        }
      }

      spec {
        service_account_name            = local.service_account_name
        automount_service_account_token = true
        restart_policy                  = "Always"

        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100

              pod_affinity_term {
                label_selector {
                  match_labels = {
                    "key" = var.name
                  }
                }

                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }
        
        container {
          name                     = var.name
          image                    = "${var.ambassador_image}:${var.ambassador_image_tag}"
          image_pull_policy        = var.image_pull_policy
          termination_message_path = "/dev/termination-log"

          resources {
            requests = {
              memory = var.resources_requests_memory
              cpu    = var.resources_requests_cpu
            }

            limits = {
              memory = var.resources_limits_memory
              cpu    = var.resources_limits_cpu
            }
          }

          env {
            name  = "AMBASSADOR_ID"
            value = var.ambassador_id
          }

          env {
            name  = "AMBASSADOR_DEBUG"
            value = var.ambassador_debug
          }

          env {
            name = "AMBASSADOR_NAMESPACE"

            value_from {
              field_ref {
                field_path = var.ambassador_namespace_name
              }
            }
          }

          dynamic "port" {
            for_each = var.loadbalance_service_target_ports
            content {
              name           = port.value.name
              container_port = port.value.container_port
              protocol       = "TCP"
            }
          }

          port {
            name           = "admin"
            container_port = 8877
            protocol       = "TCP"
          }

          liveness_probe {
            initial_delay_seconds = 3
            success_threshold     = 1
            timeout_seconds       = 1

            http_get {
              path   = "/ambassador/v0/check_alive"
              port   = 8877
              scheme = "HTTP"
            }
          }

          readiness_probe {
            initial_delay_seconds = 3
            success_threshold     = 1
            timeout_seconds       = 1

            http_get {
              path   = "/ambassador/v0/check_ready"
              port   = 8877
              scheme = "HTTP"
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.this,
    kubernetes_service_account.this,
  ]
}

