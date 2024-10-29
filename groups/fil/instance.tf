resource "aws_placement_group" "fil" {
  name     = local.common_resource_name
  strategy = "spread"
}

resource "aws_key_pair" "master" {
  key_name   = "${local.common_resource_name}-master"
  public_key = var.ssh_master_public_key
}

resource "aws_security_group" "common" {
  name   = "common-${local.common_resource_name}"
  vpc_id = data.aws_vpc.heritage.id

  tags = merge(local.common_tags, {
    Name = "common-${local.common_resource_name}"
  })
}

resource "aws_vpc_security_group_ingress_rule" "admin_ingress" {
  security_group_id = aws_security_group.common.id
  description       = "Allow SSH connectivity for application deployments"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.shared_services_management.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "visual_basic_app_ingress" {
  for_each = local.visual_basic_app_security_group_rules

  security_group_id = aws_security_group.common.id
  description       = "Allow Informix HDR connectivity for Visual Basic services"
  cidr_ipv4         = each.value.cidr_ipv4
  from_port         = each.value.port
  to_port           = each.value.port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "chips_ingress" {
  for_each = var.tuxedo_services

  security_group_id = aws_security_group.common.id
  description       = "Allow CHIPS connectivity for Tuxedo ${upper(each.key)} services"
  cidr_ipv4         = var.chips_cidr
  from_port         = each.value
  to_port           = each.value
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "ois_ingress" {
  for_each = {
    for rule in local.ois_security_group_rules : "${rule.service}-${rule.port}-${rule.cidr_ipv4}" => rule
  }

  security_group_id = aws_security_group.common.id
  description       = "Allow OIS Tuxedo connectivity for Tuxedo ${upper(each.value.service)} services"
  cidr_ipv4         = each.value.cidr_ipv4
  from_port         = each.value.port
  to_port           = each.value.port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "informix_ingress" {
  for_each = {
    for rule in local.informix_hdr_security_group_rules : "${rule.service}-${rule.port}-${rule.cidr_ipv4}" => rule
  }

  security_group_id = aws_security_group.common.id
  description       = "Allow Informix HDR connectivity for Tuxedo ${upper(each.value.service)} services"
  cidr_ipv4         = each.value.cidr_ipv4
  from_port         = each.value.port
  to_port           = each.value.port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all_egress" {
  security_group_id = aws_security_group.common.id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "fil" {
  count = var.instance_count

  ami             = data.aws_ami.fil_tuxedo.id
  instance_type   = var.instance_type
  key_name        = aws_key_pair.master.id
  placement_group = aws_placement_group.fil.id
  subnet_id       = element(local.application_subnet_ids_by_az, count.index) # use 'element' function for wrap-around behaviour

  iam_instance_profile   = module.instance_profile.aws_iam_instance_profile.name
  user_data_base64       = data.cloudinit_config.config[count.index].rendered
  vpc_security_group_ids = [aws_security_group.common.id]

  dynamic "ebs_block_device" {
    for_each = [
      for block_device in data.aws_ami.fil_tuxedo.block_device_mappings :
      block_device if block_device.device_name != data.aws_ami.fil_tuxedo.root_device_name
    ]
    iterator = block_device
    content {
      device_name = block_device.value.device_name
      encrypted   = block_device.value.ebs.encrypted
      iops        = block_device.value.ebs.iops
      snapshot_id = block_device.value.ebs.snapshot_id
      volume_size = var.lvm_block_devices[index(var.lvm_block_devices[*].lvm_physical_volume_device_node, block_device.value.device_name)].aws_volume_size_gb
      volume_type = block_device.value.ebs.volume_type
    }
  }

  root_block_device {
    volume_size = var.root_volume_size
  }

  tags = merge(local.common_tags, {
    Name = "${var.service_subtype}-${var.service}-${var.environment}-${count.index + 1}"
  })
  volume_tags = local.common_tags
}
