locals {
  # format assets for distribution
  assets_bundle = [
    # header with the unpack location
    for key, value in module.bootstrap.assets_dist :
    format("##### %s\n%s", key, value)
  ]

  environment = aws_instance.controllers[0].tags.Environment

}

# Secure copy assets to controllers.
resource "null_resource" "copy-controller-secrets" {
  count = var.controller_count

  depends_on = [
    module.bootstrap,
  ]

  connection {
    type    = "ssh"
    host    = (var.privacy_status == "public" ? aws_instance.controllers.*.public_ip[count.index] : aws_instance.controllers.*.private_ip[count.index])
    user    = "core"
    agent_identity = file("~/.ssh/id_ecdsa_${local.environment}")
    certificate = file("~/.ssh/id_ecdsa_${local.environment}-cert.pub")
    timeout = "15m"
  }

  provisioner "file" {
    content     = join("\n", local.assets_bundle)
    destination = "/home/core/assets"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo /opt/bootstrap/layout",
    ]
  }
}

# Connect to a controller to perform one-time cluster bootstrap.
resource "null_resource" "bootstrap" {
  depends_on = [
    null_resource.copy-controller-secrets,
    module.workers,
    aws_route53_record.apiserver,
  ]

  connection {
    type    = "ssh"
    host    = (var.privacy_status == "public" ? aws_instance.controllers[0].public_ip : aws_instance.controllers[0].private_ip)
    user    = "core"
    agent_identity = file("~/.ssh/id_ecdsa_${local.environment}")
    certificate = file("~/.ssh/id_ecdsa_${local.environment}-cert.pub")
    timeout = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo systemctl start bootstrap",
    ]
  }
}

