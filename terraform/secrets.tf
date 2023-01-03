data "sops_file" "secrets" {
    source_file = ".secrets.yaml"
}

resource "tls_private_key" "ssh_key" {
    algorithm = "ECDSA"
    ecdsa_curve = "P521"
}

