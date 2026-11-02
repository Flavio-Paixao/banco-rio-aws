data "aws_region" "primary" {}

data "aws_region" "dr" {
  provider = aws.dr
}

# ==========================================
# BUCKET DE ORIGEM (sa-east-1)
# ==========================================
# bucket_prefix: o Terraform acrescenta um sufixo aleatorio.
# (Nomes de bucket sao unicos no mundo; um nome fixo poderia ja estar em uso.)

resource "aws_s3_bucket" "source" {
  #checkov:skip=CKV_AWS_18:Sem server access logging no S3; a trilha de acessos vem do CloudTrail da fase 8 (DECISIONS D-15)
  #checkov:skip=CKV2_AWS_62:Sem consumidor de eventos (DECISIONS D-15)
  bucket_prefix = "${var.project_name}-dados-primario-"

  tags = {
    Name = "${var.project_name}-dados-primario"
  }
}

resource "aws_s3_bucket_public_access_block" "source" {
  bucket = aws_s3_bucket.source.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versionamento: obrigatorio para a replicacao e guarda o historico de cada arquivo
resource "aws_s3_bucket_versioning" "source" {
  bucket = aws_s3_bucket.source.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Criptografia em repouso com a NOSSA chave KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "source" {
  bucket = aws_s3_bucket.source.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.primary_kms_key_arn
    }
    bucket_key_enabled = true # reduz chamadas ao KMS (e o custo)
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "source" {
  bucket = aws_s3_bucket.source.id

  rule {
    id     = "arquivar-versoes-antigas"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = var.noncurrent_glacier_days
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # O ciclo de vida de versoes precisa que o versionamento ja exista
  depends_on = [aws_s3_bucket_versioning.source]
}

# ==========================================
# BUCKET DE DESTINO (us-east-1)
# ==========================================

resource "aws_s3_bucket" "destination" {
  #checkov:skip=CKV_AWS_144:Este e o bucket de destino da replicacao; replicar de volta nao e necessario (DECISIONS D-15)
  #checkov:skip=CKV_AWS_18:Sem server access logging no S3; a trilha de acessos vem do CloudTrail da fase 8 (DECISIONS D-15)
  #checkov:skip=CKV2_AWS_62:Sem consumidor de eventos (DECISIONS D-15)
  provider = aws.dr

  bucket_prefix = "${var.project_name}-dados-dr-"

  tags = {
    Name = "${var.project_name}-dados-dr"
  }
}

resource "aws_s3_bucket_public_access_block" "destination" {
  provider = aws.dr

  bucket = aws_s3_bucket.destination.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "destination" {
  provider = aws.dr

  bucket = aws_s3_bucket.destination.id

  versioning_configuration {
    status = "Enabled"
  }
}

# O destino usa a REPLICA da chave, na regiao de DR
resource "aws_s3_bucket_server_side_encryption_configuration" "destination" {
  provider = aws.dr

  bucket = aws_s3_bucket.destination.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.dr_kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "destination" {
  provider = aws.dr

  bucket = aws_s3_bucket.destination.id

  rule {
    id     = "arquivar-versoes-antigas"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = var.noncurrent_glacier_days
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.destination]
}

# ==========================================
# POLICY: NEGAR QUALQUER ACESSO SEM HTTPS (nos dois buckets)
# ==========================================

data "aws_iam_policy_document" "tls_source" {
  statement {
    sid       = "NegarTrafegoSemTLS"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.source.arn, "${aws_s3_bucket.source.arn}/*"]

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

data "aws_iam_policy_document" "tls_destination" {
  statement {
    sid       = "NegarTrafegoSemTLS"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.destination.arn, "${aws_s3_bucket.destination.arn}/*"]

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

resource "aws_s3_bucket_policy" "source" {
  bucket = aws_s3_bucket.source.id
  policy = data.aws_iam_policy_document.tls_source.json

  # A policy so e aplicada depois do bloqueio de acesso publico (evita conflito de ordem)
  depends_on = [aws_s3_bucket_public_access_block.source]
}

resource "aws_s3_bucket_policy" "destination" {
  provider = aws.dr

  bucket = aws_s3_bucket.destination.id
  policy = data.aws_iam_policy_document.tls_destination.json

  depends_on = [aws_s3_bucket_public_access_block.destination]
}

# ==========================================
# ROLE DE REPLICACAO (minimo privilegio)
# ==========================================
# O S3 assume esta role para ler as versoes da origem, gravar no destino e usar as
# duas chaves KMS. Sem esta role (e sem as permissoes de KMS) a replicacao de objetos
# criptografados com KMS falha.

data "aws_iam_policy_document" "replication_assume" {
  statement {
    sid     = "S3AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replication" {
  name               = "${var.project_name}-s3-replicacao"
  assume_role_policy = data.aws_iam_policy_document.replication_assume.json

  tags = {
    Name = "${var.project_name}-s3-replicacao"
  }
}

data "aws_iam_policy_document" "replication" {
  statement {
    sid       = "LerConfiguracaoDaOrigem"
    effect    = "Allow"
    actions   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
    resources = [aws_s3_bucket.source.arn]
  }

  statement {
    sid       = "LerVersoesDaOrigem"
    effect    = "Allow"
    actions   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
    resources = ["${aws_s3_bucket.source.arn}/*"]
  }

  statement {
    sid       = "GravarNoDestino"
    effect    = "Allow"
    actions   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
    resources = ["${aws_s3_bucket.destination.arn}/*"]
  }

  # Com Bucket Keys ligadas, o contexto de criptografia usa o ARN do BUCKET;
  # sem elas, usa o ARN do objeto. Os dois padroes ficam permitidos.
  statement {
    sid       = "DescriptografarNaOrigem"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.primary_kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${data.aws_region.primary.name}.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values   = [aws_s3_bucket.source.arn, "${aws_s3_bucket.source.arn}/*"]
    }
  }

  statement {
    sid       = "CriptografarNoDestino"
    effect    = "Allow"
    actions   = ["kms:Encrypt", "kms:GenerateDataKey"]
    resources = [var.dr_kms_key_arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${data.aws_region.dr.name}.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values   = [aws_s3_bucket.destination.arn, "${aws_s3_bucket.destination.arn}/*"]
    }
  }
}

resource "aws_iam_role_policy" "replication" {
  name   = "replicar-dados"
  role   = aws_iam_role.replication.id
  policy = data.aws_iam_policy_document.replication.json
}

# ==========================================
# REPLICACAO ENTRE REGIOES (CRR)
# ==========================================

resource "aws_s3_bucket_replication_configuration" "data" {
  bucket = aws_s3_bucket.source.id
  role   = aws_iam_role.replication.arn

  rule {
    id     = "replicar-tudo-para-o-dr"
    status = "Enabled"

    filter {}

    # Replica tambem as marcas de exclusao (delete markers)
    delete_marker_replication {
      status = "Enabled"
    }

    # Objetos criptografados com KMS so sao replicados com esta opcao ligada
    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    destination {
      bucket        = aws_s3_bucket.destination.arn
      storage_class = "STANDARD"

      encryption_configuration {
        replica_kms_key_id = var.dr_kms_key_arn
      }
    }
  }

  # O versionamento dos dois buckets precisa existir antes da regra
  depends_on = [
    aws_s3_bucket_versioning.source,
    aws_s3_bucket_versioning.destination,
  ]
}
