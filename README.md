# Banco Rio: infraestrutura AWS em Terraform

Case 3 do meu portfólio de arquitetura AWS: um banco **fictício** com alta disponibilidade, proteção de dados sensíveis, auditoria de acessos e recuperação de desastre (DR) entre duas regiões, escrito em Terraform com módulos.

> **Projeto de estudo.** O código é validado com `terraform fmt`, `validate` e `plan`. Nunca foi aplicado (`apply`), então não há ambiente rodando e nenhum número de disponibilidade, RPO ou RTO foi medido. Os valores de RPO e RTO citados na documentação são **metas de projeto**.

## Escopo

Resiliência e recuperação de desastre, numa conta só:

- Região primária **sa-east-1** (São Paulo) e região de DR **us-east-1** (N. Virginia)
- Aurora PostgreSQL Global Database
- Route 53 com failover
- S3 com replicação entre regiões
- KMS, WAF, CloudTrail, GuardDuty, Security Hub e AWS Config
- AWS Backup e monitoramento

Shield Advanced, CloudHSM e VPN dedicada ficam só no desenho e na análise de custo.

## Status

| Fase | Entrega | Situação |
| --- | --- | --- |
| 0 | Escopo e plano | Concluída |
| 1 | Base do repositório e providers das duas regiões | Concluída |
| 2 | Rede nas duas regiões | Em andamento |
| 3 a 10 | KMS, Aurora, S3, borda, DNS, segurança, backup e monitoramento, documentação | Não iniciadas |

## Como validar

```bash
cd terraform
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
```

Este projeto não usa `terraform apply`.

## Documentação

- [docs/DECISIONS.md](docs/DECISIONS.md): decisões, o que foi usado, o que não foi e por quê
- `docs/fase-XX-caderno.md`: caderno de cada fase

Estrutura, ARCHITECTURE, COST-ANALYSIS e diagrama entram na fase 10.
