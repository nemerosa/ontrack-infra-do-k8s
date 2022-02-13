terraform {
  required_version = "~> 1.1.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.17.1"
    }
    helm = {
      version = "~> 2.4.1"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

#########################################################################################################
# The cluster VPC
#########################################################################################################

resource "digitalocean_vpc" "vpc" {
  name        = var.do_cluster_name
  region      = var.do_region
  description = "VPC for the ${var.do_cluster_name} K8S cluster"
}

#########################################################################################################
# The cluster
#########################################################################################################

data "digitalocean_kubernetes_versions" "version" {
  version_prefix = "1.21."
}

resource "digitalocean_kubernetes_cluster" "cluster" {
  name     = var.do_cluster_name
  region   = var.do_region
  vpc_uuid = digitalocean_vpc.vpc.id

  auto_upgrade = true
  version      = data.digitalocean_kubernetes_versions.version.latest_version

  maintenance_policy {
    start_time = "04:00"
    day        = "sunday"
  }

  node_pool {
    name       = "default"
    size       = var.do_cluster_default_size
    auto_scale = true
    min_nodes  = 1
    max_nodes  = var.do_cluster_default_count
  }
}

#########################################################################################################
# Setting up the Helm connection
#########################################################################################################

provider "helm" {
  kubernetes {
    host                   = digitalocean_kubernetes_cluster.cluster.endpoint
    token                  = digitalocean_kubernetes_cluster.cluster.kube_config[0].token
    cluster_ca_certificate = base64decode( digitalocean_kubernetes_cluster.cluster.kube_config[0].cluster_ca_certificate )
  }
}

#########################################################################################################
# Ingress controller
#########################################################################################################

locals {
  ingress_nginx_values = templatefile( "${path.module}/ingress_nginx_values.yaml", {
    lb_name = var.do_cluster_name,
  } )
}

resource "helm_release" "ingress-nginx" {
  name       = "nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"

  depends_on = [
    digitalocean_kubernetes_cluster.cluster,
  ]

  namespace        = "ingress-nginx"
  create_namespace = true

  # 20 minutes
  timeout = 1200

  # Values

  values = [
    local.ingress_nginx_values,
  ]

}

#########################################################################################################
# Cert manager
#########################################################################################################

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.2.0"

  depends_on = [
    digitalocean_kubernetes_cluster.cluster,
    helm_release.ingress-nginx,
  ]

  namespace        = "cert-manager"
  create_namespace = true

  # 10 minutes
  timeout = 600

  set {
    name  = "installCRDs"
    value = "true"
  }

}

#########################################################################################################
# Cert issuer
#########################################################################################################

resource "helm_release" "cert_issuer" {
  name  = "cert-issuer"
  chart = "${path.module}/charts/production_issuer"

  depends_on = [
    digitalocean_kubernetes_cluster.cluster,
    helm_release.ingress-nginx,
    helm_release.cert_manager,
  ]

  namespace = "cert-manager"

  # 10 minutes
  timeout = 600

  # Email

  set {
    name  = "acme.email"
    value = var.do_acme_email
  }

  # Using the staging ACME server for now

  set {
    name  = "acme.server"
    value = var.do_acme_server
  }

}

#########################################################################################################
# Advanced metrics
#########################################################################################################

resource "helm_release" "kube-state-metrics" {
  count      = var.do_kube_metrics ? 1 : 0
  name       = "kube-state-metrics"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-state-metrics"
  version    = "4.5.0"

  depends_on = [
    digitalocean_kubernetes_cluster.cluster,
  ]

  # 10 minutes
  timeout = 600

}
