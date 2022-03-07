output "zone_id_route53" {
    value = aws_route53_zone.this.zone_id
}

output "name_servers_route53" {
    value = aws_route53_zone.this.name_servers
}

output "arn_route53" {
    value = aws_route53_zone.this.arn
}
