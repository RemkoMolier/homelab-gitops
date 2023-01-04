resource "random_password" "k3s_token" {
    length           = 32
    special          = false
    override_special = "_%@"
}

resource "proxmox_vm_qemu" "k3s_server" {
    count = length(var.proxmox_nodes)  
    name = "k3s-server-${count.index+1}"
    target_node = "${var.proxmox_nodes[count.index]}"

    vmid = 500+count.index
    
    clone = "debian-${var.debian_version}-amd64-template"
    os_type = "cloud-init"
    memory      = 4096
    cores       = 2

    agent = 1

    network {
        bridge   = "vmbr0"
        firewall = false
        model    = "virtio"
        tag      = 1
        mtu      = 1500
    }

    network {
        bridge   = "vmbr0"
        firewall = false
        model    = "virtio"
        tag      = 5
    }

    network {
        bridge   = "vmbr0"
        firewall = false
        model    = "virtio"
        tag      = 20
        mtu      = 1500
    }

    sshkeys = <<EOF
    ${tls_private_key.ssh_key.public_key_openssh}
    ${var.ssh_keys}
    EOF

    ipconfig0 = "ip=172.16.0.${51+count.index}/24,gw=172.16.0.1"
    ipconfig1 = "ip=10.0.0.${51+count.index}/24"
    ipconfig2 = "ip=10.254.0.${51+count.index}/24"

    lifecycle {
        ignore_changes = [
        ciuser,
        sshkeys,
        disk,
        network
        ]
    }

    connection {
        user = "debian"
        host = self.default_ipv4_address
        private_key = tls_private_key.ssh_key.private_key_openssh
    }

    provisioner "remote-exec" {
        inline = [
        "sudo /usr/bin/cloud-init status --wait"
        ]
    }

    #depends_on = [
    #    packer_image.debian-11-netinstall
    #]
}



resource "null_resource" "k3s_server_cluster_init" {
    count = length(proxmox_vm_qemu.k3s_server) > 0 ? 1:0
    
    connection {
        user = "debian"
        host = proxmox_vm_qemu.k3s_server[0].default_ipv4_address
        private_key = tls_private_key.ssh_key.private_key_openssh
        timeout = "20m"
    }

    provisioner "remote-exec" {
        inline = [
            "echo 'nameserver 172.16.0.1' | sudo tee /etc/k3s-resolv.conf",
            "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=\"${var.k3s_version}\" K3S_TOKEN=\"${random_password.k3s_token.result}\" sh -s - server --cluster-init --disable servicelb --disable traefik --tls-san=172.16.0.50 --flannel-iface=eth1 --node-ip=${proxmox_vm_qemu.k3s_server[0].default_ipv4_address} --cluster-domain ${var.cluster_domain} --resolv-conf=/etc/k3s-resolv.conf",
            "sudo kubectl wait --for=condition=Ready node/${proxmox_vm_qemu.k3s_server[0].name}",
            "sudo kubectl apply -f https://kube-vip.io/manifests/rbac.yaml",
            "sudo ctr image pull ghcr.io/kube-vip/kube-vip:${var.kube_vip_version} -q",
            "alias kube-vip=\"sudo ctr run --rm --net-host ghcr.io/kube-vip/kube-vip:${var.kube_vip_version} vip /kube-vip\"",
            "kube-vip manifest daemonset --interface eth0 --address 172.16.0.50 --inCluster --taint --controlplane --services --arp --leaderElection | sudo kubectl apply -f -"
        ]
    }
}

resource "null_resource" "k3s_server_cluster_add" {
    count = length(proxmox_vm_qemu.k3s_server)-1 > 0 ? length(proxmox_vm_qemu.k3s_server)-1 : 0
    
    connection {
        user = "debian"
        host = proxmox_vm_qemu.k3s_server[count.index+1].default_ipv4_address
        private_key = tls_private_key.ssh_key.private_key_openssh
        timeout = "20m"
    }

    provisioner "remote-exec" {
        inline = [
        "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=\"${var.k3s_version}\" K3S_TOKEN=\"${random_password.k3s_token.result}\" sh -s - server --server https://172.16.0.50:6443 --disable servicelb --disable traefik --tls-san=172.16.0.50 --flannel-iface=eth1 --node-ip=${proxmox_vm_qemu.k3s_server[count.index+1].default_ipv4_address}",
        ]
    }

    depends_on = [
        null_resource.k3s_server_cluster_init
    ]
    
}

data "remote_file" "kubeconfig" {
    conn {
        host        = proxmox_vm_qemu.k3s_server[0].default_ipv4_address
        user        = "debian"
        private_key = tls_private_key.ssh_key.private_key_openssh
        sudo        = true
    }

    path = "/etc/rancher/k3s/k3s.yaml"

    depends_on = [
        null_resource.k3s_server_cluster_init
    ]
}

locals {
    kubeconfig_content = replace(data.remote_file.kubeconfig.content,"127.0.0.1","172.16.0.50")
}    



