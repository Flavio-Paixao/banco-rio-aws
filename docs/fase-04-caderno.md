# Fase 4: Aurora Global Database (BRI-5)

**Plan esperado:** `Plan: 61 to add, 0 to change, 0 to destroy` (46 das fases anteriores mais 15 desta). É uma contagem estimada; o número real é o do seu `plan`.

**Horas estimadas:** 9.

## 1. Conceito

### Aurora e Aurora Global Database

O Aurora separa computação (instâncias) de armazenamento (um volume que se replica em 6 cópias em 3 AZs). Um **cluster** tem um writer e até 15 readers que leem o mesmo volume. O **Global Database** liga clusters de regiões diferentes: o volume do primário é replicado para as regiões secundárias por infraestrutura dedicada, com latência que a AWS descreve como tipicamente abaixo de um segundo.

### RPO e RTO (metas, não medições)

- **RPO:** quanto de dado posso perder. **RTO:** quanto tempo posso ficar fora.
- Neste case, as metas de projeto são RPO na ordem de segundos e RTO na faixa de minutos. **São metas; nada foi medido**, porque o projeto nunca recebe `apply`.

### Failover e switchover

- **Switchover:** troca planejada da região primária, sem perda de dados.
- **Failover:** recuperação depois de uma queda da região primária; pode perder o que ainda não foi replicado.

### Senha do administrador

O Secrets Manager não gerencia a senha de clusters de um Global Database (documentação da AWS). Por isso: `random_password` gera, o Secrets Manager guarda (criptografado, replicado para o DR) e o cluster recebe o valor. O custo é a senha ir para o state (D-14).

## 2. Serviços que não usamos nesta fase

- **Aurora Serverless v2:** o ACU mínimo recomendado para a região primária de um Global Database é 8, o que encarece; fica como alternativa a estudar.
- **RDS Proxy:** sem camada de aplicação, não há pool de conexões a gerenciar.
- **DynamoDB Global Tables:** o banco fictício é relacional.
- **RDS Multi-AZ clássico e réplicas de leitura entre regiões:** o Aurora Global é o recurso próprio para isso.
- **AWS DMS:** serve para migrar bancos; aqui não há origem.
- **Backtrack e Blue/Green:** não suportados com Global Database.

## 3. O que há nesta fase

| Recurso | Qtd |
| --- | --- |
| Global cluster | 1 |
| Cluster primário (sa-east-1), subnet group, parameter group | 3 |
| Instâncias do primário (writer e reader, 2 AZs) | 2 |
| Cluster secundário (us-east-1), subnet group, parameter group | 3 |
| Instância do secundário | 1 |
| Role e anexo do Enhanced Monitoring | 2 |
| `random_password`, segredo (com réplica no DR) e versão do segredo | 3 |
| **Total** | **15** |

Arquivos: `terraform/modules/aurora_global/` (novo), `terraform/main.tf` e `outputs.tf` (chamam o módulo), `terraform/versions.tf` (acrescenta o provider `random`), `docs/DECISIONS.md` (D-05 atualizado e D-14) e este caderno.

## 4. Limites do que o plan prova

O `plan` consulta a AWS para confirmar que motor, versão e classe existem nas duas regiões e aceitam Global Database. Ele **não prova** que a criação do secundário criptografado funciona (o argumento `source_region`), que a réplica do segredo é aceita, nem os tempos de replicação e de failover. Só um `apply` provaria, e o projeto não o faz.

## 5. Execução (você roda)

Nunca `terraform apply`.

```bash
cd terraform
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
cd ..
```

O `init` baixa o provider `random` e **atualiza o `.terraform.lock.hcl`**: faça commit dele, senão o CI (que usa `-lockfile=readonly`) vai falhar.

Se o `plan` falhar nos data sources `aws_rds_orderable_db_instance`, é a checagem funcionando: cole a mensagem inteira. A causa provável é versão ou classe indisponível numa das regiões, e a correção é trocar `engine_version` ou `instance_classes`.

## 6. Git e Jira

- Tickets: **BRI-27** (adaptar o módulo), **BRI-28** (primário), **BRI-29** (secundário) e **BRI-30** (senha do banco, já resolvido: o Secrets Manager não gerencia senha de Global Database).
- Branch: `BRI-27-aurora-global`
- Commit: `BRI-27 BRI-28 BRI-29 BRI-30: cria aurora global database`

## 7. Checklist

- [ ] Fase 3 mergeada na `main`
- [ ] Arquivos copiados por cima do repositório
- [ ] `fmt -check`, `init` e `validate` sem erro
- [ ] `plan`: `Plan: 61 to add`
- [ ] Nenhuma senha visível no `plan` (a senha aparece como `(sensitive value)`)
- [ ] `.terraform.lock.hcl` atualizado e commitado
- [ ] Saída do `plan` anexada aos tickets

## 8. Ligação com a prova (SAA)

- Aurora: arquitetura de armazenamento, writer e readers, endpoints
- Aurora Global Database, RPO e RTO, failover entre regiões
- Estratégias de DR (esta fase fecha o *warm standby* do banco)
- Secrets Manager e replicação de segredos; criptografia com KMS

## 9. Para explicar em entrevista

- **Por que Global Database e não uma réplica de leitura entre regiões?** Porque a replicação é feita pela camada de armazenamento, com latência baixa e promoção gerenciada.
- **Por que a senha está no state?** Porque o Secrets Manager não gerencia senha de Global Database. É um limite que assumi e documentei; num ambiente real, o state ficaria num backend criptografado.
- **Qual é o RPO?** É uma meta de projeto, na ordem de segundos, baseada no que a AWS descreve; não foi medido.
- **Por que não `db.t3.medium` como nos outros cases?** A AWS exige classes otimizadas para memória no Global Database e recomenda `db.r5` ou superior.
