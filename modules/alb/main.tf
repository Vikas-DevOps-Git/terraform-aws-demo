locals {
  common_tags = {
    Environment   = var.environment
    ManagedBy     = "terraform"
    ComplianceTag = "sox-compliant"
  }
}

resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = "ALB security group — HTTPS only"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
    description = "HTTPS inbound"
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
    description = "HTTP redirect only"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${var.environment}-alb-sg" })
}

resource "aws_lb" "main" {
  name               = "${var.environment}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection = var.environment == "prod" ? true : false
  drop_invalid_header_fields = true

  access_logs {
    bucket  = var.access_log_bucket
    prefix  = "${var.environment}-alb"
    enabled = true
  }
  tags = merge(local.common_tags, { Name = "${var.environment}-alb" })
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_target_group" "main" {
  name        = "${var.environment}-tg"
  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 10
    matcher             = "200"
  }
  tags = merge(local.common_tags, { Name = "${var.environment}-tg" })
}

# WAF association
resource "aws_wafv2_web_acl_association" "main" {
  count        = var.waf_acl_arn != "" ? 1 : 0
  resource_arn = aws_lb.main.arn
  web_acl_arn  = var.waf_acl_arn
}
