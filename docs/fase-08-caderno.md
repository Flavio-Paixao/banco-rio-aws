# Fase 8: segurança e auditoria (BRI-9)

**Plan esperado:** `Plan: 139 to add, 0 to change, 0 to destroy` (98 das fases anteriores mais 41 desta). É uma contagem estimada; o número real é o do seu `plan`.

**Horas estimadas:** 8.

## 1. Conceito

### Prevenir, detectar, auditar

- **Prevenir:** KMS, security groups, WAF, bloqueio de acesso público (fases anteriores).
- **Detectar:** GuardDuty e Security Hub.
- **Auditar:** CloudTrail e Config. Respondem "quem fez o quê, quando" e "como estava configurado".

### CloudTrail

Registra as chamadas de API da conta. Os **eventos de gerenciamento** mostram quem criou, alterou ou apagou recursos. Os **eventos de dados** mostram acessos a objetos do S3 (cobram por volume). A **validação de integridade** gera uma assinatura dos arquivos para detectar adulteração. Uma trilha **multi-região** cobre todas as regiões, inclusive as que não usamos (por onde um atacante poderia agir).

### AWS Config

Grava como cada recurso está configurado ao longo do tempo e avalia **regras** (por exemplo, "todo bucket S3 só aceita HTTPS"). Mostra o desvio, não corrige sozinho.

### GuardDuty

Analisa CloudTrail, logs de DNS e Flow Logs com inteligência de ameaças e gera **achados** (por exemplo, credenciais usadas de um lugar incomum). Não precisa instalar agente.

### Security Hub

Reúne os achados (do GuardDuty e do Config, entre outros) e roda **checagens** de boas práticas, como o padrão AWS Foundational Security Best Practices. Ele mostra pontos de atenção; ativar um padrão **não prova** conformidade com nenhuma regulação.

## 2. Serviços que não usamos nesta fase

- **Organization trail e Security Lake:** pertencem ao escopo B (multi-conta).
- **CloudTrail Insights e CloudTrail Lake:** custo extra, sem necessidade aqui.
- **IAM Access Analyzer:** barato e útil; fica como próximo passo.
- **Macie e Inspector:** D-07.
- **Detective e Audit Manager:** investigação e relatórios de auditoria; maiores que o escopo.
- **Network Firewall:** inspeção de tráfego na VPC; outro objetivo.
- **Conformance packs e remediação automática do Config:** só com um conjunto de regras mais maduro.

## 3. O que há nesta fase

| Parte | Recursos | Qtd |
| --- | --- | --- |
| Bucket de auditoria (bucket, bloqueio público, versionamento, criptografia, ciclo de vida, policy) | 6 | 6 |
| Trilha do CloudTrail, log group, role e política da role | 4 | 4 |
| AWS Config por região (role, anexo, política, gravador, canal, status, 4 regras) | 10 × 2 | 20 |
| GuardDuty por região (detector e 2 proteções) | 3 × 2 | 6 |
| Security Hub por região (conta e padrão) | 2 × 2 | 4 |
| Agregador do Security Hub (só na primária) | 1 | 1 |
| **Total** | | **41** |

Arquivos: `terraform/modules/audit_trail/`, `config_recorder/` e `threat_detection/` (novos), `terraform/modules/kms/main.tf` (key policy da chave de logs), `terraform/main.tf` e `outputs.tf`, `docs/DECISIONS.md` (D-18) e este caderno.

## 4. Limites do que o plan prova

O `plan` mostra que o Terraform entende a configuração. Ele **não prova** que o Config consegue entregar no bucket criptografado, que as condições da key policy do CloudTrail batem, que as regras passam, nem que o GuardDuty gera achados. Também **não mede** custo: GuardDuty, Config e os data events cobram por volume.

Um limite de desenho: o bucket de auditoria existe só em sa-east-1 e não é replicado (D-18).

## 5. Execução (você roda)

Nunca `terraform apply`. Rode a partir da **raiz** do repositório; o `cd terraform` acontece uma vez só.

```bash
cd ~/projetos/banco-rio-aws
git status          # a Fase 7 deve estar commitada e o status limpo
git switch -c BRI-42-seguranca-auditoria

unzip -o ~/Downloads/banco-rio-aws-fase-8.zip -d /tmp/fase8
cp -r /tmp/fase8/banco-rio-aws/. .

cd terraform
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan -no-color 2>&1 | tail -60
cd ..
```

Cole o `validate` e o final do `plan`. Se algo der erro, cole a mensagem inteira.

## 6. Git e Jira

- Tickets: **BRI-42** (CloudTrail multi-região), **BRI-43** (GuardDuty), **BRI-44** (Security Hub) e **BRI-45** (AWS Config).
- Branch: `BRI-42-seguranca-auditoria`
- Commit: `BRI-42 BRI-43 BRI-44 BRI-45: cria cloudtrail, guardduty, security hub e config`

## 7. Checklist

- [ ] Fase 7 commitada e o `git status` limpo
- [ ] Arquivos copiados por cima do repositório
- [ ] `fmt -check`, `init` e `validate` sem erro
- [ ] `plan`: `Plan: 139 to add`
- [ ] Uma `aws_cloudtrail` com `is_multi_region_trail = true` no plan
- [ ] Dois `aws_guardduty_detector`, dois `aws_securityhub_account` e dois `aws_config_configuration_recorder`
- [ ] Saída do `plan` anexada aos tickets

## 8. Ligação com a prova (SAA)

- CloudTrail: eventos de gerenciamento e de dados, validação de integridade, trilha multi-região
- Config: regras, linha do tempo de configuração
- GuardDuty e Security Hub: detecção e visão centralizada
- Modelo de responsabilidade compartilhada e defesa em camadas

## 9. Para explicar em entrevista

- **Qual a diferença entre CloudTrail e Config?** O CloudTrail registra as ações (quem fez), e o Config registra o estado dos recursos (como ficou).
- **Por que a trilha é multi-região?** Para registrar atividade também nas regiões que não usamos.
- **Isso torna o banco conforme a BACEN ou LGPD?** Não. É um desenho alinhado a boas práticas de auditoria; conformidade depende de processos, políticas e auditoria externa.
- **Qual é o ponto fraco desta fase?** O bucket de auditoria está só numa região e numa conta. No escopo B, ele iria para uma conta separada de logs.
