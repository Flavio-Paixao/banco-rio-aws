# ==========================================
# DATA SOURCES (conta e regioes, para montar ARNs e condicoes exatas)
# ==========================================

data "aws_caller_identity" "current" {}

data "aws_region" "primary" {}

data "aws_region" "dr" {
  provider = aws.dr
}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  account_root = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
}

locals {
  regions = {
    primary = data.aws_region.primary.name
    dr      = data.aws_region.dr.name
  }
}

# ==========================================
# KEY POLICIES DE MINIMO PRIVILEGIO
# ==========================================
# Separam QUEM ADMINISTRA de QUEM USA:
#
# 1) Administracao: a conta (via IAM) gerencia a chave (ver, rotacionar, mudar a
#    policy, replicar, agendar exclusao), mas NAO criptografa/descriptografa direto.
#    Manter a conta aqui evita "chave orfa".
#
# 2) Uso da chave de dados: so quando a chamada passa por RDS ou S3 (kms:ViaService)
#    e vem desta conta (kms:CallerAccount).
#
# 3) Uso da chave de logs: so o servico CloudWatch Logs da regiao, e so para log
#    groups do projeto (encryption context), mais a trilha do CloudTrail e o uso do
#    bucket de auditoria via S3 (fase 8).
#
# Cada regiao tem a sua policy porque ViaService e o servico mudam com a regiao.

locals {
  key_admin_actions = [
    "kms:CreateAlias", # nao "kms:Create*": isso incluiria CreateGrant sem as condicoes abaixo
    "kms:Describe*",
    "kms:Enable*",
    "kms:List*",
    "kms:Put*",
    "kms:Update*",
    "kms:Revoke*",
    "kms:Disable*",
    "kms:Get*",
    "kms:Delete*",
    "kms:TagResource",
    "kms:UntagResource",
    "kms:ScheduleKeyDeletion",
    "kms:CancelKeyDeletion",
    "kms:ReplicateKey",
    "kms:UpdatePrimaryRegion",
  ]

  key_usage_actions = [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncrypt*",
    "kms:GenerateDataKey*",
    "kms:DescribeKey",
  ]
}

data "aws_iam_policy_document" "data_key" {
  #checkov:skip=CKV_AWS_109:Key policy: Resource * significa esta chave; a restricao vem dos principals e conditions (DECISIONS D-13)
  #checkov:skip=CKV_AWS_111:Key policy: Resource * significa esta chave (DECISIONS D-13)
  #checkov:skip=CKV_AWS_356:Key policy: Resource * significa esta chave (DECISIONS D-13)
  for_each = local.regions

  statement {
    sid       = "KeyAdministration"
    effect    = "Allow"
    actions   = local.key_admin_actions
    resources = ["*"] # numa key policy, "*" significa "esta chave"

    principals {
      type        = "AWS"
      identifiers = [local.account_root]
    }
  }

  statement {
    sid       = "UseOnlyThroughRdsAndS3"
    effect    = "Allow"
    actions   = local.key_usage_actions
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [local.account_root]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["rds.${each.value}.amazonaws.com", "s3.${each.value}.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [local.account_id]
    }
  }

  # RDS e S3 criam "grants" para usar a chave em segundo plano (backups, replicas, replicacao).
  # So permitimos grant para um recurso da AWS, nunca para uma pessoa.
  statement {
    sid       = "AllowGrantsForAwsResources"
    effect    = "Allow"
    actions   = ["kms:CreateGrant", "kms:ListGrants", "kms:RevokeGrant"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [local.account_root]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["rds.${each.value}.amazonaws.com", "s3.${each.value}.amazonaws.com"]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

data "aws_iam_policy_document" "logs_key" {
  #checkov:skip=CKV_AWS_109:Key policy: Resource * significa esta chave; a restricao vem dos principals e conditions (DECISIONS D-13)
  #checkov:skip=CKV_AWS_111:Key policy: Resource * significa esta chave (DECISIONS D-13)
  #checkov:skip=CKV_AWS_356:Key policy: Resource * significa esta chave (DECISIONS D-13)
  for_each = local.regions

  statement {
    sid       = "KeyAdministration"
    effect    = "Allow"
    actions   = local.key_admin_actions
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [local.account_root]
    }
  }

  # O CloudWatch Logs usa a chave em nome do log group. A condicao limita a log groups
  # do projeto: /<projeto>/... e aws-waf-logs-<projeto>... (nome exigido pelo WAF).
  statement {
    sid       = "AllowCloudWatchLogs"
    effect    = "Allow"
    actions   = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${each.value}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "arn:aws:logs:${each.value}:${local.account_id}:log-group:/${var.project_name}/*",
        "arn:aws:logs:${each.value}:${local.account_id}:log-group:aws-waf-logs-${var.project_name}*",
      ]
    }
  }

  # CloudTrail criptografa os arquivos da trilha com esta chave. As condicoes limitam
  # a trilhas desta conta cujo nome comeca com o nome do projeto.
  statement {
    sid       = "AllowCloudTrailEncrypt"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudtrail:*:${local.account_id}:trail/${var.project_name}-*"]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:aws:cloudtrail:*:${local.account_id}:trail/*"]
    }
  }

  statement {
    sid       = "AllowCloudTrailDescribe"
    effect    = "Allow"
    actions   = ["kms:DescribeKey"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  # O bucket de auditoria (S3) e criptografado com esta chave. Quem grava nele (por exemplo
  # a role do AWS Config) usa a chave via S3, e so se o IAM tambem permitir.
  statement {
    sid       = "AllowAuditBucketThroughS3"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey*", "kms:Decrypt", "kms:DescribeKey"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [local.account_root]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${each.value}.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [local.account_id]
    }
  }
}

# ==========================================
# CHAVE DE DADOS (Aurora e S3): multi-region
# ==========================================
# Chave multi-region: a chave primaria fica em sa-east-1 e a REPLICA em us-east-1 tem o
# mesmo ID e o mesmo material criptografico. Assim, dado criptografado numa regiao pode
# ser descriptografado na outra sem reencriptar (base do Aurora Global e do S3 CRR).

resource "aws_kms_key" "data" {
  description             = "Chave de dados multi-region (Aurora e S3) - primaria em ${local.regions.primary}"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true # troca o material criptografico todo ano, sozinha
  multi_region            = true
  policy                  = data.aws_iam_policy_document.data_key["primary"].json

  tags = {
    Name = "${var.project_name}-data-key"
  }
}

resource "aws_kms_alias" "data" {
  name          = "alias/${var.project_name}-data"
  target_key_id = aws_kms_key.data.key_id
}

resource "aws_kms_replica_key" "data" {
  provider = aws.dr

  description             = "Chave de dados multi-region (Aurora e S3) - replica em ${local.regions.dr}"
  deletion_window_in_days = var.deletion_window_in_days
  primary_key_arn         = aws_kms_key.data.arn
  policy                  = data.aws_iam_policy_document.data_key["dr"].json

  tags = {
    Name = "${var.project_name}-data-key-replica"
  }
}

resource "aws_kms_alias" "data_dr" {
  provider = aws.dr

  name          = "alias/${var.project_name}-data"
  target_key_id = aws_kms_replica_key.data.key_id
}

# ==========================================
# CHAVE DE LOGS (Flow Logs, CloudTrail, WAF): multi-region
# ==========================================
# Separada da chave de dados: se uma vazar ou for desativada, a outra nao e afetada,
# e cada uma tem sua propria trilha no CloudTrail.

resource "aws_kms_key" "logs" {
  description             = "Chave de logs multi-region - primaria em ${local.regions.primary}"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true
  multi_region            = true
  policy                  = data.aws_iam_policy_document.logs_key["primary"].json

  tags = {
    Name = "${var.project_name}-logs-key"
  }
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.project_name}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

resource "aws_kms_replica_key" "logs" {
  provider = aws.dr

  description             = "Chave de logs multi-region - replica em ${local.regions.dr}"
  deletion_window_in_days = var.deletion_window_in_days
  primary_key_arn         = aws_kms_key.logs.arn
  policy                  = data.aws_iam_policy_document.logs_key["dr"].json

  tags = {
    Name = "${var.project_name}-logs-key-replica"
  }
}

resource "aws_kms_alias" "logs_dr" {
  provider = aws.dr

  name          = "alias/${var.project_name}-logs"
  target_key_id = aws_kms_replica_key.logs.key_id
}
