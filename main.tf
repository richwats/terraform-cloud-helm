terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "mel-ciscolabs-com"
    workspaces {
      name = "terraform-cloud-k8s"
    }
  }
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.25.0"
    }
    vault = {
      source = "hashicorp/vault"
      version = "2.18.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.0.2"
    }
  }
}

### Vault Provider ###
## Username & Password provided by Workspace Variable
variable vault_username {}
variable vault_password {
  sensitive = true
}

provider "vault" {
  address = "https://Hashi-Vault-1F899TQ4290I3-1824033843.ap-southeast-2.elb.amazonaws.com"
  skip_tls_verify = true
  auth_login {
    path = "auth/userpass/login/${var.vault_username}"
    parameters = {
      password = var.vault_password
    }
  }
}

data "vault_generic_secret" "aws-prod" {
  path = "kv/aws-prod"
}


### AWS Provider ###
provider "aws" {
  region     = "ap-southeast-2"
  access_key = data.vault_generic_secret.aws-prod.data["access"]
  secret_key = data.vault_generic_secret.aws-prod.data["secret"]
}

data "aws_eks_cluster" "eks-1" {
  name = "test-eks-KUrLlzWs"
}

data "aws_eks_cluster_auth" "eks-1" {
  name = "test-eks-KUrLlzWs"
}

### Kubernetes Provider ###
# # - Get Kubeconfig
# provider "kubernetes" {
#   host                   = data.aws_eks_cluster.eks-1.endpoint
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks-1.certificate_authority.0.data)
#   token                  = data.aws_eks_cluster_auth.eks-1.token
#   # load_config_file       = false
#   # version                = "~> 1.11"
# }


provider "helm" {
  kubernetes {
    # config_path = "~/.kube/config"
    host                   = data.aws_eks_cluster.eks-1.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks-1.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.eks-1.token
  }
}

resource "helm_release" "nginx" {
  namespace   = "default"
  name        = "nginx-demo"

  repository  = "https://charts.bitnami.com/bitnami"
  chart       = "nginx"

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }
}
