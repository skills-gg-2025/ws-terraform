# Stateless Rule Group - Block ICMP
resource "aws_networkfirewall_rule_group" "stateless_icmp_block" {
  capacity = 100
  name     = "wsc2025-stateless-icmp-block"
  type     = "STATELESS"

  rule_group {
    rules_source {
      stateless_rules_and_custom_actions {
        stateless_rule {
          priority = 1
          rule_definition {
            actions = ["aws:drop"]
            match_attributes {
              protocols = [1] # ICMP
              source {
                address_definition = "0.0.0.0/0"
              }
              destination {
                address_definition = "0.0.0.0/0"
              }
            }
          }
        }
      }
    }
  }

  tags = {
    Name = "wsc2025-stateless-icmp-block"
  }
}

# Stateful Rule Group - Block DNS and HTTPS
resource "aws_networkfirewall_rule_group" "stateful_dns_https_block" {
  capacity = 100
  name     = "wsc2025-stateful-dns-https-block"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_string = <<EOF
drop tcp any any -> any 53 (msg:"Block TCP DNS"; sid:1; rev:1;)
drop udp any any -> any 53 (msg:"Block UDP DNS"; sid:2; rev:1;)
drop tcp any any -> any 443 (msg:"Block HTTPS"; sid:3; rev:1;)
EOF
    }
  }

  tags = {
    Name = "wsc2025-stateful-dns-https-block"
  }
}

# Firewall Policy
resource "aws_networkfirewall_firewall_policy" "main" {
  name = "wsc2025-firewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateless_rule_group_reference {
      priority     = 1
      resource_arn = aws_networkfirewall_rule_group.stateless_icmp_block.arn
    }

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.stateful_dns_https_block.arn
    }
  }

  tags = {
    Name = "wsc2025-firewall-policy"
  }
}

# Network Firewall
resource "aws_networkfirewall_firewall" "main" {
  name               = "wsc2025-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.main.arn
  vpc_id             = aws_vpc.egress.id

  subnet_mapping {
    subnet_id = aws_subnet.egress_firewall_a.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.egress_firewall_b.id
  }

  tags = {
    Name = "wsc2025-firewall"
  }
}