terraform {
    required_version = ">= 0.13.0"

    required_providers {
        proxmox = {
            source = "Telmate/proxmox"
            version = "2.9.10"
        }

        sops = {
            source = "carlpett/sops"
            version = "0.7.1"
        }

        packer = {
            source = "toowoxx/packer"
            version = "0.14.0"
        }

        remote = {
            source = "tenstad/remote"
            version = "0.1.1"
        }

        flux = {
            source  = "fluxcd/flux"
            version = ">= 0.0.13"
        }
    }
}