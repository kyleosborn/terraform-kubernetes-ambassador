resource "kubernetes_service" "this_loadbalancer" {
  count = var.loadbalancer_service_enable ? 1 : 0

  metadata {
    annotations = var.loadbalancer_service_annotations
    name        = var.name
    namespace   = var.namespace_name

    labels = {
      terrafrom = "true",
      app       = var.name
    }
  }

  spec {
    type = var.loadbalancer_service_type

    dynamic "port" {
      for_each = var.loadbalance_service_target_ports
      content {
        name        = port.value.name
        port        = port.value.port
        target_port = port.value.container_port
      }
    }

    selector = {
      app = var.name
    }

    session_affinity = "None"
    # external_traffic_policy = "Local"
  }

  depends_on = [kubernetes_namespace.this]
}

