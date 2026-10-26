# Decisões e correção — Clínica Médica

## 1. Três decisões que tomamos e por quê

### Decisão 1 — Consulta e atendimento são duas tabelas diferentes

`consulta` é o **horário marcado** (paciente, médico, tipo, início/fim, status). `atendimento` é **o que aconteceu**
(queixa, anamnese, sinais vitais, diagnóstico, receitas, exames), ligado 1:1 à consulta (`id_consulta` com `UNIQUE`).

**Por quê:**

- Nem toda consulta vira atendimento: as canceladas e as faltas nunca têm prontuário. Numa tabela só, metade das
  colunas ficaria vazia na maioria das linhas.
- A consulta é vista pela recepção o dia inteiro; o atendimento é sigiloso. Separando, o atendimento pode ir para o
  schema `sensivel` e a recepção trabalha só com o schema `clinica` sem nunca tocar no prontuário.
- O médico e o paciente do atendimento não são repetidos: vêm da consulta (evita dependência transitiva, 3FN).

### Decisão 2 — O preço muda, então fica numa tabela de histórico, e a consulta guarda uma "foto" do valor

Os valores ficam em `tabela_preco` com `vigencia_inicio` e `vigencia_fim`. Quando a clínica reajusta, fecha-se a linha
antiga e cria-se uma nova. Na hora de marcar, a consulta copia o `valor_tabela` vigente e o `percentual_cobertura` do
convênio.

**Por quê:** se a tabela mudar, as consultas já marcadas e o faturamento antigo **não podem mudar junto**. Recalcular
sempre daria valores diferentes para a mesma consulta em dias diferentes. Essa cópia é uma **desnormalização feita de
propósito**: o valor guardado é histórico, não um dado repetido.

### Decisão 3 — O convênio fica no paciente **e** na consulta

`paciente.id_convenio` é o convênio **atual** (usado para sugerir na marcação). `consulta.id_convenio` é o convênio
**usado naquela consulta**.

**Por quê:** o paciente pode trocar de convênio. Se o convênio ficasse só no paciente, ao trocar, todas as consultas
antigas passariam a "pertencer" ao convênio novo e o faturamento por convênio ficaria errado. Guardando na consulta, cada
uma mantém o convênio com que foi atendida.

### Outras decisões (resumo)

| Ponto | Decisão |
|---|---|
| Agenda do médico | `horario_atendimento` (faixas fixas por dia da semana) + `bloqueio_agenda` (férias, congresso). Os **horários livres são calculados**, não gravados: gravar cada slot geraria milhares de linhas que precisariam ser refeitas a cada bloqueio ou mudança de agenda. |
| Conflito de horário | Verificado na procedure de agendamento (`data_hora_inicio`/`data_hora_fim`). Para duas sessões ao mesmo tempo, a procedure trava as linhas do médico e do paciente (`SELECT ... FOR UPDATE`) antes de checar; sem isso, as duas sessões poderiam ver o horário livre e gravar ao mesmo tempo. |
| Bloqueio por faltas | Não é uma coluna "bloqueado": é calculado contando consultas com status `faltou` nos últimos 90 dias e depois de `paciente.data_regularizacao`. Assim não há risco do campo ficar desatualizado. |
| Dados sensíveis | Schema `sensivel` separado (atendimento, diagnóstico, prescrição, exames, auditoria). Catálogos públicos (CID, medicamento, exame) ficam em `clinica`. |
| Dados clínicos variáveis | Coluna `JSONB` `dados_clinicos` no atendimento, porque cada paciente tem coisas diferentes para anotar. |
| Lembretes | Tabela `aviso` (um por consulta e canal) com `enviado_em` e `resposta`: o banco sabe quem foi avisado e quem confirmou, mesmo sem enviar nada. |

---

## 2. O que a turma corrigiu no nosso modelo (v1 → v2)

> ⚠️ Revisar com o grupo: confirmar que as mudanças abaixo são as que realmente vieram da apresentação para a turma.

| # | Como estava na v1 | O que a turma apontou | Como ficou na v2 |
|---|---|---|---|
| 1 | `medico` tinha uma coluna `id_especialidade` (FK direta). | O enunciado diz que um médico pode ter **mais de uma** especialidade; com FK direta só cabe uma. | Criada a tabela associativa `medico_especialidade` (N:N), com PK composta `(id_medico, id_especialidade)`. |
| 2 | O valor ficava só em `tipo_consulta.valor`, e a consulta não guardava valor nenhum. | Se o preço mudar, as consultas antigas e o faturamento mudam junto; e o retorno/cancelamento não tinha onde ficar registrado. | Criadas `tabela_preco` (histórico com vigência) e `pagamento` (valor total, parte do convênio, parte do paciente e regra aplicada). A consulta guarda `valor_tabela` e `percentual_cobertura` do dia. |
| 3 | Receita era um campo texto `receita` dentro do atendimento, e o CID era uma coluna `cid` também no atendimento. | Uma receita tem **vários medicamentos** e um atendimento pode ter mais de um diagnóstico: campo único viola a 1FN. | Criadas `prescricao` + `item_prescricao` (+ catálogo `medicamento`), `diagnostico` (N:N com `cid`) e `exame_solicitado` (N:N com `exame`). |
| 4 | Não havia como saber quem foi avisado; a recepção ainda ligaria para todos. | O relato pede ver "quem já foi avisado e quem confirmou". | Criada a tabela `aviso` e a coluna `consulta.confirmada_em`. |

---

## 3. Dúvida que ainda ficou (para o professor / Dra. Helena)

**O que conta como "falta" para o bloqueio de 3 faltas em 90 dias: só quem não aparece (`faltou`), ou também quem
cancela com menos de 24 horas?**

Hoje o modelo conta **só** o status `faltou`; o cancelamento tardio é cobrado (50%), mas não entra na contagem. Se a
clínica quiser contar os dois, basta incluir no cálculo as consultas `canceladas` cujo `cancelada_em` seja menos de 24 h
antes de `data_hora_inicio` — o modelo já guarda esses dados, só muda a regra na função `paciente_pode_agendar`.

Ligada a essa: **o que é "regularizar"?** Assumimos que a recepção registra uma data em `paciente.data_regularizacao` e
as faltas anteriores deixam de contar. Precisa pagar alguma multa antes?
