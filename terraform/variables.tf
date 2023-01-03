variable "proxmox_api_url" {
    type = string
}

variable "proxmox_tls_insecure" {
    type = bool
    default = false
}

variable "proxmox_nodes" {
    type = list(string)
}

variable "cluster_domain" {
    type = string
}

variable "k3s_version" {
    type = string
    default = "v1.26.0+k3s1"
}

variable "debian_version" {
    type = string
    default = "11.6.0"
}

variable "kube_vip_version" {
    type = string
    default = "v0.5.6"
}

variable "ssh_keys" {
    type = string
    default = ""
}

variable "repository_owner" {
  type        = string
  description = "github owner"
}

variable "repository_name" {
    type        = string
    description = "github repository name"
}

variable "repository_branch" {
    type        = string
    default     = "main"
    description = "branch name"
}

variable "flux_target_path" {
    type        = string
    description = "flux sync target path"
}