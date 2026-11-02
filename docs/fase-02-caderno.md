# Fase 2: rede nas duas regiões (BRI-3)

**Plan esperado:** `Plan: 30 to add, 0 to change, 0 to destroy` (15 recursos por região). É uma estimativa de contagem; o número real é o do seu `plan`. Se for diferente, cole a saída inteira antes de mexer em qualquer coisa.

**Horas estimadas:** 6.

## 1. Conceito

### VPC, subnets e Internet Gateway

- **VPC:** a rede privada virtual do projeto numa região. Aqui, uma por região, com CIDRs diferentes (10.0.0.0/16 e 10.1.0.0/16) para nunca se sobreporem.
- **Subnet pública:** subnet cuja route table tem uma rota `0.0.0.0/0` para o Internet Gateway. É a rota que a torna "pública", não o nome.
- **Subnet privada:** sem rota para a internet. Aqui, a route table privada só tem a rota local da VPC.
- **2 AZs por região:** uma subnet de cada tipo em cada AZ. Se uma AZ cair, a outra continua.

### Security group e NACL

- **Security group (SG):** firewall no nível do recurso, **com estado** (a resposta de uma conexão permitida volta sozinha) e só com regras de permissão.
- **NACL:** firewall no nível da subnet, **sem estado** (ida e volta precisam de regra) e com regras de permissão e negação.
- Aqui usamos só SGs (D-10).

### Um módulo, duas regiões

O módulo `network` é escrito uma vez e chamado duas vezes. A chamada do DR passa `providers = { aws = aws.dr }`, e tudo dentro do módulo nasce em us-east-1. Dentro do módulo não existe nenhuma menção à região.

### Como os CIDRs das subnets são calculados

`cidrsubnet("10.0.0.0/16", 8, 1)` devolve `10.0.1.0/24`: 8 bits a mais na máscara e o subnet número 1. As públicas usam os números 1 e 2, e as privadas, 11 e 12.

## 2. Serviços que não usamos nesta fase

- **NAT Gateway:** cobra por hora e por GB, e as subnets privadas não têm nada que precise sair para a internet (D-04, D-10).
- **VPC endpoints:** servem para a computação privada falar com serviços AWS sem internet; sem computação, não há quem use.
- **NACLs customizadas:** os SGs bastam, e a falta de estado das NACLs complica sem ganho aqui.
- **VPC peering e Transit Gateway:** a replicação do Aurora e do S3 usa a rede da AWS, sem ligar as duas VPCs. Os CIDRs sem sobreposição deixam a porta aberta.
- **IPv6 e egress-only IGW:** fora do foco.
- **VPC Flow Logs:** ficam para a fase 3, depois da chave KMS de logs (D-11).

## 3. O que há nesta fase

| Arquivo | Para quê |
| --- | --- |
| `terraform/modules/network/` | VPC, subnets, IGW, route tables, SG default bloqueado e SGs do ALB e do banco |
| `terraform/main.tf` | Chama o módulo duas vezes (primária e DR) |
| `terraform/variables.tf` | Acrescenta os CIDRs das duas VPCs |
| `terraform/outputs.tf` | IDs das VPCs e das subnets privadas |
| `.github/workflows/terraform-ci.yml` | Volta a usar `-lockfile=readonly`, porque o lock existe desde a fase 1 |
| `.gitattributes` | Fixa quebras de linha em LF (tira os avisos de CRLF) |
| `docs/DECISIONS.md` | Acrescenta D-10 e D-11 |

Os recursos por região são: VPC (1), SG default (1), IGW (1), subnets (4), route tables (2), associações (4), SG do ALB (1) e SG do banco (1), somando 15.

## 4. Execução (você roda)

Nunca `terraform apply`.

```bash
cd terraform
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
cd ..
```

O `init` precisa rodar de novo porque há um módulo novo. Se `fmt -check` listar arquivos, rode `terraform fmt -recursive` e me diga quais mudaram. Se algo der erro, cole a mensagem inteira antes de corrigir.

No `plan`, confira: 30 recursos a criar; as subnets privadas em `10.0.11.0/24` e `10.0.12.0/24` (primária) e em `10.1.11.0/24` e `10.1.12.0/24` (DR); e nenhum recurso com `provider` trocado entre as regiões.

## 5. Git e Jira

- Tickets: **BRI-20** (adaptar o módulo), **BRI-21** (rede em sa-east-1) e **BRI-22** (rede em us-east-1). O **BRI-23** (Flow Logs) passa para a Epic BRI-4, a fase 3.
- Branch: `BRI-20-modulo-network`
- Commit: `BRI-20 BRI-21 BRI-22: cria modulo network nas duas regioes`
- Depois do `plan` limpo, anexe a saída aos tickets e mova para Ready to Deploy; depois do merge, Done.

## 6. Checklist

- [ ] Arquivos copiados por cima do repositório (mantendo o `.terraform.lock.hcl`)
- [ ] `terraform fmt -check -recursive` sem arquivos listados
- [ ] `terraform init` e `terraform validate` com sucesso
- [ ] `terraform plan`: `Plan: 30 to add`
- [ ] CIDRs das subnets conferidos nas duas regiões
- [ ] BRI-23 movido para a Epic BRI-4 no Jira
- [ ] Branch e commit com as chaves; saída do `plan` anexada

## 7. Ligação com a prova (SAA)

- VPC, subnets públicas e privadas, route tables e Internet Gateway
- Security group (com estado) contra NACL (sem estado)
- NAT Gateway: quando precisa e quanto custa; alternativas como VPC endpoints
- Desenho com múltiplas AZs e CIDRs sem sobreposição para peering futuro

## 8. Para explicar em entrevista

- **Por que não há NAT Gateway?** Porque não há computação nas subnets privadas. Um NAT cobra por hora mesmo sem uso, então só entra quando há tráfego de saída a justificar.
- **O que torna uma subnet pública?** A rota para o Internet Gateway na route table, não o nome.
- **Por que CIDRs diferentes nas duas VPCs?** Para poder ligá-las depois (peering ou Transit Gateway) sem renumerar.
- **Por que o SG do banco libera as subnets privadas e não um SG de aplicação?** Porque este case não tem camada de aplicação. Num ambiente real, a origem seria o SG da aplicação.
