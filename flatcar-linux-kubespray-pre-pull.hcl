
variable "acceleration" {
  type    = string
  default = "kvm"
}

variable "boot_wait" {
  type    = string
  default = "45s"
}

variable "disk_size" {
  type    = string
  default = "40000"
}

variable "flatcar_channel" {
  type    = string
  default = "alpha"
}

variable "flatcar_version" {
  type    = string
  default = "current"
}

variable "headless" {
  type    = string
  default = "false"
}

variable "iso_checksum" {
  type    = string
  default = ""
}

variable "iso_checksum_type" {
  type    = string
  default = "none"
}

variable "kube_version" {
  type    = string
  default = "v1.18.3"
}

variable "memory" {
  type    = string
  default = "2048M"
}

source "qemu" "image" {
  accelerator             = "${var.acceleration}"
  boot_command            = [
    "sudo passwd core<enter><wait><wait><wait><wait><wait>",
    "packer<enter><wait><wait>",
    "packer<enter><wait><wait>",
    "sudo systemctl start sshd.service<enter>"
  ]
  boot_wait               = "${var.boot_wait}"
  disk_image              = false
  disk_size               = "${var.disk_size}"
  format                  = "qcow2"
  headless                = "${var.headless}"
  iso_checksum            = "${var.iso_checksum}"
  iso_checksum_type       = "${var.iso_checksum_type}"
  iso_url                 = "https://${var.flatcar_channel}.release.flatcar-linux.net/amd64-usr/current/flatcar_production_iso_image.iso"
  output_directory        = "builds"
  pause_before_connecting = "2m"
  qemuargs                = [
    ["-m", "${var.memory}"],
    ["-fw_cfg", "name=opt/org.flatcar-linux/config,file=boot.ign"]
  ]
  shutdown_command        = "sudo shutdown now"
  ssh_password            = "packer"
  ssh_timeout             = "5m"
  ssh_username            = "core"
  vm_name                 = "flatcar-linux-${var.flatcar_channel}.qcow2"
  vnc_bind_address        = "0.0.0.0"
  vnc_use_password        = true
}

build {
  sources = [
    "source.qemu.image"
  ]

  provisioner "file" {
    destination = "/tmp/ignition.json"
    source      = "ignition.json"
  }

  provisioner "shell" {
    inline = [
      "sudo flatcar-install -d /dev/vda -C ${var.flatcar_channel} -i /tmp/ignition.json"
    ]
  }

  provisioner "ansible" {
    ansible_env_vars    = [
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ANSIBLE_CONFIG=./kubespray/ansible.cfg"
    ]
    extra_arguments     = [
      "-b", "-e", "ip=10.0.2.15",
      "-e", "kube_version=${var.kube_version}",
      "-e", "ingress_nginx_enabled=True",
      "-e", "local_release_dir='/root/releases'",
      "-e", "helm_enabled=True",
      "-e", "ignore_assert_errors=True",
      "-e", "bootstrap_os=flatcar",
      "--private-key", "unsec_priv_key",
      "--tags", "always,bootstrap-os,preinstall,docker,download"
    ]
    groups              = [
      "kube-master",
      "etcd",
      "kube-node",
      "k8s-cluster"
    ]
    inventory_directory = "./kubespray/inventory/sample/"
    keep_inventory_file = true
    playbook_file       = "./kubespray/cluster.yml"
    roles_path          = "./kubespray/roles/"
    user                = "core"
  }

}
