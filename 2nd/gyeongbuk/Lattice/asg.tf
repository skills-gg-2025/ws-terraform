# Consumer Launch Template
resource "aws_launch_template" "consumer" {
  name_prefix   = "skills-consumer-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.bastion.key_name

  vpc_security_group_ids = [aws_security_group.consumer_server.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_dynamodb.name
  }

  user_data = base64encode(templatefile("${path.module}/src/consumer_userdata.sh", {
    lattice_service_dns = aws_vpclattice_service.app.dns_entry[0].domain_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "skills-consumer-server"
    }
  }

  tags = {
    Name = "skills-consumer-lt"
  }
}

# Service Launch Template
resource "aws_launch_template" "service" {
  name_prefix   = "skills-app-server-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.bastion.key_name

  vpc_security_group_ids = [aws_security_group.app_server.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_dynamodb.name
  }

  user_data = base64encode(file("${path.module}/src/service_userdata.sh"))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "skills-app-server"
    }
  }

  tags = {
    Name = "skills-app-server-lt"
  }
}

# Consumer Auto Scaling Group
resource "aws_autoscaling_group" "consumer" {
  name = "skills-consumer-asg"
  vpc_zone_identifier = [
    aws_subnet.consumer_private_a.id,
    aws_subnet.consumer_private_c.id
  ]
  target_group_arns         = [aws_lb_target_group.consumer.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  min_size         = 2
  max_size         = 6
  desired_capacity = 2

  launch_template {
    id      = aws_launch_template.consumer.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "skills-consumer-asg"
    propagate_at_launch = false
  }
}

# Service Auto Scaling Group
resource "aws_autoscaling_group" "service" {
  name = "skills-app-asg"
  vpc_zone_identifier = [
    aws_subnet.service_private_a.id,
    aws_subnet.service_private_c.id
  ]
  target_group_arns         = [aws_lb_target_group.service.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  min_size         = 2
  max_size         = 6
  desired_capacity = 2

  launch_template {
    id      = aws_launch_template.service.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "skills-app-asg"
    propagate_at_launch = false
  }
}
