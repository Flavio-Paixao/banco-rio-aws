# Fase 5: S3 com replicação entre regiões (BRI-6)

**Plan esperado:** `Plan: 76 to add, 0 to change, 0 to destroy` (61 das fases anteriores mais 15 desta). É uma contagem estimada; o número real é o do seu `plan`.

**Horas estimadas:** 5.

## 1. Conceito

### Replicação entre regiões (CRR)

O S3 copia, de forma **assíncrona**, cada objeto novo de um bucket de origem para um bucket de destino em outra região. Exige versionamento nos dois buckets e uma **role** que o S3 assume para ler a origem e gravar no destino. Não há garantia de tempo sem o Replication Time Control (RTC), que é pago.

### Replicação e KMS

Objetos criptografados com KMS só são replicados se a regra tiver `sse_kms_encrypted_objects` ligado e a role puder **descriptografar** com a chave da origem e **criptografar** com a chave do destino. Por isso a chave multi-region da fase 3: o destino usa a réplica da chave, na região dele.

### O que a replicação não faz

- Não replica objetos que já existiam antes da regra (para isso existe o S3 Batch Replication).
- Não replica a exclusão de uma versão específica, só as marcas de exclusão (delete markers); isso protege contra apagar o backup por engano.
- Não substitui backup: se alguém sobrescreve ou apaga um objeto, a mudança também é replicada.

### Outros controles do bucket

- **Block Public Access:** quatro travas contra acesso público.
- **Policy "só HTTPS":** nega qualquer requisição sem TLS.
- **Versionamento e ciclo de vida:** histórico de cada arquivo, com versões antigas indo para o Glacier e depois expirando.
- **Bucket Key:** reduz as chamadas ao KMS e o custo.

## 2. Serviços que não usamos nesta fase

- **S3 Object Lock:** modo compliance é irreversível; decisão adiada.
- **Replication Time Control:** custo extra; fica só no desenho.
- **Multi-Region Access Points:** outro estudo, para roteamento de acesso entre regiões.
- **S3 Batch Replication:** só faria sentido com dados já existentes, e não há.
- **Macie:** descobre dados pessoais no S3, mas cobra por varredura (D-07).
- **EFS e FSx com replicação:** o banco fictício guarda objetos, não arquivos em rede.

## 3. O que há nesta fase

| Recurso | Qtd |
| --- | --- |
| Bucket de origem, bloqueio público, versionamento, criptografia, ciclo de vida, policy HTTPS | 6 |
| Bucket de destino, com os mesmos cinco itens | 6 |
| Role de replicação, política da role e configuração de replicação | 3 |
| **Total** | **15** |

Arquivos: `terraform/modules/s3_replicated/` (novo), `terraform/main.tf` e `outputs.tf`, `docs/DECISIONS.md` (D-15) e este caderno.

## 4. Limites do que o plan prova

O `plan` mostra que o Terraform entende a configuração. Ele **não prova** que a replicação funciona: as permissões da role, as condições de KMS e o tempo de replicação só seriam confirmados por um `apply` e por um teste de upload, que este projeto não faz. Isso fica registrado nos documentos finais.

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

- Tickets: **BRI-31** (módulo), **BRI-32** (role de replicação), **BRI-33** (regra CRR) e **BRI-34** (skips do checkov).
- Branch: `BRI-31-s3-replicacao`
- Commit: `BRI-31 BRI-32 BRI-33 BRI-34: cria buckets s3 com replicacao entre regioes`

## 7. Checklist

- [ ] Fase 4 mergeada na `main`
- [ ] Arquivos copiados por cima do repositório
- [ ] `fmt -check`, `init` e `validate` sem erro
- [ ] `plan`: `Plan: 76 to add`
- [ ] Um `aws_s3_bucket_replication_configuration` e dois `aws_s3_bucket` no plan
- [ ] Saída do `plan` anexada aos tickets

## 8. Ligação com a prova (SAA)

- S3: versionamento, ciclo de vida, classes de armazenamento, Block Public Access
- Replicação entre regiões (CRR) e na mesma região (SRR), RTC e suas limitações
- Criptografia SSE-S3, SSE-KMS e Bucket Keys; policy de bucket com `aws:SecureTransport`
- Estratégias de DR para dados de objeto

## 9. Para explicar em entrevista

- **A replicação é um backup?** Não. Ela copia também as mudanças e sobrescritas. Por isso existem o versionamento, as marcas de exclusão replicadas e, na fase 9, o AWS Backup.
- **Qual é o RPO dos objetos?** Uma meta de projeto na faixa de minutos, sem garantia, porque o RTC não está ligado.
- **Por que o destino tem outra chave?** Cada região precisa de uma chave local; a chave multi-region permite que a réplica seja equivalente à primária.
- **Por que a role tem condições de KMS?** Para que ela só use as chaves via S3 e só para estes buckets.
