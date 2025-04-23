output "transit_gateway_id"            { value = aws_ec2_transit_gateway.main.id }
output "transit_gateway_attachment_id" { value = aws_ec2_transit_gateway_vpc_attachment.main.id }
output "route_table_id"                { value = aws_ec2_transit_gateway_route_table.main.id }
