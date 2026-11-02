# Fase 3: KMS multi-region e VPC Flow Logs (BRI-4)

**Plan esperado:** `Plan: 16 to add, 0 to change, 0 to destroy` se você rodar o `plan` partindo do código da fase 3 sozinho **a partir de um state vazio**. Como o state é local e nunca recebeu `apply`, o `plan` mostra o acumulado: **`Plan: 46 to add`** (30 da rede + 16 desta fase). É uma contagem estimada; o número real é o do seu `plan`.

**Horas estimadas:** 4 (KMS) + 2 (Flow Logs).

## 1. Conceito

### KMS e criptografia em envelope

O KMS guarda chaves e nunca entrega a chave em si. Serviços como o S3 e o Aurora pedem ao KMS uma chave de dados, criptografam com ela e guardam a versão criptografada da chave junto do dado. Por isso a **key policy** (quem pode usar e administrar a chave) é o controle mais importante.

### Chave multi-region

Uma chave multi-region tem a mesma ID e o mesmo material criptografico em regiões diferentes: uma **primária** e **réplicas**. Cada réplica é uma chave de verdade na região dela, com policy e custo próprios. Para o DR isso significa: o dado do Aurora e do S3 criptografado em sa-east-1 pode ser aberto em us-east-1 sem reencriptar.

### Key policy e IAM

Numa chave KMS, a key policy manda: se ela não permitir, o IAM sozinho não basta. Quando a policy delega à conta (`principal = conta`), o IAM passa a valer também. Aqui separamos **administração** (gerenciar a chave) de **uso** (criptografar e descriptografar) e restringimos o uso por serviço (`kms:ViaService`) e por conta (`kms:CallerAccount`).

### VPC Flow Logs

Registram quem falou com quem na VPC (IPs, portas, aceito ou recusado). Servem para auditoria e investigação. Ficam num log group do CloudWatch, criptografado com a chave de logs.

## 2. Serviços que não usamos nesta fase

- **Chaves gerenciadas pela AWS (aws/s3, aws/rds):** não deixam editar a key policy, então não mostram o controle de acesso ao dado.
- **Uma chave por serviço:** mais isolamento e mais custo; duas chaves (dados e logs) bastam para o case.
- **CloudHSM:** só no desenho (D-08).
- **Flow Logs em S3 ou Kinesis Data Firehose:** o volume do case é nulo, e o CloudWatch facilita consulta.
- **Traffic Mirroring:** captura pacotes completos; é outro objetivo (inspeção profunda).

## 3. O que há nesta fase

| Arquivo | Para quê |
| --- | --- |
| `terraform/modules/kms/` | Duas chaves multi-region (dados e logs), cada uma com réplica no DR e alias nas duas regiões: 8 recursos |
| `terraform/modules/vpc_flow_logs/` | Log group criptografado, role, política da role e o Flow Log, por região: 4 recursos |
| `terraform/main.tf` | Chama o módulo `kms` (com `providers` para as duas regiões) e o `vpc_flow_logs` duas vezes |
| `terraform/outputs.tf` | ARNs das chaves |
| `terraform/modules/network/main.tf` | Só o texto do skip do checkov mudou |
| `docs/DECISIONS.md` | Acrescenta D-12 e D-13 e atualiza D-11 |

## 4. Limites do que o plan prova

O `plan` mostra que o Terraform entende a configuração e quantos recursos cria, mas **não prova** que as policies funcionam na AWS. Em especial: a condição de encryption context da chave de logs, a entrega dos Flow Logs com a role e a criação de réplica de chave multi-region só seriam confirmadas por um `apply`, que este projeto não usa. Isso fica registrado nos documentos finais.

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

O `init` precisa rodar de novo (módulos novos). Se algo der erro, cole a mensagem inteira antes de corrigir. No `plan`, confira: 46 a criar; as quatro chaves (`aws_kms_key` x2 e `aws_kms_replica_key` x2); e os dois `aws_flow_log`, um em cada região.

Sobre o formato: já rodei `terraform fmt -check` nos arquivos desta fase e passou. Isso não substitui o seu `validate` e o seu `plan`.

## 6. Git e Jira

- Tickets: **BRI-24** (adaptar o módulo), **BRI-25** (chave de dados), **BRI-26** (chave de logs) e **BRI-23** (Flow Logs, vindo da fase 2).
- Branch: `BRI-24-kms-multi-region`
- Commit: `BRI-23 BRI-24 BRI-25 BRI-26: cria chaves kms multi-region e vpc flow logs`

## 7. Checklist

- [ ] Fase 2 mergeada na `main` e o CI verde (ou o erro colado aqui)
- [ ] Arquivos copiados por cima do repositório
- [ ] `fmt -check`, `init` e `validate` sem erro
- [ ] `plan`: `Plan: 46 to add`
- [ ] Quatro chaves KMS e dois Flow Logs conferidos no plan
- [ ] Saída do `plan` anexada aos tickets

## 8. Ligação com a prova (SAA)

- KMS: key policy contra IAM, grants, chaves gerenciadas pela AWS contra gerenciadas pelo cliente, rotação
- Chaves multi-region e o papel delas em DR
- Criptografia em repouso e em trânsito
- VPC Flow Logs e CloudWatch Logs para auditoria de rede

## 9. Para explicar em entrevista

- **Por que multi-region e não uma chave por região?** Porque o dado replicado precisa ser aberto na outra região sem reencriptar; com a mesma ID e o mesmo material, o Aurora Global e o S3 CRR funcionam sem passos extras.
- **Por que duas chaves?** Raio de impacto menor e trilha de auditoria separada para dados e para logs.
- **A conta pode usar a chave direto?** Não: a conta administra, mas o uso só vale via RDS ou S3, nesta conta.
- **O que o plan não garante?** Que as policies e a entrega dos logs funcionam de fato; isso exigiria um apply, que o projeto não faz.
