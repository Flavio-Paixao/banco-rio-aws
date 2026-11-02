data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# ==========================================
# CERTIFICADO ACM
# ==========================================
# Dominio ficticio: o certificado e declarado, mas nunca seria validado num apply real
# (a validacao por DNS exigiria um dominio de verdade). Por isso nao ha aws_acm_certificate_validation.

resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-${var.region_label}-cert"
  }
}

# ==========================================
# APPLICATION LOAD BALANCER
# ==========================================
# Sem instancias atras dele: responde com uma resposta fixa (DECISIONS D-04).
# Serve de alvo para o WAF e para o health check do Route 53.

resource "aws_lb" "main" {
  #checkov:skip=CKV_AWS_91:Access logs do ALB so aceitam bucket com SSE-S3, nao KMS, o que quebra o padrao do projeto (DECISIONS D-16)
  #checkov:skip=CKV_AWS_150:Projeto de estudo precisa poder ser destruido (DECISIONS D-16)
  name               = "${var.project_name}-${var.region_label}-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = var.public_subnet_ids
  security_groups    = [var.alb_security_group_id]

  drop_invalid_header_fields = true
  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-${var.region_label}-alb"
  }
}

# HTTP so redireciona para HTTPS
resource "aws_lb_listener" "http" {
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

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Banco Rio: ambiente de estudo"
      status_code  = "200"
    }
  }
}

# ==========================================
# WAF (regras gerenciadas da AWS + limite de requisicoes por IP)
# ==========================================

locals {
  # nome do grupo gerenciado => prioridade
  managed_rule_groups = {
    AWSManagedRulesCommonRuleSet          = 10
    AWSManagedRulesKnownBadInputsRuleSet  = 20
    AWSManagedRulesSQLiRuleSet            = 30
    AWSManagedRulesAmazonIpReputationList = 40
  }
}

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_name}-${var.region_label}-waf"
  description = "WAF do ALB: regras gerenciadas da AWS e limite por IP"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = local.managed_rule_groups

    content {
      name     = rule.key
      priority = rule.value

      # none = usa a acao propria de cada regra do grupo (bloquear)
      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = rule.key
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.project_name}-${var.region_label}-${rule.key}"
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "LimitePorIp"
    priority = 50

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-${var.region_label}-limite-por-ip"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${var.region_label}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${var.project_name}-${var.region_label}-waf"
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

# ==========================================
# LOGS DO WAF (CloudWatch Logs, criptografado com a chave de logs)
# ==========================================
# O WAF exige que o nome do log group comece com "aws-waf-logs-" (a key policy
# da chave de logs ja aceita esse padrao).

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.project_name}-${var.region_label}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.logs_kms_key_arn

  tags = {
    Name = "${var.project_name}-${var.region_label}-waf-logs"
  }
}

data "aws_iam_policy_document" "waf_logs" {
  statement {
    sid       = "AllowWafLogDelivery"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.waf.arn}:*"]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "waf" {
  policy_name     = "${var.project_name}-${var.region_label}-waf-logs"
  policy_document = data.aws_iam_policy_document.waf_logs.json
}

resource "aws_wafv2_web_acl_logging_configuration" "main" {
  resource_arn            = aws_wafv2_web_acl.main.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]

  # Nao grava credenciais nem cookies de sessao nos logs
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

  depends_on = [aws_cloudwatch_log_resource_policy.waf]
}
