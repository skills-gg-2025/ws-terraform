# Use direct resource references instead of data sources

# Inbound Rule Group - Application VPC에서 수신하는 트래픽 (80번 포트만 허용)
resource "aws_networkfirewall_rule_group" "hub_firewall_inbound" {
  capacity = 100
  name     = "hub-firewall-inbound"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_string = <<EOF
pass tcp any any -> any 80 (sid:1;)
drop tcp any any -> any any (sid:2;)
EOF
    }
  }

  tags = {
    Name = "hub-firewall-inbound"
  }
}

# Outbound Rule Group - Application VPC로 전달되는 트래픽 (80, 3306번 포트만 허용)
resource "aws_networkfirewall_rule_group" "hub_firewall_outbound" {
  capacity = 100
  name     = "hub-firewall-outbound"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_string = <<EOF
pass tcp any any -> any 80 (sid:10;)
pass tcp any any -> any 3306 (sid:11;)
drop tcp any any -> any any (sid:12;)
EOF
    }
  }

  tags = {
    Name = "hub-firewall-outbound"
  }
}

# Network Firewall Policy
resource "aws_networkfirewall_firewall_policy" "hub_firewall_policy" {
  name = "hub-firewall-policy"

  firewall_policy {
    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.hub_firewall_inbound.arn
    }

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.hub_firewall_outbound.arn
    }

    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
  }

  tags = {
    Name = "hub-firewall-policy"
  }
}

# Network Firewall
resource "aws_networkfirewall_firewall" "hub_firewall" {
  name                = "hub-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.hub_firewall_policy.arn
  vpc_id              = aws_vpc.hub_vpc.id

  subnet_mapping {
    subnet_id = aws_subnet.hub_firewall_a.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.hub_firewall_b.id
  }

  tags = {
    Name = "hub-firewall"
  }
}

# Logging Configuration for Network Firewall
resource "aws_networkfirewall_logging_configuration" "hub_firewall_logging" {
  firewall_arn = aws_networkfirewall_firewall.hub_firewall.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = "/aws/networkfirewall/hub-firewall"
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }
  }
}

# CloudWatch Log Group for Network Firewall
resource "aws_cloudwatch_log_group" "hub_firewall_logs" {
  name              = "/aws/networkfirewall/hub-firewall"
  retention_in_days = 7

  tags = {
    Name = "hub-firewall-logs"
  }
}

# Replace existing route to use Network Firewall endpoint instead of Transit Gateway
resource "aws_route" "hub_firewall_to_app_via_firewall" {
  route_table_id         = aws_route_table.hub_firewall_rt.id
  destination_cidr_block = "192.168.0.0/16"
  vpc_endpoint_id        = [for ss in aws_networkfirewall_firewall.hub_firewall.firewall_status[0].sync_states : ss.attachment[0].endpoint_id if ss.availability_zone == "ap-northeast-2a"][0]

  depends_on = [aws_networkfirewall_firewall.hub_firewall]
  
  # This will replace the existing TGW route
  lifecycle {
    replace_triggered_by = [aws_networkfirewall_firewall.hub_firewall]
  }
}