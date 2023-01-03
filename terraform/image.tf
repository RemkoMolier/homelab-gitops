data "packer_version" "version" {}

data "packer_files" "debian_11_netinstall" {
    directory = "debian-11-netinstall"
}

resource "packer_image" "debian-11-netinstall" {
    count = length(var.proxmox_nodes)
    variables = {
        proxmox_api_url = "${var.proxmox_api_url}"
        proxmox_user = data.sops_file.secrets.data["proxmox.user"]
        proxmox_password = data.sops_file.secrets.data["proxmox.password"]
        proxmox_tls_insecure = var.proxmox_tls_insecure
        proxmox_node = "${var.proxmox_nodes[count.index]}"
        vm_id = 9000+count.index
        debian_version = "${var.debian_version}"
    }

    directory = data.packer_files.debian_11_netinstall.directory
    
    triggers = {
        packer_version = data.packer_version.version.version
        debian_11_netinstall_hash = data.packer_files.debian_11_netinstall.files_hash

    }
}