# Fase 1: so consultas (data sources), nenhum recurso e criado.
# Elas provam que as credenciais funcionam nas duas regioes e que o provider
# com apelido (aws.dr) esta ligado. As AZs serao usadas pelo modulo de rede (fase 2).

data "aws_availability_zones" "primary" {
  state = "available"
}

data "aws_availability_zones" "dr" {
  provider = aws.dr

  state = "available"
}
