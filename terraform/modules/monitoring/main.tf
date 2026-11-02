data "aws_caller_identity" "current" {}

# ==========================================
# TOPICO SNS DE ALERTAS
# ==========================================
# Criptografado com a chave de logs da regiao. Sem assinantes: assinar um e-mail exige
# confirmacao manual e expoe um dado pessoal, entao fica fora do codigo (DECISIONS D-19).

resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-alertas-${var.region_label}"
  kms_master_key_id = var.kms_key_arn

  tags = {
    Name = "${var.project_name}-alertas-${var.region_label}"
  }
}

data "aws_iam_policy_document" "alerts" {
  statement {
    sid    = "AllowAccountOwner"
    effect = "Allow"
    actions = [
      "sns:GetTopicAttributes",
      "sns:SetTopicAttributes",
      "sns:AddPermission",
      "sns:RemovePermission",
      "sns:DeleteTopic",
      "sns:Subscribe",
      "sns:ListSubscriptionsByTopic",
      "sns:Publish",
    ]
    resources = [aws_sns_topic.alerts.arn]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # Somente o CloudWatch (alarmes) e o EventBridge (regras) desta conta publicam no topico.
  statement {
    sid       = "AllowAlarmsAndRulesToPublish"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com", "events.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sns:Publish", "sns:Subscribe"]
    resources = [aws_sns_topic.alerts.arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.alerts.json
}

# ==========================================
# ALARMES
# ==========================================

# Erros 5xx gerados pelo proprio ALB (por exemplo, WAF ou ALB com problema).
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project_name}-alb-5xx-${var.region_label}"
  alarm_description   = "Erros 5xx gerados pelo ALB da regiao ${var.region_label}"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.alb_5xx_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${var.project_name}-alb-5xx-${var.region_label}"
  }
}

# Atraso de replicacao do Aurora Global. A metrica e publicada na regiao do cluster SECUNDARIO.
resource "aws_cloudwatch_metric_alarm" "replication_lag" {
  count = var.enable_replication_lag_alarm ? 1 : 0

  alarm_name          = "${var.project_name}-aurora-atraso-replicacao-${var.region_label}"
  alarm_description   = "Atraso de replicacao do Aurora Global acima do limiar de alerta"
  namespace           = "AWS/RDS"
  metric_name         = "AuroraGlobalDBReplicationLag"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 5
  threshold           = var.replication_lag_threshold_ms
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = var.aurora_secondary_cluster_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${var.project_name}-aurora-atraso-replicacao-${var.region_label}"
  }
}

# Health check do Route 53. As metricas do Route 53 so existem em us-east-1.
# Dado ausente conta como falha: se a metrica sumir, e melhor alertar.
resource "aws_cloudwatch_metric_alarm" "health_check" {
  count = var.enable_health_check_alarm ? 1 : 0

  alarm_name          = "${var.project_name}-health-check-primaria"
  alarm_description   = "O health check do Route 53 da regiao primaria esta falhando"
  namespace           = "AWS/Route53"
  metric_name         = "HealthCheckStatus"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = var.health_check_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${var.project_name}-health-check-primaria"
  }
}

# ==========================================
# REGRAS DO EVENTBRIDGE
# ==========================================

# Achados do GuardDuty de severidade alta (7 ou mais).
resource "aws_cloudwatch_event_rule" "guardduty_high" {
  name        = "${var.project_name}-guardduty-severo-${var.region_label}"
  description = "Achados do GuardDuty com severidade 7 ou mais"

  event_pattern = jsonencode({
    source        = ["aws.guardduty"]
    "detail-type" = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })

  tags = {
    Name = "${var.project_name}-guardduty-severo-${var.region_label}"
  }
}

resource "aws_cloudwatch_event_target" "guardduty_high" {
  rule = aws_cloudwatch_event_rule.guardduty_high.name
  arn  = aws_sns_topic.alerts.arn
}

# Jobs de backup e de copia que falharam, foram abortados ou expiraram.
resource "aws_cloudwatch_event_rule" "backup_failed" {
  name        = "${var.project_name}-backup-falhou-${var.region_label}"
  description = "Jobs de backup ou de copia com falha"

  event_pattern = jsonencode({
    source        = ["aws.backup"]
    "detail-type" = ["Backup Job State Change", "Copy Job State Change"]
    detail = {
      state = ["FAILED", "ABORTED", "EXPIRED"]
    }
  })

  tags = {
    Name = "${var.project_name}-backup-falhou-${var.region_label}"
  }
}

resource "aws_cloudwatch_event_target" "backup_failed" {
  rule = aws_cloudwatch_event_rule.backup_failed.name
  arn  = aws_sns_topic.alerts.arn
}
