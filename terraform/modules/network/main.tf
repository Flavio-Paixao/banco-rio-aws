# ==========================================
# VPC
# ==========================================

resource "aws_vpc" "main" {
  #checkov:skip=CKV2_AWS_11:Flow Logs entram na fase 3, depois da chave KMS de logs (DECISIONS D-11)
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-${var.region_label}-vpc"
  }
}

# Assume o SG default da VPC e remove todas as regras dele.
# Nada usa o default; sem regras, um recurso criado sem SG fica isolado.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.region_label}-default-sg-bloqueado"
  }
}

# ==========================================
# INTERNET GATEWAY
# ==========================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.region_label}-igw"
  }
}

# ==========================================
# SUBNETS (2 publicas + 2 privadas, uma de cada tipo por AZ)
# ==========================================
# Para 10.0.0.0/16: publicas 10.0.1.0/24 e 10.0.2.0/24; privadas 10.0.11.0/24 e 10.0.12.0/24.

resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = false # o ALB gerencia os proprios IPs

  tags = {
    Name = "${var.project_name}-${var.region_label}-public-${var.azs[count.index]}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 11)
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.project_name}-${var.region_label}-private-${var.azs[count.index]}"
    Tier = "private"
  }
}

# ==========================================
# ROUTE TABLES
# ==========================================

# Publica: o que torna a subnet "publica" e esta rota 0.0.0.0/0 -> IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-${var.region_label}-public-rt"
  }
}

# Privada: sem rota para a internet (nao ha NAT Gateway, DECISIONS D-04).
# So existe a rota local da VPC, criada pela AWS.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.region_label}-private-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ==========================================
# SECURITY GROUPS
# ==========================================

# Entrada da internet para o ALB (anexado na fase 6)
resource "aws_security_group" "alb" {
  #checkov:skip=CKV2_AWS_5:Falso positivo: o SG e anexado ao ALB na fase 6
  #checkov:skip=CKV_AWS_260:ALB publico precisa aceitar HTTP:80 da internet (DECISIONS D-10)
  name        = "${var.project_name}-${var.region_label}-alb-sg"
  description = "Entrada da internet para o ALB (HTTP e HTTPS)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP da internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS da internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Sem bloco egress de proposito: o ALB responde com resposta fixa e nao fala com backend.
  # O Terraform remove a regra "tudo liberado" que a AWS cria por padrao.

  tags = {
    Name = "${var.project_name}-${var.region_label}-alb-sg"
  }
}

# Banco de dados (anexado ao Aurora na fase 4)
resource "aws_security_group" "db" {
  #checkov:skip=CKV2_AWS_5:Falso positivo: o SG e anexado ao Aurora na fase 4
  name        = "${var.project_name}-${var.region_label}-db-sg"
  description = "Aurora PostgreSQL: aceita conexoes so das subnets privadas"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "PostgreSQL somente das subnets privadas (DECISIONS D-10)"
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = aws_subnet.private[*].cidr_block
  }

  # Sem bloco egress de proposito: o banco nao inicia conexoes.
  # SG e stateful, entao as respostas as conexoes recebidas continuam saindo.

  tags = {
    Name = "${var.project_name}-${var.region_label}-db-sg"
  }
}
