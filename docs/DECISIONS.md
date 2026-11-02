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
- **Atenção:** o Global Database não aceita classes `db.t*`; o módulo reaproveitado usava `db.t3.medium` e será adaptado na fase 4.

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

Os Flow Logs vão para o CloudWatch Logs e devem ser criptografados com a chave KMS de logs, que só existe a partir da fase 3. Criá-los antes obrigaria a criar o log group sem criptografia e alterá-lo depois. O checkov CKV2_AWS_11 está dispensado na VPC com esta justificativa, e o skip sai quando os Flow Logs forem ligados.
