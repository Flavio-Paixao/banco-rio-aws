# Fase 1: base do repositório e providers das duas regiões (BRI-2)

**Plan esperado:** nenhum recurso novo. Como esta fase só tem consultas (data sources) e outputs, o `plan` mostra `Changes to Outputs` com as regiões e as AZs, e **não** mostra a linha `Plan: N to add`. Se aparecer algo diferente, cole a saída inteira antes de mexer em qualquer coisa.

**Horas estimadas:** 4.

## 1. Conceito

### Região e zona de disponibilidade (AZ)

- **Região:** conjunto de datacenters numa área geográfica (sa-east-1 é São Paulo; us-east-1 é N. Virginia).
- **AZ:** datacenter(s) isolado(s) dentro de uma região. Espalhar recursos em 2 AZs protege de falha de um datacenter. Espalhar em 2 **regiões** protege de falha da região inteira, que é o caso do DR.

### Provider com apelido (alias)

O Terraform cria recursos na região do provider. Para trabalhar em duas regiões, declaramos dois providers `aws`: o padrão (sa-east-1) e um com `alias = "dr"` (us-east-1). Quem precisa nascer no DR escolhe `provider = aws.dr`. Nos módulos, o provider é repassado pelo bloco `providers = { aws = aws.dr }`. É assim que a fase 2 vai chamar o mesmo módulo de rede duas vezes.

### default_tags

As tags de projeto, ambiente, dono e repositório são aplicadas sozinhas a todo recurso que aceita tags, nas duas regiões. Facilita custo por tag e auditoria.

### State e backend

O state é o arquivo onde o Terraform guarda o que ele gerencia. Em equipe, ele fica num backend remoto (S3 com lock, versionado e criptografado). Aqui o state é local, porque o bucket do backend teria que ser criado com `apply` antes do primeiro `init`. A decisão está em D-03 do DECISIONS.md.

## 2. Serviços que não usamos nesta fase

- **S3 como backend remoto:** só no desenho (D-03).
- **Terraform Cloud/HCP:** adiciona uma ferramenta externa sem ganho para um projeto de estudo só com `plan`.
- **AWS Control Tower e Organizations:** pertencem ao escopo B.

## 3. O que há nesta fase

| Arquivo | Para quê |
| --- | --- |
| `terraform/versions.tf` | Versão do Terraform e do provider AWS |
| `terraform/providers.tf` | Provider padrão (sa-east-1), provider `aws.dr` (us-east-1) e `default_tags` |
| `terraform/variables.tf` | Nome do projeto, ambiente e as duas regiões |
| `terraform/main.tf` | Consulta as AZs de cada região (prova que o provider `aws.dr` funciona) |
| `terraform/outputs.tf` | Mostra regiões e AZs |
| `terraform/.tflint.hcl` | Regras do tflint (reaproveitado do seguros-horizonte) |
| `.github/workflows/terraform-ci.yml` | `fmt`, `validate`, tflint e checkov em cada push e PR; sem credenciais AWS e sem `plan`/`apply` |
| `.gitignore` | Ignora state, `.tfvars` e planos |
| `README.md`, `docs/DECISIONS.md` | Ponto de partida da documentação |

Não há senha, chave ou segredo no código. As credenciais da AWS ficam no seu ambiente (perfil do AWS CLI ou variáveis de ambiente), nunca no repositório.

## 4. Execução (você roda)

Nunca `terraform apply`. Só estes comandos:

```bash
cd terraform
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
```

Se `fmt -check` listar arquivos, rode `terraform fmt -recursive` e me diga quais mudaram. Se qualquer comando der erro, **cole a mensagem inteira** antes de corrigir.

`terraform init` cria o arquivo `terraform/.terraform.lock.hcl`. **Faça commit dele**: ele fixa a versão exata do provider. Na fase 2 reativamos `-lockfile=readonly` no CI.

## 5. Git e Jira

- Ticket: **BRI-2** (Epic da fase 1). Sugestão de sub-tarefas: estrutura de pastas, providers com alias, CI, DECISIONS inicial.
- Branch: `BRI-2-base-do-repositorio`
- Commit: `BRI-2: cria base do repositorio com providers das duas regioes`
- Quando o `plan` estiver limpo, anexe a saída ao ticket e mova para **Ready to Deploy**. Depois do merge, **Done**. Neste projeto "Ready to Deploy" significa `fmt`, `validate` e `plan` limpos, porque não há `apply`.

## 6. Checklist

- [ ] Arquivos copiados para o repositório `banco-rio-aws`
- [ ] `terraform fmt -check -recursive` sem arquivos listados
- [ ] `terraform init` concluído
- [ ] `terraform validate`: `Success! The configuration is valid.`
- [ ] `terraform plan` com `Changes to Outputs` e nenhuma linha `Plan: N to add`
- [ ] `.terraform.lock.hcl` commitado; nenhum `*.tfstate` ou `.terraform/` no commit (`git status` antes do commit)
- [ ] Branch criada com a chave BRI-2 e commit com a chave
- [ ] Saída do `plan` anexada ao ticket

## 7. Ligação com a prova (SAA)

- Regiões, AZs e por que escolher mais de uma para disponibilidade e DR
- Estratégias de DR: backup e restauração, *pilot light*, *warm standby* e multi-site ativo-ativo. Este case se aproxima de *warm standby*: o Aurora secundário já roda no DR, e a borda fica pronta para receber tráfego.
- RPO (quanto de dado posso perder) e RTO (quanto tempo posso ficar fora) são metas definidas antes de escolher a estratégia.

## 8. Para explicar em entrevista

- **Por que duas regiões e não só duas AZs?** AZs protegem de falha de datacenter; só a segunda região protege de falha da região.
- **Por que o state é local?** Porque o projeto nunca recebe `apply` e o backend remoto precisaria existir antes. Num ambiente real eu usaria S3 versionado, criptografado e com lock.
- **O que foi aberto mão?** Separação por contas e backend remoto real; ficaram no desenho.
