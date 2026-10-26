# Banco_II_Clinica

Projeto de um banco de dados (PostgreSQL) para uma clínica médica que atende particulares e pacientes de convênio.
O sistema controla a **agenda** (sem conflitos de horário), o **atendimento e o prontuário**, o **valor de cada consulta**
e protege os **dados sensíveis** dos pacientes. Todos os dados são **fictícios**.

Enunciado completo: [Contexto/02-clinica-medica.md](Contexto/02-clinica-medica.md).

---

## Estrutura do repositório

| Pasta / arquivo | Conteúdo |
|---|---|
| [Contexto/](Contexto/) | Enunciado do projeto (relato da Dra. Helena, regras e entregas) |
| [Modelagem/](Modelagem/) | Diagrama ER (MER) exportado em PDF, PNG e SVG |
| [Dicionário de dados simples/](Dicionário%20de%20dados%20simples/) | Dicionário de dados de todas as tabelas |
| [Decisões e correção/](Decisões%20e%20correção/) | Decisões de modelagem e correções v1 → v2 |
| [sql/01_ddl.sql](sql/01_ddl.sql) | Criação dos schemas, tabelas e restrições |
| [sql/02_carga.sql](sql/02_carga.sql) | Carga de dados fictícios que exercitam as regras |
| `sql/03_transacoes.sql` | Agendamento como transação e teste de concorrência *(a entregar)* |
| [sql/04_consultas.sql](sql/04_consultas.sql) | Consultas (funções SQL, subconsultas/CTE, `JSONB`) |
| `sql/05_janelas_views.sql` | Window functions e views *(a entregar)* |
| `evidencias/` | Prints das execuções (concorrência, `EXPLAIN`, testes) *(a entregar)* |

### Como executar

```sql
-- no psql, dentro da pasta do projeto
\i sql/01_ddl.sql
\i sql/02_carga.sql
\i sql/04_consultas.sql
```

O `01_ddl.sql` apaga e recria os schemas, então pode ser executado quantas vezes for preciso.

---

## Modelo

Dois schemas:

- **`clinica`** — cadastros, agenda, valores, pagamentos e avisos:
  `especialidade`, `medico`, `medico_especialidade`, `horario_atendimento`, `bloqueio_agenda`, `convenio`, `paciente`,
  `contato_emergencia`, `tipo_consulta`, `tabela_preco`, `consulta`, `pagamento`, `aviso`, e os catálogos públicos
  `cid`, `medicamento` e `exame`.
- **`sensivel`** — prontuário e auditoria:
  `atendimento`, `diagnostico`, `prescricao`, `item_prescricao`, `exame_solicitado`, `auditoria_prontuario`.

Total: **22 tabelas**. Diagrama em [Modelagem/MER_clinica_medica.png](Modelagem/MER_clinica_medica.png).

Regras garantidas pelo próprio banco (DDL): `PK`, `FK`, `UNIQUE` (CRM, CPF, nome do convênio, um atendimento por consulta),
`CHECK` (status da consulta, dia da semana 0–6, `hora_fim > hora_inicio`, `fim > inicio` nos bloqueios, percentual de
cobertura entre 0 e 100, motivo do bloqueio) e `DEFAULT` (status `agendada`, `dados_clinicos = '{}'`, protocolo
`CL-2026-000123` gerado com `LPAD` a partir de uma sequence).

---

## Normalização (até a 3FN)

- **1FN** — Todos os atributos são atômicos. Nada de listas em uma coluna: um médico com várias especialidades usa
  `medico_especialidade`; uma receita com vários medicamentos usa `prescricao` + `item_prescricao`; vários diagnósticos
  usam `diagnostico` (N:N com `cid`); vários exames usam `exame_solicitado`. A exceção consciente é `dados_clinicos`
  (`JSONB`), que guarda sinais vitais e anotações que variam de paciente para paciente (pedido do enunciado).
- **2FN** — As tabelas com PK composta (`medico_especialidade`) só têm atributos que dependem da chave inteira
  (ex.: `rqe` depende do médico **e** da especialidade). As demais têm PK simples (`SERIAL`).
- **3FN** — Não há dependência transitiva: o atendimento não repete médico nem paciente (vêm da consulta); a duração
  fica em `tipo_consulta` e o preço em `tabela_preco`; o nome do convênio fica só em `convenio`.

### Desnormalização feita de propósito

A `consulta` guarda uma **"foto"** do `valor_tabela` e do `percentual_cobertura` no momento da marcação, e também o
`id_convenio` usado. Esses dados poderiam ser obtidos por junção, mas **mudam com o tempo** (reajuste de tabela, troca de
convênio, mudança no percentual). Guardar o valor do dia impede que o faturamento antigo mude. Ou seja: é um dado
histórico, não uma repetição.

---

## Respostas aos 6 pontos de decisão

### 1. Consulta x atendimento: uma tabela ou duas?

**Duas.** `consulta` é o horário marcado (paciente, médico, tipo, início/fim, status). `sensivel.atendimento` é o que
aconteceu (queixa, diagnóstico, receitas, exames, `dados_clinicos`), em relação **1:1** (`id_consulta UNIQUE`).
Canceladas e faltas nunca têm prontuário, então uma tabela só teria muitas colunas vazias; além disso, a consulta é
pública para a recepção e o atendimento é sigiloso.

### 2. Agenda semanal e bloqueios: horários livres calculados ou gravados?

`horario_atendimento` guarda as faixas fixas por **dia da semana** (início e fim) e `bloqueio_agenda` guarda os períodos
sem atendimento (férias, congresso, outro). Os **horários livres são calculados** (faixa do dia − bloqueios − consultas
não canceladas). Gravar cada horário geraria milhares de linhas que teriam de ser refeitas a cada bloqueio ou mudança
de agenda.

### 3. Como o banco impede conflito de horário (só na procedure)

A verificação fica **na procedure de agendamento** (D-26), sem restrição no banco (sem `EXCLUDE`). Ela procura consultas
não canceladas do mesmo médico **ou** do mesmo paciente cujo intervalo se sobreponha
(`novo_inicio < data_hora_fim AND novo_fim > data_hora_inicio`).

- **O que garante:** quem agenda pela procedure, em uma sessão de cada vez, nunca grava conflito.
- **O que não garante:** um `INSERT` direto na tabela (fora da procedure) passa sem checagem. E, com **duas sessões ao
  mesmo tempo**, as duas podem ler "horário livre" antes de qualquer uma gravar e as duas inserem (condição de corrida).
- **Solução:** dentro da transação, travar a linha do médico e do paciente com `SELECT ... FOR UPDATE` antes de checar.
  A segunda sessão espera a primeira terminar; quando continua, já enxerga a consulta gravada e recebe o erro de conflito
  (ou usa-se isolamento `SERIALIZABLE`, em que uma das transações falha e precisa ser repetida).

### 4. Convênio: na consulta ou só no paciente?

**Nos dois.** `paciente.id_convenio` é o convênio **atual** (sugerido na marcação); `consulta.id_convenio` é o convênio
**usado naquela consulta**. Se o paciente trocar de convênio, as consultas antigas continuam com o convênio original e o
faturamento por convênio fica correto.

### 5. Valor da consulta: guardar ou recalcular?

**Guardar.** Os preços ficam em `tabela_preco` com vigência (`vigencia_inicio`/`vigencia_fim`). Na marcação, a consulta
copia o valor vigente e o percentual do convênio; o `pagamento` guarda valor total, parte do convênio, parte do paciente e
a regra aplicada (normal, retorno gratuito, cancelamento tardio 50%). Se a tabela mudar, só as consultas **novas** usam o
valor novo; as já marcadas mantêm o valor combinado.

### 6. Dados sensíveis: separar em tabelas e schemas?

**Sim.** Prontuário, diagnósticos (CID), prescrições, exames solicitados e auditoria ficam no schema **`sensivel`**;
catálogos públicos (`cid`, `medicamento`, `exame`) ficam em `clinica`. A separação deixa claro o que é sigiloso e permite,
no futuro, liberar o schema `clinica` para a recepção e fechar o `sensivel` com permissões (roles), sem mexer no modelo.

#### Regra de acesso ao prontuário (documentada, pois o curso não cobre roles)

- **Recepção:** acessa só o schema `clinica` (agenda, pacientes, pagamentos, avisos). Nunca lê o `sensivel`.
- **Médico do atendimento:** é o único que vê o prontuário completo daquele atendimento.
- **Outros médicos:** não veem o prontuário de atendimentos que não fizeram.
- **Toda alteração** no prontuário é registrada em `sensivel.auditoria_prontuario` (quem, quando, antes e depois — por
  trigger na prova 3).

---

## Outras regras de negócio e onde ficam

| Regra | Como foi tratada |
|---|---|
| Médico com várias especialidades / CRM único | `medico_especialidade` (N:N) e `UNIQUE (crm)` |
| Duração por tipo (30/20/45 min) | `tipo_consulta.duracao`; `data_hora_fim = início + duração` |
| Retorno gratuito em 30 dias | Consulta de retorno aponta a consulta de origem; cálculo do valor verifica mesmo médico e ≤ 30 dias |
| Convênio x particular | Percentual de cobertura do convênio; sem convênio (`NULL`) = particular, paga 100% |
| Cancelamento | Até 24 h antes sem custo; depois, 50% (registrado em `pagamento`) |
| Bloqueio por 3 faltas em 90 dias | **Calculado** (conta `faltou` nos últimos 90 dias e após `paciente.data_regularizacao`), sem coluna "bloqueado" |
| Status | `CHECK` com `agendada`, `confirmada`, `realizada`, `cancelada`, `faltou` |
| Lembretes por e-mail/WhatsApp | Tabela `aviso` (por consulta e canal) com `enviado_em` e `resposta`; o envio real é de outro sistema |

### Dúvidas levadas à Dra. Helena (professor)

- **Falta** conta só `faltou`, ou também cancelamento com menos de 24 h? Hoje o modelo conta só `faltou`.
- **Regularizar** é apenas registrar a data em `paciente.data_regularizacao` ou exige pagamento de multa?

Mais detalhes em [Decisões e correção/decisoes.md](Decisões%20e%20correção/decisoes.md).

---

## Por que a transação protege o que protege

O agendamento é uma transação **tudo ou nada**: verificar conflito → inserir a consulta → inserir o pagamento pendente.
Se qualquer passo falhar (conflito, paciente bloqueado, médico sem agenda), é feito `ROLLBACK` e nada fica gravado pela
metade (**atomicidade**). Os `CHECK`/`FK` mantêm a **consistência**; o `SELECT ... FOR UPDATE` dá **isolamento** entre duas
sessões que disputam o mesmo horário; e o `COMMIT` garante a **durabilidade**. A transação **não** protege contra quem
grava direto na tabela sem passar pela procedure.

---

## Divisão do trabalho

| Integrante | Responsabilidade |
|---|---|
| Alessandro Almeida de Souza | Modelagem, DDL, carga, consultas e documentação |
| *(preencher)* | *(preencher)* |
| *(preencher)* | *(preencher)* |

## Uso de IA

| Onde usamos | O que a IA errou / o que corrigimos |
|---|---|
| Rascunho do dicionário de dados e do README | *(preencher: ex. sugeriu FK direta médico → especialidade, corrigido para N:N)* |
| Geração de dados fictícios da carga | *(preencher: ex. gerou consultas em conflito / fora da agenda do médico)* |
| Consultas SQL | *(preencher)* |

Todo conteúdo gerado por IA foi revisado e testado pelo grupo antes de entrar no repositório.

