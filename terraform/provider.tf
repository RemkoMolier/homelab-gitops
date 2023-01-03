provider "proxmox" {
    pm_api_url = "${var.proxmox_api_url}"
    pm_user = data.sops_file.secrets.data["proxmox.user"]
    pm_password = data.sops_file.secrets.data["proxmox.password"]
    pm_tls_insecure = var.proxmox_tls_insecure
    pm_parallel = 20
}

provider "sops" {
}

provider "packer" {
}

provider "remote" {
    max_sessions = 2
}

provider "flux" {
    
}

provider "kubernetes" {
  
}