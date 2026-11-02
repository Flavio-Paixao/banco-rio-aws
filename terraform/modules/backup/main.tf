data "aws_caller_identity" "current" {}

# ==========================================
# COFRE (BACKUP VAULT)
# ==========================================
# Onde ficam os pontos de recuperacao, criptografados com a chave de dados da regiao.
# A regiao de DR tem o seu proprio cofre, que recebe as copias da primaria.

resource "aws_backup_vault" "main" {
  name        = "${var.project_name}-cofre-${var.region_label}"
  kms_key_arn = var.kms_key_arn

  tags = {
    Name = "${var.project_name}-cofre-${var.region_label}"
  }
}

# ==========================================
# VAULT LOCK EM MODO GOVERNANCE
# ==========================================
# Impede apagar ou encurtar a retencao de um backup fora da faixa min/max, mesmo para quem
# tem permissao de administrador. Sem "changeable_for_days" o modo e GOVERNANCE: quem tem
# permissao especifica ainda consegue remover o lock. O modo COMPLIANCE (irreversivel depois
# da carencia) fica so no desenho (DECISIONS D-19).

resource "aws_backup_vault_lock_configuration" "main" {
  backup_vault_name  = aws_backup_vault.main.name
  min_retention_days = var.lock_min_retention_days
  max_retention_days = var.lock_max_retention_days
}

# ==========================================
# ROLE DO AWS BACKUP (so onde ha plano)
# ==========================================

data "aws_iam_policy_document" "backup_trust" {
  count = var.create_plan ? 1 : 0

  statement {
    sid     = "AllowBackupService"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "backup" {
  count = var.create_plan ? 1 : 0

  name               = "${var.project_name}-backup-${var.region_label}"
  assume_role_policy = data.aws_iam_policy_document.backup_trust[0].json

  tags = {
    Name = "${var.project_name}-backup-${var.region_label}"
  }
}

resource "aws_iam_role_policy_attachment" "backup" {
  count = var.create_plan ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore" {
  count = var.create_plan ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# As politicas gerenciadas nao conhecem as chaves do projeto. Esta politica libera so as
# chaves informadas (a da origem e a do cofre de destino da copia).
data "aws_iam_policy_document" "backup_kms" {
  count = var.create_plan ? 1 : 0

  statement {
    sid    = "UseProjectKeys"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = var.kms_key_arns
  }

  statement {
    sid       = "GrantsForAwsResources"
    effect    = "Allow"
    actions   = ["kms:CreateGrant"]
    resources = var.kms_key_arns

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

resource "aws_iam_role_policy" "backup_kms" {
  count = var.create_plan ? 1 : 0

  name   = "${var.project_name}-backup-kms-${var.region_label}"
  role   = aws_iam_role.backup[0].id
  policy = data.aws_iam_policy_document.backup_kms[0].json
}

# ==========================================
# PLANO E SELECAO
# ==========================================
# Uma regra diaria. Cada ponto de recuperacao fica retention_days dias e, se enable_copy,
# e copiado para o cofre de DR com a mesma retencao.

resource "aws_backup_plan" "main" {
  count = var.create_plan ? 1 : 0

  name = "${var.project_name}-plano-${var.region_label}"

  rule {
    rule_name         = "diario"
    target_vault_name = aws_backup_vault.main.name
    schedule          = var.schedule
    start_window      = 60
    completion_window = 180

    lifecycle {
      delete_after = var.retention_days
    }

    dynamic "copy_action" {
      for_each = var.enable_copy ? [1] : []

      content {
        destination_vault_arn = var.copy_destination_vault_arn

        lifecycle {
          delete_after = var.retention_days
        }
      }
    }
  }

  tags = {
    Name = "${var.project_name}-plano-${var.region_label}"
  }

  depends_on = [aws_backup_vault_lock_configuration.main]
}

resource "aws_backup_selection" "main" {
  count = var.create_plan ? 1 : 0

  name         = "${var.project_name}-recursos-${var.region_label}"
  iam_role_arn = aws_iam_role.backup[0].arn
  plan_id      = aws_backup_plan.main[0].id
  resources    = var.resource_arns

  depends_on = [
    aws_iam_role_policy_attachment.backup,
    aws_iam_role_policy.backup_kms,
  ]
}
