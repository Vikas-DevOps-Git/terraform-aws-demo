# Transit Gateway — hub-spoke connectivity for multi-VPC environments
# Connects dev/staging/prod VPCs for shared services (Vault, monitoring)

locals {
  common_tags = {
    Environment   = var.environment
    ManagedBy     = "terraform"
    ComplianceTag = "sox-compliant"
  }
}

resource "aws_ec2_transit_gateway" "main" {
  description                     = "BNY platform TGW — ${var.environment}"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"
  tags = merge(local.common_tags, { Name = "${var.environment}-tgw" })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = var.vpc_id
  subnet_ids         = var.private_subnet_ids

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(local.common_tags, { Name = "${var.environment}-tgw-attachment" })
}

resource "aws_ec2_transit_gateway_route_table" "main" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  tags = merge(local.common_tags, { Name = "${var.environment}-tgw-rt" })
}

resource "aws_ec2_transit_gateway_route_table_association" "main" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.main.id
}
