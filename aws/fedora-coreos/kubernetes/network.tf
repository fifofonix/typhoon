data "aws_availability_zones" "all" {
}

# Network VPC, gateway, and routes

resource "aws_vpc" "network" {
  count                            = (var.reuse_networking == "true" ? 0 : 1)
  cidr_block                       = var.host_cidr
  assign_generated_ipv6_cidr_block = (var.ipv6_networking == "true" ? true : false)

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    "Name" = var.cluster_name
  }
}

data "aws_vpc" "network" {
  id = (var.reuse_networking == "true" ? var.explicit_vpc_id : aws_vpc.network[0].id)
}

resource "aws_internet_gateway" "gateway" {
  count  = (var.reuse_networking == "true" ? 0 : 1)
  vpc_id = data.aws_vpc.network.id

  tags = {
    "Name" = var.cluster_name
  }
}

resource "aws_route_table" "default" {
  count  = (var.reuse_networking == "true" ? 0 : 1)
  vpc_id = data.aws_vpc.network.id

  tags = {
    "Name" = var.cluster_name
  }
}

resource "aws_route" "egress-ipv4" {
  count                  = (var.reuse_networking == "true" ? 0 : 1)
  route_table_id         = aws_route_table.default[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gateway[0].id
}

resource "aws_route" "egress-ipv6" {
  count                       = (var.reuse_networking == "true" ? 0 : 1)
  route_table_id              = aws_route_table.default[0].id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.gateway[0].id
}

# Subnets (one per availability zone)

data "aws_subnets" "subnets" {
  filter {
    name   = "subnet-id"
    values = (var.reuse_networking == "true" ? var.explicit_subnets : [for s in aws_subnet.public : s.id])
  }
}

resource "aws_subnet" "public" {
  count = (var.reuse_networking == "true" ? 0 : length(data.aws_availability_zones.all.names))

  vpc_id            = data.aws_vpc.network.id
  availability_zone = data.aws_availability_zones.all.names[count.index]

  cidr_block = cidrsubnet(var.host_cidr, 4, count.index)

  ipv6_cidr_block = cidrsubnet(data.aws_vpc.network.ipv6_cidr_block, 8, count.index)

  map_public_ip_on_launch = (var.privacy_status == "public" ? true : false)

  assign_ipv6_address_on_creation = (var.ipv6_networking == "true" ? true : false)

  tags = {
    "Name" = "${var.cluster_name}-public-${count.index}"
  }
}

resource "aws_route_table_association" "public" {
  count = (var.reuse_networking == "true" ? 0 : length(data.aws_availability_zones.all.names))

  route_table_id = aws_route_table.default[0].id
  subnet_id      = data.aws_subnets.subnets.ids[count.index]

}

