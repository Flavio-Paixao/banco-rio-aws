# Análise de custo

Estimativa do custo de **manter o projeto ligado**, em dólares por mês (730 horas). O projeto **nunca foi aplicado**, então não existe fatura: tudo aqui é **cálculo sobre preços de lista**, não custo medido. Se algum dia for aplicado, o custo real depende de uso, dados e impostos, e pode ser bem diferente.

## Fonte e método

Os preços vêm da **AWS Price List** (os arquivos JSON públicos de preços do próprio serviço de preços da AWS, em `pricing.us-east-1.amazonaws.com/offers/v1.0/aws/<serviço>/current/<região>/index.json`), consultados em 2 de novembro de 2026, preço sob demanda, em dólares. Datas de publicação dos arquivos usados:

| Serviço | Publicação do arquivo |
| --- | --- |
| Amazon RDS (Aurora PostgreSQL) | 29/10/2026 |
| Elastic Load Balancing | 02/11/2026 |
| AWS WAF | 14/09/2026 |
| AWS KMS | 26/10/2026 |
| AWS Secrets Manager | 11/09/2026 |
| Amazon CloudWatch | 07/10/2026 |
| AWS CloudHSM | 11/09/2026 |
| Amazon VPC (Site-to-Site VPN) | 16/10/2026 |
| AWS Direct Connect | 23/10/2026 |
| AWS Config, CloudTrail, GuardDuty, AWS Backup | 11/09, 02/11, 30/10 e 14/10/2026 |

O Shield Advanced vem da página de preços do serviço (https://aws.amazon.com/shield/pricing/), que traz US$ 3.000 por mês e a assinatura de 1 ano; a taxa por GB transferido vem do arquivo da Price List.

A AWS Pricing Calculator (https://calculator.aws/) usa os mesmos preços. **Não conferi os totais na calculadora**: ela é uma ferramenta interativa que só você consegue abrir e salvar com um link. Recomendo recriar o piso mensal abaixo nela e guardar o link no repositório.

## 1. Piso mensal fixo do que está no código

São os itens que cobram por hora ou por recurso existente, **sem depender de volume de dados**. É um piso: sozinho já deixa de fora tudo da seção 2.

| Item | Quantidade | Preço unitário | US$/mês |
| --- | --- | --- | --- |
| Aurora PostgreSQL `db.r6g.large`, sa-east-1 | 2 instâncias (writer e reader) | US$ 0,537/h | 784,02 |
| Aurora PostgreSQL `db.r6g.large`, us-east-1 | 1 instância | US$ 0,26/h | 189,80 |
| ALB, sa-east-1 | 1 | US$ 0,034/h | 24,82 |
| ALB, us-east-1 | 1 | US$ 0,0225/h | 16,43 |
| WAF: web ACLs | 2 | US$ 5,00 | 10,00 |
| WAF: regras (4 grupos gerenciados e 1 regra de limite, por ACL) | 10 | US$ 1,00 | 10,00 |
| KMS: chaves (2 primárias e 2 réplicas) | 4 | US$ 1,00 | 4,00 |
| Secrets Manager (segredo e réplica) | 2 | US$ 0,40 | 0,80 |
| CloudWatch: alarmes padrão | 1 em sa-east-1 e 3 em us-east-1 | US$ 0,135 e US$ 0,10 | 0,43 |
| **Piso fixo** | | | **cerca de US$ 1.040** |

Isso dá cerca de **US$ 12.500 por ano**, só de piso. O Aurora responde por cerca de 94% do piso: são três instâncias de classe `r6g`, que o Global Database exige (D-05 e D-14). É o principal motivo de este tipo de arquitetura ser cara de manter ligada.

Premissas e limites do piso:

- 730 horas por mês, instâncias ligadas o mês inteiro, sem Reserved Instances nem Savings Plans (que reduziriam o custo, mas dependem de compromisso e não foram calculados aqui).
- Cada réplica de chave KMS multi-region conta como uma chave. Considerei isso por suposição sobre a cobrança de réplicas, a confirmar na calculadora.
- Os **dashboards** do CloudWatch (1 painel) e o **health check e a zona hospedada do Route 53** não entraram no piso: não consegui confirmar o preço nos arquivos consultados. São valores pequenos perto do Aurora, mas ficam como pendência de conferência.

## 2. Custos que dependem de uso (preços unitários, sem total)

Não existe volume medido, então não calculei totais. Estes são os preços unitários, para você montar cenários na calculadora:

| Item | Preço unitário (fonte: Price List) |
| --- | --- |
| Aurora, armazenamento | US$ 0,19/GB-mês em sa-east-1 e US$ 0,10/GB-mês em us-east-1 |
| Aurora, I/O | US$ 0,28 por milhão em sa-east-1 e US$ 0,20 por milhão em us-east-1 |
| Aurora Global, I/O de escrita replicada | US$ 0,28 por milhão (sa-east-1) e US$ 0,20 por milhão (us-east-1) |
| Aurora, backup acima da cota gratuita | US$ 0,037/GB-mês (sa-east-1) e US$ 0,021/GB-mês (us-east-1) |
| ALB, capacidade usada (LCU) | US$ 0,011 por LCU-hora em sa-east-1 e US$ 0,008 em us-east-1 |
| WAF, requisições | US$ 0,60 por milhão (até 48 KB, preço de tabela) |
| KMS, requisições | US$ 0,03 por 10 mil em sa-east-1, com franquia gratuita mensal |
| CloudTrail, eventos de dados | US$ 0,000001 por evento (US$ 1,00 por milhão) em sa-east-1 |
| AWS Config, itens de configuração e avaliações | US$ 0,003 por item gravado e US$ 0,001 por avaliação de regra (primeiros 100 mil) |
| Transferência entre regiões (replicação do Aurora, S3 e cópia de backup) | Não conferida nesta análise: é um custo real e recorrente num DR, a verificar na calculadora |
| GuardDuty, Security Hub, S3, Flow Logs, CloudWatch Logs, SNS | Dependem de volume; consultar a calculadora |

## 3. Só desenho: o que custaria incluir

Estes itens **não estão no código** (D-08). Valores de lista, mensais, a 730 horas.

| Item | Cálculo | US$/mês | US$/ano |
| --- | --- | --- | --- |
| **Shield Advanced** | US$ 3.000 por mês por assinatura, compromisso de 1 ano, mais US$ 0,05 por GB transferido de ELB (sa-east-1, primeiros 100 TB) | 3.000 + transferência | 36.000 + transferência |
| **CloudHSM**, 2 HSMs em sa-east-1 | 2 × US$ 2,72/h | 3.971 | 47.654 |
| **CloudHSM**, 2 HSMs em us-east-1 | 2 × US$ 1,60/h | 2.336 | 28.032 |
| CloudHSM, 4 HSMs (2 por região) | soma das duas linhas acima | 6.307 | 75.686 |
| **Site-to-Site VPN** | US$ 0,05 por conexão-hora × 2 conexões (uma por região) | 73 | 876 |
| **Direct Connect**, 1 porta dedicada de 1 Gbps | US$ 0,30/h numa das localidades listadas na Price List (varia por localidade) | 219 | 2.628 |

Observações:

- O CloudHSM usa o preço por HSM-hora do arquivo da Price List (US$ 2,72/h em sa-east-1 e US$ 1,60/h em us-east-1). Considerei 2 HSMs por região porque um HSM único seria um ponto único de falha; **confirme a recomendação atual** na documentação da AWS.
- O Direct Connect cobra também a transferência de dados, o circuito da operadora e o cross-connect no data center, que **não são da AWS** e variam por contrato. O valor acima é só a porta. Uma VPN pela internet (Site-to-Site) é a alternativa barata, sem a previsibilidade de latência do circuito dedicado.
- A decisão de contratar o Shield Advanced depende de risco e de orçamento. Os benefícios exatos devem ser lidos na página oficial do serviço; não os detalho aqui porque não os conferi nesta análise.

## 4. O que cada decisão custa ou economiza (comparações de lista)

| Decisão | Efeito de custo, a preços de lista |
| --- | --- |
| Sem NAT Gateway (D-04 e D-10) | Evita uma cobrança fixa por hora e por GB processado em cada região |
| Sem CloudFront (D-07) | Evita o custo de distribuição; o failover é por DNS |
| Aurora secundário com 1 instância | Reduz o custo fixo do DR; um *warm standby* com 2 instâncias custaria mais US$ 189,80 por mês na região secundária |
| Chaves KMS customizadas (D-13) | Cada chave custa US$ 1 por mês, pouco perto do ganho de controle |
| Sem Macie e Inspector (D-07) | Evita cobranças por volume |

## 5. O que esta análise não é

- Não é orçamento nem previsão de fatura.
- Não mostra "economia" de nada: não há ambiente de comparação.
- Não inclui impostos, suporte AWS, tráfego de saída para a internet, custo de pessoas ou ferramentas.
- Os preços mudam; os valores valem para a data de consulta.
