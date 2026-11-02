data "aws_region" "primary" {}

data "aws_region" "dr" {
  provider = aws.dr
}

# ==========================================
# CLASSE DA INSTANCIA (conferida na AWS, nas duas regioes)
# ==========================================
# O plan nao confere se a classe existe para este motor e versao. Estes data sources
# perguntam a AWS, em cada regiao, se a combinacao motor + versao + classe pode ser
# criada, se aceita Global Database e se suporta Performance Insights e Enhanced
# Monitoring. Se nao puder, o plan falha aqui, com uma mensagem clara.

data "aws_rds_orderable_db_instance" "primary" {
  engine                     = "aurora-postgresql"
  engine_version             = var.engine_version
  preferred_instance_classes = var.instance_classes

  supports_global_databases     = true
  supports_performance_insights = true
  supports_enhanced_monitoring  = true
}

data "aws_rds_orderable_db_instance" "dr" {
  provider = aws.dr

  engine                     = "aurora-postgresql"
  engine_version             = var.engine_version
  preferred_instance_classes = var.instance_classes

  supports_global_databases     = true
  supports_performance_insights = true
  supports_enhanced_monitoring  = true
}

# ==========================================
# SENHA DO ADMINISTRADOR (Secrets Manager, replicado para o DR)
# ==========================================
# O Secrets Manager NAO gerencia a senha de clusters que fazem parte de um Global
# Database (documentacao da AWS), entao a senha e gerada aqui e guardada num segredo
# criptografado com a chave de dados. O segredo e replicado para a regiao de DR.
# A senha tambem fica no state (local e fora do git); veja DECISIONS D-14.

resource "random_password" "master" {
  length  = 32
  special = true
  # O Aurora PostgreSQL nao aceita / " @ nem espaco na senha
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "master" {
  #checkov:skip=CKV2_AWS_57:Rotacao automatica exige uma Lambda; fica so no desenho (DECISIONS D-14)
  name                    = "${var.project_name}/aurora/master"
  description             = "Credenciais do administrador do Aurora Global Database"
  kms_key_id              = var.primary_kms_key_arn
  recovery_window_in_days = 7

  replica {
    region     = data.aws_region.dr.name
    kms_key_id = var.dr_kms_key_arn
  }

  tags = {
    Name = "${var.project_name}-aurora-master"
  }
}

resource "aws_secretsmanager_secret_version" "master" {
  secret_id = aws_secretsmanager_secret.master.id

  secret_string = jsonencode({
    engine   = "aurora-postgresql"
    port     = 5432
    dbname   = var.db_name
    username = var.db_username
    password = random_password.master.result
  })
}

# ==========================================
# ROLE DO ENHANCED MONITORING (IAM e global: uma role serve as duas regioes)
# ==========================================

data "aws_iam_policy_document" "monitoring_assume" {
  statement {
    sid     = "RdsMonitoringAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  name               = "${var.project_name}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json

  tags = {
    Name = "${var.project_name}-rds-monitoring"
  }
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ==========================================
# GLOBAL CLUSTER
# ==========================================

resource "aws_rds_global_cluster" "main" {
  global_cluster_identifier = "${var.project_name}-global"
  engine                    = "aurora-postgresql"
  engine_version            = var.engine_version
  database_name             = var.db_name
  storage_encrypted         = true

  # PROJETO DE ESTUDO: permite destruir sem travar.
  deletion_protection = false
}

# ==========================================
# REGIAO PRIMARIA (sa-east-1): cluster com writer e reader
# ==========================================

resource "aws_db_subnet_group" "primary" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.primary_private_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_rds_cluster_parameter_group" "primary" {
  name        = "${var.project_name}-aurora-cluster-pg"
  family      = "aurora-postgresql15"
  description = "Parametros customizados do Aurora PostgreSQL"

  # Registra so comandos que alteram estrutura (CREATE, ALTER, DROP).
  # "all" geraria log gigante e custo no CloudWatch.
  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  # Registra consultas que demoram mais de 1 segundo (valor em milissegundos)
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = {
    Name = "${var.project_name}-aurora-cluster-pg"
  }
}

resource "aws_rds_cluster" "primary" {
  #checkov:skip=CKV2_AWS_8:O plano do AWS Backup esta no modulo backup (DECISIONS D-19); o checkov nao liga recursos de modulos diferentes
  #checkov:skip=CKV_AWS_139:Projeto de estudo precisa poder ser destruido (DECISIONS D-14)
  cluster_identifier        = "${var.project_name}-aurora-primary"
  global_cluster_identifier = aws_rds_global_cluster.main.id
  engine                    = aws_rds_global_cluster.main.engine
  engine_version            = aws_rds_global_cluster.main.engine_version
  database_name             = var.db_name

  # SENHA: gerada por random_password e guardada no Secrets Manager. Nada no codigo.
  master_username = var.db_username
  master_password = random_password.master.result

  # Rede
  db_subnet_group_name            = aws_db_subnet_group.primary.name
  vpc_security_group_ids          = [var.primary_db_security_group_id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.primary.name

  # Backup e manutencao (horarios em UTC; nao podem se sobrepor)
  backup_retention_period      = var.backup_retention_days
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:05:00-sun:06:00"
  copy_tags_to_snapshot        = true

  # Logs do PostgreSQL vao para o CloudWatch
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Criptografia em repouso com a NOSSA chave
  storage_encrypted = true
  kms_key_id        = var.primary_kms_key_arn

  # Autenticacao por token IAM (opcional, fica habilitada)
  iam_database_authentication_enabled = true

  # PROJETO DE ESTUDO: permite destruir sem travar.
  # EM PRODUCAO REAL: deletion_protection = true e skip_final_snapshot = false
  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Name = "${var.project_name}-aurora-primary"
  }

  # Versoes menores sao tratadas pelo global cluster; sem isto o Terraform brigaria com a AWS.
  lifecycle {
    ignore_changes = [engine_version]
  }
}

resource "aws_rds_cluster_instance" "primary_writer" {
  identifier         = "${var.project_name}-aurora-primary-writer"
  cluster_identifier = aws_rds_cluster.primary.id
  engine             = aws_rds_cluster.primary.engine
  engine_version     = aws_rds_cluster.primary.engine_version
  instance_class     = data.aws_rds_orderable_db_instance.primary.instance_class
  availability_zone  = var.primary_azs[0]

  db_subnet_group_name       = aws_db_subnet_group.primary.name
  publicly_accessible        = false # sem IP publico; e as subnets privadas nao tem rota para o IGW
  auto_minor_version_upgrade = false # nao se aplica a clusters de Global Database

  # Enhanced Monitoring: metricas do sistema operacional a cada 60 s
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.monitoring.arn

  # Performance Insights: painel que mostra quais consultas pesam mais
  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.primary_kms_key_arn

  tags = {
    Name = "${var.project_name}-aurora-primary-writer"
  }

  lifecycle {
    ignore_changes = [engine_version]
  }
}

# Reader na outra AZ. Se o writer cair, ele assume (promotion_tier = 1).
resource "aws_rds_cluster_instance" "primary_reader" {
  identifier         = "${var.project_name}-aurora-primary-reader"
  cluster_identifier = aws_rds_cluster.primary.id
  engine             = aws_rds_cluster.primary.engine
  engine_version     = aws_rds_cluster.primary.engine_version
  instance_class     = data.aws_rds_orderable_db_instance.primary.instance_class
  availability_zone  = var.primary_azs[1]
  promotion_tier     = 1

  db_subnet_group_name       = aws_db_subnet_group.primary.name
  publicly_accessible        = false
  auto_minor_version_upgrade = false

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.monitoring.arn

  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.primary_kms_key_arn

  tags = {
    Name = "${var.project_name}-aurora-primary-reader"
  }

  # Garante que o writer seja criado primeiro
  depends_on = [aws_rds_cluster_instance.primary_writer]

  lifecycle {
    ignore_changes = [engine_version]
  }
}

# ==========================================
# REGIAO DE DR (us-east-1): cluster secundario, somente leitura
# ==========================================
# Replica os dados do primario. Num failover regional, ele e promovido a primario.

resource "aws_db_subnet_group" "dr" {
  provider = aws.dr

  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.dr_private_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_rds_cluster_parameter_group" "dr" {
  provider = aws.dr

  name        = "${var.project_name}-aurora-cluster-pg"
  family      = "aurora-postgresql15"
  description = "Parametros customizados do Aurora PostgreSQL"

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = {
    Name = "${var.project_name}-aurora-cluster-pg"
  }
}

resource "aws_rds_cluster" "secondary" {
  #checkov:skip=CKV2_AWS_8:O plano do AWS Backup esta no modulo backup (DECISIONS D-19); o checkov nao liga recursos de modulos diferentes
  #checkov:skip=CKV_AWS_139:Projeto de estudo precisa poder ser destruido (DECISIONS D-14)
  provider = aws.dr

  cluster_identifier        = "${var.project_name}-aurora-secondary"
  global_cluster_identifier = aws_rds_global_cluster.main.id
  engine                    = aws_rds_global_cluster.main.engine
  engine_version            = aws_rds_global_cluster.main.engine_version

  # Cluster secundario nao tem usuario nem senha proprios: herda do primario.

  db_subnet_group_name            = aws_db_subnet_group.dr.name
  vpc_security_group_ids          = [var.dr_db_security_group_id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.dr.name

  backup_retention_period         = var.backup_retention_days
  copy_tags_to_snapshot           = true
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Criptografia com a REPLICA da chave de dados, na regiao de DR.
  # source_region e exigido pela AWS para o secundario criptografado.
  storage_encrypted = true
  kms_key_id        = var.dr_kms_key_arn
  source_region     = data.aws_region.primary.name

  iam_database_authentication_enabled = true

  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Name = "${var.project_name}-aurora-secondary"
  }

  # O secundario so pode ser criado depois da instancia writer do primario
  depends_on = [aws_rds_cluster_instance.primary_writer]

  lifecycle {
    ignore_changes = [engine_version, replication_source_identifier]
  }
}

resource "aws_rds_cluster_instance" "secondary" {
  provider = aws.dr

  identifier         = "${var.project_name}-aurora-secondary-reader"
  cluster_identifier = aws_rds_cluster.secondary.id
  engine             = aws_rds_cluster.secondary.engine
  engine_version     = aws_rds_cluster.secondary.engine_version
  instance_class     = data.aws_rds_orderable_db_instance.dr.instance_class

  db_subnet_group_name       = aws_db_subnet_group.dr.name
  publicly_accessible        = false
  auto_minor_version_upgrade = false

  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.monitoring.arn

  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.dr_kms_key_arn

  tags = {
    Name = "${var.project_name}-aurora-secondary-reader"
  }

  lifecycle {
    ignore_changes = [engine_version]
  }
}
