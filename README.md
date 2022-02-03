Ontrack Infra DO K8S
====================

Definition of a Kubernetes cluster in Digital Ocean with an Ingress controller.

# Usage

Clone this repository and create a `terraform.tfvars` file at the root of the working copy with the following values:

```hcl
# Digital Ocean token with read/write authorizations
# Create one by going to https://cloud.digitalocean.com/account/api/tokens
do_token        = "..."
# The Digital Ocean region where to install the cluster. For example:
do_region       = "fra1"
# The email used to register the ingress to the ACME Let's Encrypt server
do_acme_email   = "...@..."
# Unique name for the cluster
do_cluster_name = "..."
```

Run the plan:

```bash
terraform plan -input=false -out=plan
```

Apply the plan:

```bash
terraform apply plan
```

After a few minutes, your Digital Ocean cluster will be ready to accept workloads.

# Resources

The following resources are created:

* a VPC whose name is the same as the cluster - all resources of the cluster will be in this VPC
* a K8S cluster, set in auto scaling mode for its `default` pool of nodes, from 1 node to `do_cluster_default_count` (
  defaults to 3)
* an Ingress controller, a Cert manager & a Cert issuer

# Configuration of the Ingress controller

By default, the Ingress controller uses the https://kubernetes.github.io/ingress-nginx/ controller.

The Certificate issuer uses the ACME Let's Encrypt production server at https://acme-v02.api.letsencrypt.org/directory.
To use the staging server, set:

```hcl
do_acme_server = "https://acme-staging-v02.api.letsencrypt.org/directory"
```

# Adding ingresses

An Ingress resource will typically look like:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-name
  namespace: target-namespace
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    kubernetes.io/ingress.class: nginx
spec:
  tls:
    - hosts:
        - host.domain.com
      secretName: host.domain.com.tls
  rules:
    - host: host.domain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: service-name
                port:
                  number: 8080
```

The two main attributes are the annotations on the Ingress resource:

```yaml
cert-manager.io/cluster-issuer: letsencrypt-prod
kubernetes.io/ingress.class: nginx
```

# Destruction

To remove the whole setup (the Ontrack K8S resources and its managed database), run:

```bash
terraform destroy
```

> Note that the destruction of the VPC associated with the cluster might fail (because it times out before all its associated resources are actually removed). Launch tge `destroy` command to finally clean it.

# Configuration variables

See [`variables.tf`](variables.tf) for the list of configuration variables, their types and their description.
