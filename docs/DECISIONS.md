# Decisões do projeto

Cada decisão tem o motivo, o que foi deixado de lado e o que se abre mão. Este arquivo cresce a cada fase.

## D-01. Escopo: resiliência e DR (versão A), numa conta só

- **Motivo:** dá para validar tudo com `terraform plan` numa conta, e responde aos quatro requisitos do banco fictício (alta disponibilidade, dados sensíveis, auditoria, DR).
- **Não escolhido:** governança multi-conta (AWS Organizations, SCPs, contas separadas). Criar contas e aplicar SCPs não se desfaz com facilidade e não se valida bem com `plan` numa conta só.
- **Abrimos mão de:** separação de ambientes por conta. Num banco real, este desenho rodaria dentro de uma estrutura multi-conta.
- **Ajuste ao escopo:** CloudTrail incluído, porque sem ele a auditoria de acessos fica descoberta.

## D-02. Regiões: sa-east-1 (primária) e us-east-1 (DR)

- **Motivo:** São Paulo mantém os dados perto dos clientes brasileiros; N. Virginia é uma região grande, com todos os serviços usados e preço menor.
- **Como no código:** provider padrão em sa-east-1 e provider com apelido `aws.dr` em us-east-1.
- **Abrimos mão de:** manter os dados só no Brasil. A réplica em us-east-1 é uma decisão que um banco real precisaria avaliar contra a regulação aplicável.

## D-03. State local nesta fase, backend S3 só no desenho

- **Motivo:** o bucket do backend precisaria existir antes do `init`, e criá-lo exige `apply`, que este projeto não usa.
- **Como seria num ambiente real:** bucket S3 versionado e criptografado com KMS, com bloqueio de state (lock) e acesso restrito por IAM. Será descrito no ARCHITECTURE.
- **Cuidado:** `*.tfstate` está no `.gitignore`, porque o state pode conter dados sensíveis.

## D-04. Sem camada de aplicação

- **Motivo:** o foco é dados e DR. Um ALB com resposta fixa nas duas regiões basta para mostrar WAF, health check e failover.
- **Efeito:** sem EC2, ECS ou Lambda de aplicação, e sem NAT Gateway (que nos cases anteriores servia às instâncias privadas).

## D-05. Banco: Aurora PostgreSQL Global Database

- **Motivo:** PostgreSQL é o motor dos módulos reaproveitados (seguros-horizonte) e o Global Database faz a réplica entre regiões.
- **Classe da instância:** a documentação da AWS exige para o Global Database classes otimizadas para memória e recomenda `db.r5` ou superior. O módulo reaproveitado usava `db.t3.medium` (burstable), então a fase 4 usa `db.r6g.large` ou `db.r5.large` (D-14).

## D-06. Reuso dos cases anteriores

| Origem | Módulo | Adaptação prevista | Fase |
| --- | --- | --- | --- |
| seguros-horizonte | networking | Sem NAT; instanciado duas vezes (provider padrão e `aws.dr`); Flow Logs ligados na fase 3 (D-11) | 2 |
| seguros-horizonte | kms | Chaves multi-region e réplica no DR; `kms:ViaService` por região | 3 |
| seguros-horizonte | rds | Global cluster; classe sem `db.t*`; cluster secundário no DR | 4 |
| seguros-horizonte | storage | Replicação entre regiões (CRR) e chave KMS na réplica | 5 |
| seguros-horizonte | CI (`terraform-ci.yml`, tflint, checkov) | Mesma estrutura, caminhos do novo repositório | 1 |

## D-07. Serviços que não foram usados

| Serviço | Por que não |
| --- | --- |
| AWS Organizations e SCPs | É o escopo B |
| EC2, ECS, EKS, Lambda de aplicação | Fora do foco (D-04) |
| NAT Gateway | Sem computação nas subnets privadas, não há saída de internet a justificar o custo por hora |
| CloudFront | O objetivo é failover regional com Route 53 |
| DynamoDB Global Tables | O banco fictício é relacional |
| Transit Gateway e peering entre regiões | A replicação do Aurora e do S3 usa a rede da AWS |
| Macie | Varredura tem custo; fica como próximo passo |
| Inspector | Sem EC2, contêineres ou Lambda, não há o que escanear |
| AWS Elastic Disaster Recovery | Serve para replicar servidores, e não há servidores |

## D-08. Só no desenho: Shield Advanced, CloudHSM e VPN dedicada

Preenchido na fase 10, junto com o COST-ANALYSIS, com custos conferidos na AWS Pricing Calculator.

## D-09. Alinhamento a boas práticas (sem alegar conformidade)

O projeto é **alinhado a boas práticas** de segurança e resiliência (criptografia em repouso, mínimo privilégio, trilha de auditoria, backups entre regiões). Não afirma conformidade com BACEN, LGPD, PCI-DSS ou SOX. Cada fase indica o que foi apenas desenhado.

## D-10. Rede: sem NAT, sem camada de aplicação, security groups mínimos

- **Estrutura por região:** VPC /16, 2 subnets públicas e 2 privadas (uma de cada por AZ), Internet Gateway e uma route table pública e uma privada. Primária 10.0.0.0/16 e DR 10.1.0.0/16, sem sobreposição, o que deixaria a porta aberta para um peering futuro.
- **Subnets privadas sem rota para a internet:** não há NAT Gateway (D-04). A route table privada tem só a rota local da VPC.
- **SG do ALB:** aceita HTTP (80) e HTTPS (443) da internet e não tem regra de saída, porque o ALB responde com resposta fixa. A porta 80 aberta ao mundo é esperada num ALB público (o checkov CKV_AWS_260 foi dispensado só nesse SG).
- **SG do banco:** aceita 5432 só dos CIDRs das subnets privadas e não tem regra de saída. No módulo do seguros-horizonte a origem era o SG da aplicação; como aqui não há camada de aplicação, a origem passou a ser o CIDR das subnets privadas, onde uma aplicação futura ficaria. A replicação do Aurora entre regiões não passa por este SG.
- **SG default da VPC:** adotado e esvaziado, para que nada use um SG com regras por engano.
- **Não usado:** NACLs customizadas (os SGs já controlam o acesso e as NACLs são sem estado, o que complica sem ganho aqui), VPC endpoints (sem computação nas subnets privadas para usá-los) e peering ou Transit Gateway entre as VPCs (D-07).

## D-11. VPC Flow Logs ficam para a fase 3

Os Flow Logs vão para o CloudWatch Logs e devem ser criptografados com a chave KMS de logs, que só existe a partir da fase 3. Criá-los antes obrigaria a criar o log group sem criptografia e alterá-lo depois. Na fase 3 eles passaram a existir, no módulo `vpc_flow_logs`. O skip do checkov CKV2_AWS_11 continua na VPC porque o recurso de Flow Logs fica em outro módulo; se o checkov reconhecer a ligação entre os módulos, o skip pode sair.

## D-12. Flow Logs: role com mínimo privilégio, uma exceção inevitável

- **Destino:** CloudWatch Logs, com retenção de 365 dias e criptografia pela chave de logs da própria região. Alternativa não usada: S3, mais barato para volume alto, mas aqui o tráfego é inexistente e o CloudWatch facilita consulta e alarmes.
- **Role:** assumida só pelo serviço `vpc-flow-logs.amazonaws.com`, com `aws:SourceAccount` para evitar o problema do "confused deputy". O nome da role inclui o rótulo da região, porque IAM é global e as duas instâncias do módulo colidiriam.
- **Permissões:** `logs:CreateLogStream`, `logs:PutLogEvents` e `logs:DescribeLogStreams` só no log group dos Flow Logs. `logs:DescribeLogGroups` precisa de `Resource: "*"` porque é uma chamada de conta; é a única exceção, e o checkov CKV_AWS_356 está dispensado nela. A política segue o exemplo da documentação da AWS, mas só um `apply` confirmaria que a entrega funciona; o `plan` não verifica isso.

## D-13. KMS: duas chaves multi-region

- **Duas chaves, uma por finalidade:** dados (Aurora e S3) e logs (Flow Logs, CloudTrail, WAF). Se uma vazar ou for desativada, a outra não é afetada, e cada uma tem sua trilha no CloudTrail.
- **Multi-region:** a chave primária fica em sa-east-1 e a réplica em us-east-1 tem o mesmo ID e o mesmo material. Dado criptografado numa região pode ser descriptografado na outra sem reencriptar, o que sustenta o Aurora Global e o S3 CRR. A réplica é uma chave própria, com key policy e custo próprios (aproximadamente US$ 1 por chave por mês, a confirmar na fase 10).
- **Key policy de dados:** a conta administra mas não usa direto; o uso só vale via RDS ou S3 da região (`kms:ViaService`), de chamadas desta conta (`kms:CallerAccount`). Grants só para recursos da AWS.
- **Key policy de logs:** só o CloudWatch Logs da região, e só para log groups cujo nome começa com `/banco-rio/` ou `aws-waf-logs-banco-rio`. O CloudTrail entra na fase 8.
- **Rotação anual** ligada na primária; a réplica acompanha a primária.
- **Resource `*` nas key policies:** numa key policy, `*` significa "esta chave". Os skips do checkov CKV_AWS_109, 111 e 356 nas policies apontam para esta decisão.
- **Abrimos mão de:** chaves gerenciadas pela AWS (sem controle da policy), uma chave por serviço (mais isolamento, mais custo) e CloudHSM (D-08).

## D-14. Aurora Global Database

- **Estrutura:** um `aws_rds_global_cluster`, um cluster primário em sa-east-1 (writer e reader em 2 AZs) e um cluster secundário em us-east-1 (1 instância, somente leitura). O secundário é promovido num failover regional.
- **Senha:** a documentação da AWS diz que o Secrets Manager **não gerencia** a senha de clusters que fazem parte de um Global Database (`manage_master_user_password` do módulo antigo não serve aqui). A senha é gerada com `random_password`, guardada num segredo do Secrets Manager criptografado com a chave de dados e **replicado para us-east-1** com a réplica da chave. Nada de senha no código.
- **Limite assumido:** a senha também fica no **state**, que é local e está no `.gitignore`. Num ambiente real, o state iria para um backend criptografado com acesso restrito (D-03), ou a senha seria passada de outra forma. Rotação automática exigiria uma Lambda e fica só no desenho (checkov CKV2_AWS_57 dispensado).
- **Classe da instância:** os data sources `aws_rds_orderable_db_instance` perguntam à AWS, em cada região, se motor + versão + classe existem, se aceitam Global Database e se suportam Performance Insights e Enhanced Monitoring. Se não, o `plan` falha com mensagem clara. Preferência: `db.r6g.large`, depois `db.r5.large`.
- **Versão do motor:** 15.19, a mesma conferida no seguros-horizonte. A checagem acima cobre a combinação nas duas regiões.
- **Criptografia:** o primário usa a chave de dados e o secundário usa a **réplica** dela em us-east-1 (D-13). O argumento `source_region` é passado no secundário porque a AWS o exige para réplica criptografada; só um `apply` confirmaria a combinação.
- **Backup:** backup automático nativo do Aurora por 7 dias. O plano do AWS Backup com cópia entre regiões entra na fase 9 (checkov CKV2_AWS_8 dispensado até lá).
- **Estudo, não produção:** `deletion_protection = false` e `skip_final_snapshot = true` para o projeto poder ser destruído. Em produção seriam `true` e `false`.
- **Auditoria dentro do banco:** a extensão `pgaudit` seria o próximo passo, mas não foi codificada porque os nomes dos parâmetros só seriam confirmados por um `apply`. Fica como desenho.
- **Metas de projeto (não são medições):** RPO do banco na ordem de segundos, apoiado na latência de replicação que a AWS descreve como tipicamente abaixo de um segundo, e RTO na faixa de minutos com failover regional. Nenhum desses valores foi medido.
- **Failover e switchover:** *switchover* é a troca planejada, sem perda de dados; *failover* é a recuperação após queda da região primária e pode perder as últimas transações ainda não replicadas. Os dois exigem versões de motor iguais nos clusters.
- **Não usado:** Aurora Serverless v2 (o Global Database com ACU mínimo recomendado de 8 sai mais caro e é outro estudo), RDS Proxy (sem camada de aplicação), Aurora Auto Scaling (não suportado em clusters secundários) e Blue/Green (não suportado com Global Database).

## D-15. S3 com replicação entre regiões (CRR)

- **Estrutura:** um bucket de dados em sa-east-1 (origem) e outro em us-east-1 (destino). Os dois têm versionamento (obrigatório para replicar), bloqueio total de acesso público, criptografia SSE-KMS com Bucket Key, ciclo de vida para versões antigas e uma policy que nega qualquer acesso sem HTTPS.
- **Chaves:** a origem usa a chave de dados e o destino usa a **réplica** dela (D-13). Os objetos replicados são recriptografados com a chave do DR.
- **Role de replicação:** assumida só pelo `s3.amazonaws.com`, com permissão de ler as versões da origem, gravar no destino e usar cada chave KMS só via S3 da região respectiva e só para os dois buckets. Com Bucket Keys ligadas, o contexto de criptografia usa o ARN do bucket, então a condição aceita o ARN do bucket e o do objeto. A política segue o exemplo da documentação da AWS; só um `apply` confirmaria que a replicação funciona de fato.
- **Retenção:** versões antigas vão para o Glacier após 90 dias e expiram após 2555 dias (7 anos). É uma escolha de projeto, não uma exigência legal confirmada.
- **Desenho dos cases anteriores:** o módulo de storage do seguros-horizonte tinha três buckets (dados, backups, logs). Aqui ficam só os de dados. O bucket de logs entra com o CloudTrail na fase 8, e os backups passam pelo AWS Backup na fase 9.
- **Limites da replicação:** vale só para objetos novos depois que a regra existe (objetos antigos exigiriam S3 Batch Replication, não usado); a exclusão de uma versão específica não é replicada, só as marcas de exclusão; e sem o Replication Time Control a AWS não dá garantia de tempo de replicação. O RTC (meta de 15 minutos) tem custo extra e fica só no desenho.
- **Meta de projeto (não é medição):** RPO dos objetos na faixa de minutos, sem garantia contratual.
- **Skips do checkov:** CKV_AWS_144 só no bucket de destino (replicar de volta não é necessário); CKV_AWS_18 e CKV2_AWS_62 nos dois buckets (sem server access logging e sem consumidor de eventos; a trilha de acessos vem do CloudTrail).
- **Não usado:** S3 Object Lock (irreversível em modo compliance; decisão adiada), S3 Multi-Region Access Points (outro estudo), Replication Time Control, Intelligent-Tiering, Macie (D-07) e replicação para uma terceira região.

## D-16. Borda: ALB, ACM e WAF em cada região

- **ALB sem backend:** um ALB público por região, nas subnets públicas, com resposta fixa (HTTP 200 em texto). Ele é o alvo do WAF e do health check do Route 53 (fase 7). Não há target group nem instâncias (D-04). `drop_invalid_header_fields` ligado.
- **Listeners:** a porta 80 só redireciona para a 443 (HTTP 301). A 443 usa a política TLS `ELBSecurityPolicy-TLS13-1-2-2021-06`, que aceita TLS 1.2 e 1.3.
- **Certificado ACM:** um por região, para o domínio **fictício** `banco-rio.example.com`. Não existe `aws_acm_certificate_validation`, porque a validação por DNS exigiria um domínio real. Consequência: o `plan` funciona, mas num `apply` real o listener HTTPS não conseguiria usar um certificado que nunca foi emitido. É um limite do estudo, não um erro de desenho.
- **WAF (REGIONAL):** quatro grupos de regras gerenciadas da AWS (Common, Known Bad Inputs, SQL Injection e IP Reputation) e uma regra própria que bloqueia mais de 1000 requisições por IP em 5 minutos. A ação padrão é permitir. O WAF é uma camada a mais, não substitui validação na aplicação.
- **Logs do WAF:** CloudWatch Logs, com nome `aws-waf-logs-...` (exigência do WAF), retenção de 365 dias e criptografia pela chave de logs da região. As entregas dependem de uma resource policy do CloudWatch Logs. Os cabeçalhos `authorization` e `cookie` são omitidos dos logs. Se a combinação de KMS com a entrega de logs do WAF funciona, só um `apply` diria.
- **Sem access logs do ALB:** eles só aceitam bucket com SSE-S3, não KMS, o que quebraria o padrão do projeto de criptografar tudo com chave própria. O checkov CKV_AWS_91 está dispensado por isso. A trilha de chamadas administrativas vem do CloudTrail (fase 8) e a de requisições, dos logs do WAF.
- **Proteção contra DDoS:** o Shield Standard já protege ALB e Route 53 sem custo. O Shield Advanced fica só no desenho (D-08).
- **Não usado:** CloudFront (o objetivo é failover regional com Route 53, D-07), API Gateway, Network Load Balancer, AWS Global Accelerator (outro caminho para failover entre regiões, com custo fixo), AWS Firewall Manager e Cognito.

## D-17. DNS com failover no Route 53

- **Estrutura:** uma zona hospedada para o domínio fictício, um health check HTTPS no ALB da região primária (`/health`, a cada 30 segundos, 3 falhas seguidas) e dois registros `A` do tipo alias com o mesmo nome: `PRIMARY` (ALB de sa-east-1, ligado ao health check) e `SECONDARY` (ALB de us-east-1).
- **Tempo de troca (cálculo, não medição):** o Route 53 só declara a primária fora do ar depois de 3 falhas a 30 segundos, ou seja, cerca de 90 segundos, mais o tempo de cache de DNS nos clientes. Com intervalo de 10 segundos seria mais rápido e mais caro. Por isso o RTO de DNS está na faixa de minutos, como meta de projeto.
- **`evaluate_target_health = false`:** o ALB não tem alvos registrados (D-04), então a decisão fica com o health check explícito, e não com a avaliação automática do alias.
- **O que o failover de DNS não faz:** ele só muda para onde as pessoas são mandadas. Promover o cluster Aurora secundário a primário é um passo separado (failover do Global Database), que num ambiente real seria um procedimento documentado ou automatizado (por exemplo EventBridge e Lambda). Essa automação não foi codificada.
- **Domínio fictício:** a zona existe no Route 53, mas não é delegada em registrador algum, então nada responderia na internet. Os registros de validação do certificado ACM também não foram criados, pelo mesmo motivo (D-16).
- **Só no desenho:** DNSSEC (exigiria uma chave KMS assimétrica em us-east-1 e um registro DS no registrador) e query logging (exigiria um log group em us-east-1 com resource policy). Os dois checks do checkov (CKV2_AWS_38 e CKV2_AWS_39) estão dispensados nessa zona por isso.
- **Alarme do health check:** as métricas do Route 53 só existem em us-east-1, que é a região de DR. O alarme entra na fase 9 e deve ser criado com o provider `aws.dr`.
- **Não usado:** roteamento por latência ou geolocalização (outro objetivo), failover com health check também no secundário (custo extra), Route 53 Resolver e zonas privadas (sem tráfego interno entre VPCs), Application Recovery Controller (custo fixo alto e fora do escopo) e Global Accelerator.

## D-18. Segurança e auditoria: CloudTrail, GuardDuty, Security Hub e Config

Este projeto é **alinhado a boas práticas** de auditoria e detecção. Isso não equivale a conformidade com BACEN, LGPD, PCI-DSS ou SOX, que não é afirmada.

- **CloudTrail:** uma trilha multi-região (`is_multi_region_trail`), com eventos de gerenciamento (quem criou, alterou ou apagou recursos), serviços globais, validação de integridade dos arquivos e criptografia com a chave de logs. Também registra os acessos a objetos (data events) dos dois buckets de dados, o que responde à pergunta "quem leu este dado". Os arquivos vão para o bucket de auditoria e para um log group do CloudWatch.
- **Bucket de auditoria:** versionado, sem acesso público, SSE-KMS com a chave de logs, só HTTPS, logs para o Glacier em 90 dias e expiração em 2555 dias (escolha de projeto, não exigência legal). A policy libera só o CloudTrail e o Config, com condições de conta e de trilha.
- **Limite assumido:** o bucket de auditoria existe só em sa-east-1 e **não é replicado** para o DR. Num ambiente real, ele seria replicado (como o bucket de dados, D-15), idealmente para uma conta separada de logs, que é o escopo B. Se a região primária ficasse indisponível, a trilha continuaria gravando em outra região (é multi-região), mas o bucket em si ficaria fora do ar.
- **Chave de logs:** a key policy ganhou três permissões: CloudTrail gera chaves de dados só para trilhas da conta com o nome do projeto, descreve a chave, e o bucket de auditoria pode ser usado via S3 pela conta, com IAM concedendo o acesso à role do Config.
- **GuardDuty:** um detector por região, com as proteções de eventos de dados do S3 e de login no RDS (Aurora). Ficaram de fora a proteção contra malware em EBS, EKS, Lambda e monitoramento de runtime, porque não há esses recursos. Os achados vão para o EventBridge na fase 9.
- **Security Hub:** ligado em cada região, só com o padrão AWS Foundational Security Best Practices (os padrões default ficam desligados). Os achados da região de DR são agregados na primária. Os padrões CIS e PCI DSS não foram ativados; ativar um padrão mostra checagens, não prova conformidade.
- **AWS Config:** um gravador por região (recursos globais só na primária) e quatro regras gerenciadas por região: bucket S3 sem leitura pública, S3 só com HTTPS, storage do RDS criptografado e CloudTrail ativo. O Security Hub depende do Config para várias de suas checagens.
- **O que o plan não prova:** que a entrega do Config no bucket com KMS funciona, que as condições da key policy do CloudTrail batem, e que as checagens do Security Hub passam. Só um `apply` e uma semana de uso diriam.
- **Custo:** GuardDuty, Config e os data events do CloudTrail cobram por volume. Entram no COST-ANALYSIS (fase 10), com valores conferidos na AWS Pricing Calculator.
- **Não usado:** Organization trail e Security Lake (escopo B), CloudTrail Insights e CloudTrail Lake (custo), IAM Access Analyzer (barato e útil, fica como próximo passo), Macie e Inspector (D-07), Detective, Audit Manager, Network Firewall, conformance packs e remediação automática do Config.

## D-19. Backup e monitoramento

Este projeto é **alinhado a boas práticas** de backup e observabilidade. Isso não equivale a conformidade com BACEN, LGPD, PCI-DSS ou SOX, que não é afirmada.

**Backup**

- **Cofres:** um por região, criptografados com a chave de dados da região. O cofre do DR recebe as cópias do cofre primário.
- **Plano:** uma regra diária às 05:00 UTC protege o cluster Aurora primário, com retenção de 35 dias, e copia cada ponto de recuperação para o cofre do DR com a mesma retenção. A seleção é pelo ARN do cluster, não por tag, para que o plano proteja só o que está escrito.
- **Vault Lock em modo governance:** retenção mínima de 7 e máxima de 365 dias em cada cofre. Sem `changeable_for_days`, o modo é governance: quem tem a permissão específica ainda consegue remover o lock. Foi a escolha do Flávio.
- **Só no desenho: modo compliance.** Depois da carência, o lock em compliance não pode ser removido nem pela conta raiz, e o cofre só some quando o último ponto de recuperação expira. Num banco real seria o modo certo para backups imutáveis; num projeto de estudo é um risco sem ganho.
- **Chaves KMS:** a key policy da chave de dados ganhou o serviço `backup` em `kms:ViaService` (a policy continua limitada à conta). A role do backup recebe uma política com as duas chaves (origem e destino da cópia).
- **S3 fora do plano:** o bucket de dados fica protegido por versionamento e replicação (D-15). O AWS Backup para S3 pede políticas extras e a confirmação de como ele usa a chave KMS do bucket; fica como próximo passo.
- **Aurora:** o backup contínuo (PITR) do próprio Aurora segue ligado (7 dias, D-14). O plano do AWS Backup acrescenta retenção maior, cópia entre regiões e o lock.
- **O que o plan não prova:** que o job de backup roda, que a cópia chega ao DR com a chave replicada, que a restauração funciona nem quanto tempo leva. Teste de restauração não foi feito e nenhum RTO ou RPO foi medido.

**Monitoramento**

- **Tópico SNS por região**, criptografado com a chave de logs. A key policy da chave de logs ganhou uma permissão para o CloudWatch e o EventBridge da conta gerarem a chave de dados (sem ela os alarmes não publicam num tópico com chave própria). A policy do tópico permite publicar só CloudWatch e EventBridge da conta e nega tráfego sem TLS. **Não há assinantes**: assinar um e-mail exige confirmação manual e é dado pessoal.
- **Alarmes:** erros 5xx do ALB (as duas regiões); atraso de replicação do Aurora Global (limiar de alerta de 5000 ms, que é um valor de estudo e **não é o RPO**), lido na região do cluster secundário; status do health check do Route 53, em us-east-1 (dado ausente conta como falha).
- **EventBridge:** achados do GuardDuty com severidade 7 ou mais e jobs de backup ou cópia com falha, em cada região, para o tópico de alertas.
- **Painel:** um dashboard com atraso de replicação, health check e erros 5xx das duas regiões.
- **Limite:** um alarme que dispara não faz o failover. Promover o Aurora secundário e redirecionar o tráfego continuam sendo passos documentados, sem automação (D-17).
- **Não usado:** Security Hub com notificações próprias (já agrega os achados), CloudWatch Synthetics, X-Ray, Container Insights e Application Signals (não há aplicação), AWS Chatbot e Incident Manager (sem equipe de plantão), alarme composto, detecção de anomalias e notificações do cofre de backup por SNS (as regras do EventBridge cobrem as falhas).
