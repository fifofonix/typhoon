locals {

  fcos_blacklisted = [
    # "ami-024fca6df6d29c717", # Next, 6.1.6
    # "ami-016069fc4cb84c296"  # Testing, 6.1.6
  ]

  fcos_next_pinned    = var.os_pinned_ami
  # fedora-coreos-41.20241122.1.0-x86_64 ami-0b259c6773df76310 6.11.8-300.fc41.x86_64 (next)

  fcos_testing_pinned = var.os_pinned_ami
  # fedora-coreos-41.20241122.2.0-x86_64 ami-083f53a14231338dc (testing)

  fcos_stable_pinned  = var.os_pinned_ami
  # fedora-coreos-41.20241122.3.0-x86_64 ami-04631d2c883552c84 (stable)

  # Get the AMI that is the 'released' one as defined by FCOS HTTPS metadata.
  # In general there is a 'small' period of time where AMIs are pre-positioned
  # before they are actually triggered for release.  This also caters to the
  # rare situation where an OS rollback occurs.  In this situation the metadata
  # will be updated to indicate the 'released' official version which will not
  # be the latest AMI

  fcos_next_metadata_defined_ami_x86    = lookup(jsondecode(data.http.next_metadata.response_body).architectures.x86_64.images.aws.regions, data.aws_region.current.name).image
  fcos_testing_metadata_defined_ami_x86 = lookup(jsondecode(data.http.testing_metadata.response_body).architectures.x86_64.images.aws.regions, data.aws_region.current.name).image
  fcos_stable_metadata_defined_ami_x86  = lookup(jsondecode(data.http.stable_metadata.response_body).architectures.x86_64.images.aws.regions, data.aws_region.current.name).image

  fcos_next_metadata_defined_ami_arm    = lookup(jsondecode(data.http.next_metadata.response_body).architectures.aarch64.images.aws.regions, data.aws_region.current.name).image
  fcos_testing_metadata_defined_ami_arm = lookup(jsondecode(data.http.testing_metadata.response_body).architectures.aarch64.images.aws.regions, data.aws_region.current.name).image
  fcos_stable_metadata_defined_ami_arm  = lookup(jsondecode(data.http.stable_metadata.response_body).architectures.aarch64.images.aws.regions, data.aws_region.current.name).image

  fcos_next_metadata_defined_ami    = var.arch == "arm64" ? local.fcos_next_metadata_defined_ami_arm : local.fcos_next_metadata_defined_ami_x86
  fcos_testing_metadata_defined_ami = var.arch == "arm64" ? local.fcos_testing_metadata_defined_ami_arm : local.fcos_testing_metadata_defined_ami_x86
  fcos_stable_metadata_defined_ami  = var.arch == "arm64" ? local.fcos_stable_metadata_defined_ami_arm : local.fcos_stable_metadata_defined_ami_x86

  fcos_metadata_defined_ami = var.os_stream == "next" ? local.fcos_next_metadata_defined_ami : var.os_stream == "testing" ? local.fcos_testing_metadata_defined_ami : local.fcos_stable_metadata_defined_ami

  # Remove pre-positioned items until such time as they are released.
  fcos_ordered_amis_minus_unreleased    = slice(data.aws_ami_ids.fedora-coreos.ids, 0, index(data.aws_ami_ids.fedora-coreos.ids, local.fcos_metadata_defined_ami) + 1)

  # Remove any blacklisted AMIs and then from the remaining list pick the most current...but also respect any pinning...
  fcos_pinned = var.os_stream == "next" ? local.fcos_next_pinned : var.os_stream == "testing" ? local.fcos_testing_pinned : local.fcos_stable_pinned
  ami_id = local.fcos_pinned != "" ? local.fcos_pinned : [for i in reverse(local.fcos_ordered_amis_minus_unreleased) : i if contains(local.fcos_blacklisted, i) == false][0]

}

data "aws_region" "current" {}

data "http" "next_metadata" {
  url = "https://builds.coreos.fedoraproject.org/streams/next.json"

  # Optional request headers
  request_headers = {
    Accept = "application/json"
  }
}

data "http" "testing_metadata" {
  url = "https://builds.coreos.fedoraproject.org/streams/testing.json"

  # Optional request headers
  request_headers = {
    Accept = "application/json"
 }
}
data "http" "stable_metadata" {
 url = "https://builds.coreos.fedoraproject.org/streams/stable.json"

  # Optional request headers
  request_headers = {
    Accept = "application/json"
  }
}

data "aws_ami_ids" "fedora-coreos" {
  owners      = ["125523088429"]
  sort_ascending = true

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "description"
    values = ["Fedora CoreOS ${var.os_stream} *"]
  }
}

data "aws_ami_ids" "fedora-coreos-arm" {
  count = var.arch == "arm64" ? 1 : 0

  owners      = ["125523088429"]
  sort_ascending = true

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "description"
    values = ["Fedora CoreOS ${var.os_stream} *"]
  }
}
