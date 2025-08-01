output "app_server_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "alb_dns_name" {
  value = aws_lb.waf_alb.dns_name
}

output "waf_web_acl_name" {
  value = aws_wafv2_web_acl.waf.name
}