# Fase 6: borda com ALB, ACM e WAF (BRI-7)

**Plan esperado:** `Plan: 94 to add, 0 to change, 0 to destroy` (76 das fases anteriores mais 18 desta, 9 por região). É uma contagem estimada; o número real é o do seu `plan`.

**Horas estimadas:** 7.

## 1. Conceito

### ALB (Application Load Balancer)

Balanceador de camada 7 (HTTP/HTTPS). Fica nas subnets públicas, recebe o tráfego da internet e o encaminha para alvos. Aqui não há alvos: ele devolve uma resposta fixa, o que basta para mostrar WAF, TLS e health check sem custo de computação.

### ACM (certificados)

Emite e renova certificados TLS gratuitos para uso com ALB, CloudFront e API Gateway. A validação por DNS prova que você controla o domínio. Como o domínio do banco é fictício, o certificado é declarado mas nunca seria emitido (D-16).

### WAF

Firewall de camada 7 que olha o conteúdo da requisição. Funciona com regras: as **gerenciadas** (mantidas pela AWS, contra as ameaças mais comuns) e as suas (aqui, limite de requisições por IP). Protege contra ataques como injeção de SQL e tráfego malicioso conhecido; não substitui a validação feita pela aplicação.

### Shield

O **Shield Standard** vem ligado para todos, sem custo, e protege contra DDoS comuns de camadas 3 e 4. O **Shield Advanced** é pago (assinatura anual) e fica só no desenho (D-08).

## 2. Serviços que não usamos nesta fase

- **CloudFront:** traz a borda global, mas o objetivo é failover regional (D-07).
- **Global Accelerator:** outra forma de failover entre regiões, com custo fixo.
- **Network Load Balancer:** camada 4; não há protocolo que o exija.
- **API Gateway e Cognito:** não há API nem usuários finais no escopo.
- **Firewall Manager:** gerencia WAF em várias contas (escopo B).
- **Shield Advanced:** só desenho.

## 3. O que há nesta fase

| Recurso (por região) | Qtd |
| --- | --- |
| Certificado ACM | 1 |
| ALB | 1 |
| Listeners (80 redireciona, 443 responde) | 2 |
| WAF (web ACL) e associação ao ALB | 2 |
| Log group do WAF, resource policy e configuração de logs | 3 |
| **Total por região** | **9** |

Arquivos: `terraform/modules/edge/` (novo), `terraform/main.tf`, `variables.tf` (acrescenta `domain_name`) e `outputs.tf`, `docs/DECISIONS.md` (D-16) e este caderno.

## 4. Limites do que o plan prova

O `plan` não prova que o HTTPS funciona (o certificado nunca seria emitido), que as regras do WAF bloqueiam o que deveriam, nem que a entrega de logs do WAF para um log group com KMS funciona. Só um `apply` e testes de requisição provariam, e o projeto não faz isso.

## 5. Execução (você roda)

Nunca `terraform apply`.

```bash
cd terraform
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan -no-color 2>&1 | tail -60
cd ..
```

Cole o `validate` e o final do `plan`. Se algo der erro, cole a mensagem inteira.

## 6. Git e Jira

- Tickets: **BRI-35** (ALB nas duas regiões), **BRI-36** (certificado ACM), **BRI-37** (WAF com regras gerenciadas) e **BRI-38** (logs do WAF).
- Branch: `BRI-35-borda-alb-waf`
- Commit: `BRI-35 BRI-36 BRI-37 BRI-38: cria alb, acm e waf nas duas regioes`

## 7. Checklist

- [ ] Fase 5 mergeada na `main`
- [ ] Arquivos copiados por cima do repositório
- [ ] `fmt -check`, `init` e `validate` sem erro
- [ ] `plan`: `Plan: 94 to add`
- [ ] Dois `aws_lb`, dois `aws_wafv2_web_acl` e dois `aws_acm_certificate` no plan
- [ ] Saída do `plan` anexada aos tickets

## 8. Ligação com a prova (SAA)

- ELB: ALB contra NLB, listeners, health checks
- ACM e terminação de TLS no balanceador
- WAF contra Shield, regras gerenciadas, limite por taxa
- Defesa em camadas na borda (Route 53 + WAF + SG)

## 9. Para explicar em entrevista

- **Para que serve um ALB sem backend?** Para mostrar a borda de ponta a ponta sem custo de computação; ele é o alvo do WAF e do health check do failover.
- **O que o WAF resolve e o que não resolve?** Bloqueia ataques conhecidos e excesso de requisições, mas não substitui validação na aplicação nem autenticação.
- **Por que não há access logs do ALB?** Eles só aceitam bucket com SSE-S3, e o projeto criptografa tudo com chave própria; a trilha vem do WAF e do CloudTrail.
- **O HTTPS funcionaria num apply real?** Não com o domínio fictício: o certificado nunca seria emitido. É um limite do estudo.
