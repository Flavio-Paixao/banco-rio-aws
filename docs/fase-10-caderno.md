# Fase 10: documentação final (BRI-11)

**Plan esperado:** não muda. Esta fase só adiciona documentação, então o `plan` continua em `Plan: 166 to add, 0 to change, 0 to destroy`.

**Horas estimadas:** 6.

## 1. O que entrega

| Ticket | Entrega |
| --- | --- |
| BRI-51 | `docs/ARCHITECTURE.md` |
| BRI-52 | `docs/DECISIONS.md` completo (D-08 preenchido) |
| BRI-53 | `docs/COST-ANALYSIS.md` |
| BRI-54 | `docs/diagrama-arquitetura.svg` |
| BRI-55 | `README.md` revisado e revisão das afirmações |

## 2. Conceito: documentar o que não foi provado

Num portfólio, a parte mais valiosa é saber **separar o que foi validado do que foi suposto**. Este case valida com `fmt`, `validate` e `plan`. Por isso cada documento diz:

- o que o `plan` prova (o Terraform entende a configuração e cria N recursos);
- o que o `plan` **não** prova (replicação, backup, certificado, alarmes, entrega de logs);
- o que é **meta** (RPO e RTO) e o que seria **medição** (nenhuma foi feita).

## 3. Decisões desta fase

- **Fonte dos preços:** a AWS Price List (arquivos JSON públicos de preços), com a data de publicação de cada arquivo. A AWS Pricing Calculator usa os mesmos preços, mas é interativa; os totais devem ser recriados nela por você e o link guardado no repositório.
- **Custo só como piso:** o que depende de volume de dados não ganhou total, porque não há volume medido.
- **Diagrama em SVG escrito à mão:** abre em qualquer navegador e aparece direto no GitHub, sem ferramenta externa.

## 4. Serviços de documentação e custo que não usamos

- **AWS Well-Architected Tool:** faria uma revisão guiada dos pilares, mas pede uma carga de trabalho real.
- **AWS Cost Explorer e Budgets:** mostram custo **real**; sem `apply` não há fatura.
- **Ferramentas de diagrama automático a partir do Terraform:** gerariam um desenho do que existe no código, mas sem o que é só desenho.

## 5. Checklist de revisão final

- [ ] Nenhum resultado de uptime, RPO, RTO ou economia aparece como medido.
- [ ] Nenhum texto afirma conformidade com BACEN, LGPD, PCI-DSS ou SOX.
- [ ] Nenhuma senha, chave ou segredo no código ou nos documentos.
- [ ] `terraform fmt -check`, `validate` e `plan` limpos (`Plan: 166 to add`).
- [ ] Links do README abrem.

## 6. Perguntas de revisão (SAA)

1. **O que é RPO e o que é RTO?** RPO é a quantidade de dados que se aceita perder, medida em tempo. RTO é o tempo aceito até o serviço voltar.
2. **Qual estratégia de DR este case se aproxima?** *Warm standby*: o Aurora secundário já roda no DR e a borda está pronta para receber tráfego.
3. **Por que o failover de DNS não basta?** Ele só muda para onde as pessoas são mandadas; o banco secundário precisa ser promovido à parte.
4. **Por que replicação não é backup?** Ela copia também apagões e erros; backup guarda pontos no tempo.
5. **Quando valeria pagar o Shield Advanced, o CloudHSM ou uma VPN dedicada?** Quando o risco ou a exigência justificam o custo fixo (COST-ANALYSIS, seção 3).
