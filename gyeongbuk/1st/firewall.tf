# Network Firewall Rule Group
resource "aws_networkfirewall_rule_group" "skills_rule_group" {
  capacity = 100
  name     = "skills-firewall-rule-group"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "DENYLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets              = ["ifconfig.me"]
      }
    }
  }

  tags = {
    Name = "skills-firewall-rule-group"
  }
}

# Network Firewall Policy
resource "aws_networkfirewall_firewall_policy" "skills_policy" {
  name = "skills-firewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.skills_rule_group.arn
    }
  }

  tags = {
    Name = "skills-firewall-policy"
  }
}

# Network Firewall
resource "aws_networkfirewall_firewall" "skills_firewall" {
  name                = "skills-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.skills_policy.arn
  vpc_id              = aws_vpc.hub.id

  subnet_mapping {
    subnet_id = aws_subnet.inspect_subnet_a.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.inspect_subnet_b.id
  }

  tags = {
    Name = "skills-firewall"
  }
}

# Network Firewall Logging Configuration
resource "aws_cloudwatch_log_group" "firewall_log_group" {
  name              = "/aws/networkfirewall/skills-firewall"
  retention_in_days = 7

  tags = {
    Name = "skills-firewall-log-group"
  }
}

resource "aws_networkfirewall_logging_configuration" "skills_firewall_logging" {
  firewall_arn = aws_networkfirewall_firewall.skills_firewall.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall_log_group.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }
  }
}
