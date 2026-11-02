# Fase 9: backup e monitoramento (BRI-10)

**Plan esperado:** `Plan: 166 to add, 0 to change, 0 to destroy` (139 das fases anteriores mais 27 desta). É uma contagem estimada; o número real é o do seu `plan`.

**Horas estimadas:** 8.

## 1. Conceito

### Backup não é replicação

Replicação copia também o erro: se alguém apaga ou corrompe um dado, a réplica fica igual. **Backup** guarda pontos no tempo e permite voltar. Por isso o projeto usa os dois.

### AWS Backup

Serviço central que agenda backups, guarda os **pontos de recuperação** em **cofres** (*vaults*) e copia entre regiões. Um **plano** diz quando e por quanto tempo; uma **seleção** diz o que proteger.

### Vault Lock

Trava que impede apagar um backup ou encurtar sua retenção fora de uma faixa. **Governance**: ainda pode ser removido por quem tem permissão especial. **Compliance**: depois da carência, é irreversível. Usamos governance.

### Observabilidade

- **Métricas e alarmes (CloudWatch):** medem algo e avisam quando passa de um limiar.
- **EventBridge:** reage a eventos de serviços (um achado do GuardDuty, um backup que falhou).
- **SNS:** distribui o aviso para quem se inscrever.
- **Dashboard:** uma tela com os gráficos importantes.

### Um detalhe de região

As métricas do Route 53 só existem em **us-east-1**, e a métrica de atraso do Aurora Global é publicada na região do **cluster secundário**. Por isso esses dois alarmes nascem no DR.

## 2. Serviços que não usamos nesta fase

- **AWS Backup para S3:** exige políticas extras e confirmar o uso da chave KMS; próximo passo (D-19).
- **Backup contínuo (PITR) do AWS Backup:** o Aurora já tem o dele.
- **Backup Audit Manager:** relatórios de conformidade, fora do escopo.
- **Synthetics, X-Ray, Container Insights:** não há aplicação.
- **AWS Chatbot e Incident Manager:** não há equipe de plantão.
- **Alarmes compostos e detecção de anomalias:** complexidade sem ganho aqui.

## 3. O que há nesta fase

| Parte | Recursos | Qtd |
| --- | --- | --- |
| Cofre e lock no DR | 2 | 2 |
| Cofre e lock na primária | 2 | 2 |
| Role, 2 anexos, política de KMS, plano e seleção (primária) | 6 | 6 |
| Tópico SNS, política, alarme 5xx, 2 regras e 2 alvos (por região) | 7 × 2 | 14 |
| Alarmes de atraso e de health check (DR) | 2 | 2 |
| Painel | 1 | 1 |
| **Total** | | **27** |

Arquivos novos: `terraform/modules/backup/`, `monitoring/` e `dashboard/`. Alterados: `terraform/modules/kms/main.tf` (backup nas condições da chave de dados e SNS na chave de logs), `edge/outputs.tf` e `aurora_global/` (saídas e texto de um skip do checkov), `terraform/main.tf` e `outputs.tf`, `docs/DECISIONS.md` (D-19), o caderno da fase 5 e o README.

## 4. Limites do que o plan prova

O `plan` não prova que o backup roda, que a cópia chega ao DR, que uma restauração funciona nem quanto demora; não prova que os alarmes disparam nem que o SNS entrega. Nenhum RTO ou RPO foi medido. O limiar de 5000 ms do atraso de replicação é um valor de alerta de estudo.

## 5. Perguntas de revisão (SAA)

1. **Qual a diferença entre replicação e backup?** Replicação copia o estado atual, inclusive o erro. Backup guarda pontos no tempo.
2. **Por que o alarme do Route 53 fica em us-east-1?** As métricas do Route 53 só são publicadas lá.
3. **Vault Lock em compliance ou governance?** Compliance é irreversível; governance permite remover o lock com permissão especial.
4. **Um alarme faz o failover?** Não. Ele avisa. O failover do DNS é do Route 53; a promoção do Aurora é um passo à parte.
