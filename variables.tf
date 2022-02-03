# Required variables

variable "do_token" {
  type        = string
  sensitive   = true
  description = "Digital Ocean connection token"
}

variable "do_region" {
  type        = string
  description = "Digital Ocean region where to create all the resources (example: ams3)"
}

variable "do_cluster_name" {
  type        = string
  description = "Name of the K8S cluster"
}

variable "do_acme_email" {
  type        = string
  description = "Email of the Certificate Issuer"
}

# Options

variable "do_cluster_default_size" {
  type        = string
  description = "Size of the nodes in the default pool"
  default     = "s-2vcpu-4gb"
}

variable "do_cluster_default_count" {
  type        = number
  description = "Maximum number of the nodes in the default pool"
  default     = 3
}

variable "do_acme_server" {
  type        = string
  description = "URL to the ACME server, defaults to production."
  default     = "https://acme-v02.api.letsencrypt.org/directory"
  // For ACME staging, use https://acme-staging-v02.api.letsencrypt.org/directory
}

