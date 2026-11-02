# Fase 7: DNS com failover (BRI-8)

**Plan esperado:** `Plan: 98 to add, 0 to change, 0 to destroy` (94 das fases anteriores mais 4 desta). É uma contagem estimada; o número real é o do seu `plan`.

**Horas estimadas:** 5.

## 1. Conceito

### Route 53

Serviço de DNS da AWS. É **global** (não pertence a uma região) e tem SLA próprio. Traduz nomes em endereços e pode decidir, a cada consulta, **qual endereço devolver**, de acordo com uma política de roteamento.

### Política de failover

Dois registros com o mesmo nome: um **PRIMARY** e um **SECONDARY**. O Route 53 responde com o primário enquanto o health check dele estiver saudável. Se falhar, passa a responder com o secundário. Quando o primário volta, o tráfego volta.

### Health check

Verificadores do Route 53, espalhados pelo mundo, testam o ALB por HTTPS. Se uma quantidade mínima falha `failure_threshold` vezes seguidas, o endpoint é considerado fora do ar. Com intervalo de 30 segundos e 3 falhas, são cerca de 90 segundos até a decisão (o intervalo de 10 segundos é mais rápido e custa mais).

### Registro alias

Um alias aponta para um recurso da AWS (como o ALB) sem custo de consulta e funciona no apex do domínio, onde um CNAME não pode ficar.

### TTL e cache

Mesmo depois que o Route 53 troca a resposta, resolvedores e navegadores podem guardar a resposta antiga por um tempo. Por isso o tempo de troca real é maior que o do health check.

### O que o failover de DNS não faz

Ele só muda para onde as pessoas são mandadas. O banco no DR continua um cluster secundário (somente leitura) até que alguém o promova. Isso é um passo à parte (D-17).

## 2. Serviços que não usamos nesta fase

- **Roteamento por latência, geolocalização ou peso:** servem para outros objetivos (desempenho, regras regionais, deploy gradual).
- **Application Recovery Controller:** orquestra failover com chaves de roteamento, mas tem custo fixo alto.
- **Global Accelerator:** failover por IPs anycast, também com custo fixo.
- **Zonas privadas e Route 53 Resolver:** não há tráfego interno entre VPCs.
- **DNSSEC e query logging:** só no desenho (D-17).
- **Registro de domínio:** o domínio é fictício.

## 3. O que há nesta fase

| Recurso | Qtd |
| --- | --- |
| Zona hospedada | 1 |
| Health check da região primária | 1 |
| Registros alias de failover (PRIMARY e SECONDARY) | 2 |
| **Total** | **4** |

Arquivos: `terraform/modules/dns/` (novo), `terraform/main.tf` e `outputs.tf`, `docs/DECISIONS.md` (D-17) e este caderno.

## 4. Limites do que o plan prova

O `plan` mostra que o Terraform entende a configuração. Ele **não prova** que o failover acontece, quanto tempo leva, nem que o health check consegue alcançar o ALB (que num `apply` real teria o problema do certificado, D-16). Os tempos citados são **cálculos**, não medições.

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

- Tickets: **BRI-39** (zona hospedada), **BRI-40** (health check) e **BRI-41** (registros de failover).
- Branch: `BRI-39-dns-failover`
- Commit: `BRI-39 BRI-40 BRI-41: cria dns com failover no route 53`

## 7. Checklist

- [ ] Fase 6 mergeada na `main`
- [ ] Arquivos copiados por cima do repositório
- [ ] `fmt -check`, `init` e `validate` sem erro
- [ ] `plan`: `Plan: 98 to add`
- [ ] Dois `aws_route53_record` (PRIMARY e SECONDARY) e um health check no plan
- [ ] Saída do `plan` anexada aos tickets

## 8. Ligação com a prova (SAA)

- Route 53: tipos de registro, alias contra CNAME, políticas de roteamento (failover, latência, geolocalização, ponderado)
- Health checks e como se ligam ao failover
- RTO e RPO: o que o DNS resolve e o que depende do banco e dos dados
- Estratégia *warm standby*: o ambiente de DR existe e está ligado, mas com capacidade reduzida

## 9. Para explicar em entrevista

- **O que acontece quando a região primária cai?** O health check falha três vezes seguidas, o Route 53 passa a devolver o ALB do DR, e o tráfego muda quando os caches de DNS expiram. O banco só vira primário quando alguém promove o cluster secundário.
- **Por que `evaluate_target_health` está desligado?** Porque o ALB não tem alvos registrados, então a decisão fica com o health check explícito.
- **Qual é o RTO?** Uma meta de projeto na faixa de minutos, calculada a partir do intervalo, das falhas e do cache; não foi medida.
- **Por que o alarme do health check ficará em us-east-1?** Porque as métricas do Route 53 só existem nessa região, que é a de DR.
