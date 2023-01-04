data "flux_install" "cluster" {
  target_path = var.flux_target_path
  cluster_domain = var.cluster_domain
}

data "flux_sync" "cluster" {
  target_path = var.flux_target_path
  url         = "ssh://git@github.com/${var.repository_owner}/${var.repository_name}.git"
  branch      = var.repository_branch
}

resource "local_file" "flux_install" {
  content  = data.flux_install.cluster.content
  filename = "../${data.flux_install.cluster.path}"
}

resource "local_file" "flux_sync" {
  content  = data.flux_sync.cluster.content
  filename = "../${data.flux_sync.cluster.path}"
}

resource "local_file" "flux_kustomize" {
  content  = data.flux_sync.cluster.kustomize_content
  filename = "../${data.flux_sync.cluster.kustomize_path}"
}

locals {
  github_known_hosts = <<EOT
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
  EOT
}

resource "remote_file" "flux_install" {
  conn {
      host        = proxmox_vm_qemu.k3s_server[0].default_ipv4_address
      user        = "debian"
      private_key = tls_private_key.ssh_key.private_key_openssh
  }

  content = data.flux_install.cluster.content
  path = "/home/debian/flux_install.yaml"
  
}

resource "remote_file" "flux_sync" {
  conn {
      host        = proxmox_vm_qemu.k3s_server[0].default_ipv4_address
      user        = "debian"
      private_key = tls_private_key.ssh_key.private_key_openssh
  }

  content = data.flux_sync.cluster.content
  path = "/home/debian/flux_sync.yaml"
}



resource "null_resource" "k3s_server_flux_init" {
    count = length(proxmox_vm_qemu.k3s_server) > 0 ? 1:0
    
    connection {
        user = "debian"
        host = proxmox_vm_qemu.k3s_server[0].default_ipv4_address
        private_key = tls_private_key.ssh_key.private_key_openssh
        timeout = "20m"
    }

    provisioner "remote-exec" {
        inline = [
            "sudo kubectl create namespace ${data.flux_sync.cluster.namespace} --dry-run=client -o yaml | sudo kubectl apply -f -",
            "sudo kubectl -n ${data.flux_sync.cluster.namespace} create secret generic sops-age --from-literal=age.ageKey='${data.sops_file.secrets.data["age.agekey"]}' --dry-run=client -o yaml | sudo kubectl apply -f -",
            "sudo kubectl -n ${data.flux_sync.cluster.namespace} create secret generic ${data.flux_sync.cluster.secret} --from-literal=identity='${data.sops_file.secrets.data["git.deploy-key.private"]}' --from-literal=identity.pub='${data.sops_file.secrets.data["git.deploy-key.public"]}' --from-literal=known_hosts='${local.github_known_hosts}' --dry-run=client -o yaml | sudo kubectl apply -f -",
            "sudo kubectl apply -f /home/debian/flux_install.yaml",
            "sudo kubectl apply -f /home/debian/flux_sync.yaml",
            
        ]
    }

    depends_on = [
        null_resource.k3s_server_cluster_init,
        remote_file.flux_install,
        remote_file.flux_sync,
    ]
}