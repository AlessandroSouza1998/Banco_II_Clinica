# Projeto 2 — Clínica médica

Estrutura comum das entregas (GitHub, tags, notas): [00-estrutura-das-entregas.md](00-estrutura-das-entregas.md).
Projeto de referência já detalhado: [01-biblioteca.md](01-biblioteca.md).

## Cenário

Uma clínica atende **particulares e pacientes de convênios** com médicos de várias especialidades. A clínica quer
controlar a **agenda** (sem horários em conflito), registrar o **atendimento e o prontuário**, calcular o valor de cada
consulta e proteger os **dados sensíveis** dos pacientes. Todos os dados do projeto são **fictícios**.

## Solicitação do usuário

**Solicitante:** Dra. Helena, diretora clínica e recepcionista-chefe da clínica (ela acumula as funções). Leia o relato como
se ela tivesse chamado você para fazer o sistema. O que ela não explicou, você pergunta ao professor (ele faz o papel dela).
A modelagem é sua.

### O relato da Dra. Helena

> Somos uma clínica com 12 médicos de várias especialidades. Atendemos particulares e pacientes de convênio. Hoje a
> agenda é uma planilha por médico e o prontuário é uma pasta de papel. Já marcamos duas consultas no mesmo horário.
>
> **Meu dia começa** olhando a agenda do dia: quem vem, com qual médico, se é primeira consulta, retorno ou exame de
> rotina. Ligo para quem ainda não confirmou.
>
> **Para marcar uma consulta**, preciso ver os horários livres do médico. Cada médico atende em dias e horários
> diferentes, e às vezes sai de férias ou vai a congresso, e nesses dias não pode haver consulta. A primeira consulta
> dura 30 minutos, o retorno 20 e o exame de rotina 45. Cada tipo tem um valor de tabela.
>
> **Retorno é gratuito** se for feito em até 30 dias da consulta anterior com o mesmo médico. O paciente de convênio paga
> só a parte que o convênio não cobre (cada convênio cobre um percentual). O particular paga tudo.
>
> **Cancelamento:** até 24 horas antes, sem custo. Depois disso, cobramos metade do valor. Quem **falta 3 vezes em 90
> dias** não marca mais consulta até regularizar.
>
> **No atendimento**, o médico registra a queixa, o diagnóstico (com o código CID, a Classificação Internacional de
> Doenças), as receitas (com vários medicamentos) e os exames pedidos. Também anota pressão, peso, temperatura e
> alergias, mas cada paciente tem coisas diferentes para anotar. O prontuário é sigiloso: só o médico que atendeu vê tudo.

### Minhas dificuldades hoje

1. **Conflito de horário:** o mesmo médico, ou o mesmo paciente, marcado em duas consultas ao mesmo tempo.
2. Não sei **quem faltou** e quantas vezes. Descubro quando o paciente reclama.
3. Quero que o sistema **lembre o paciente por e-mail e WhatsApp** na véspera da consulta, e que eu veja quem já foi
   avisado e quem confirmou.
4. Calculo o valor da consulta (convênio, retorno gratuito, cancelamento tardio) de cabeça e erro.
5. Não sei **quais horários cada médico tem livres** nesta semana.
6. Quero saber **quais especialidades e quais médicos mais atendem**, para decidir contratações.

### O que quero ver quando abrir o sistema

- A **agenda do dia** de cada médico, com o status de cada consulta.
- Os **horários livres** de um médico em um período.
- Os pacientes **bloqueados** por faltas.
- O **valor a receber** de cada consulta, separando o que é do convênio e o que é do paciente.
- Quem **ainda não confirmou** a consulta de amanhã.

### O que guardo hoje

| Onde | O que tem |
|---|---|
| Planilha por médico | dia, horário, paciente, tipo de consulta, situação |
| Cadastro de pacientes | nome, CPF, nascimento, telefone, e-mail, convênio e carteirinha |
| Pasta de papel | queixa, diagnóstico, receitas, exames pedidos, sinais vitais |
| Caderno da recepção | faltas e cancelamentos |

### Perguntas para fazer à Dra. Helena

- Um médico pode ter mais de uma especialidade? O CRM (Conselho Regional de Medicina) é único?
- O paciente pode trocar de convênio? O que vale para consultas antigas?
- Se a tabela de valores mudar, o que acontece com consultas já marcadas?
- O que conta como "falta": só quem não aparece, ou também quem cancela de última hora?

> O envio real de e-mail e WhatsApp é feito por outro sistema. **O banco de dados guarda o que precisa ser avisado e o que
> já foi avisado.**

## Regras de negócio

| Regra | Valor |
|---|---|
| Especialidades | Um médico pode ter mais de uma; cada médico tem CRM único |
| Agenda do médico | Horários de atendimento por dia da semana (início e fim) e bloqueios (férias, congresso) |
| Tipos de consulta | Primeira consulta (30 min), retorno (20 min), exame de rotina (45 min), cada um com valor de tabela |
| Conflito | Um médico não atende duas consultas ao mesmo tempo; um paciente não tem duas consultas ao mesmo tempo |
| Retorno | Gratuito se feito em até 30 dias da consulta anterior com o mesmo médico |
| Convênio | O convênio cobre um percentual do valor; o restante é do paciente. Particular paga 100% |
| Cancelamento | Até 24 horas antes, sem custo; depois, cobra 50% do valor |
| Faltas | Paciente com 3 faltas nos últimos 90 dias não pode agendar até regularizar |
| Status da consulta | Agendada, confirmada, realizada, cancelada, faltou |
| Prontuário | Anamnese, diagnóstico (CID), prescrições (vários itens), exames solicitados. Só o médico do atendimento vê o prontuário completo |

## Modelo mínimo (a decidir pelo grupo; pelo menos 8 tabelas)

Especialidade, médico, médico-especialidade, paciente, convênio, tipo de consulta (duração e valor), horário de atendimento,
bloqueio de agenda, consulta, atendimento (prontuário), prescrição (itens), exame solicitado, pagamento.
O grupo decide e **justifica** o desenho.

**Pontos que exigem decisão** (a prova cobra a justificativa):

1. Consulta (o horário marcado) x atendimento (o que aconteceu): uma tabela ou duas?
2. Como representar a agenda semanal do médico e os bloqueios? Os horários livres são calculados ou gravados?
3. Como o banco **impede conflito de horário**: **só na procedure** (D-26), sem restrição no banco. O que isso garante e o que não garante, principalmente com duas sessões ao mesmo tempo?
4. O convênio do paciente muda com o tempo: guardar o convênio na consulta ou só no paciente?
5. O valor da consulta: guardar o valor calculado no momento ou recalcular sempre? E se a tabela de valores mudar?
6. Dados sensíveis (prontuário, CID): separar em tabelas e schemas diferentes? Por quê? (O curso não cobre roles e permissões: a regra de quem vê o prontuário fica documentada no `README.md`.)

## Dados de apoio

- Coluna `dados_clinicos` (`JSONB`) no atendimento: sinais vitais (pressão, peso, temperatura), alergias, queixas e outros
  campos que variam de atendimento para atendimento.
- Número do protocolo da consulta no formato `CL-2026-000123`, gerado com `LPAD`.

## Entrega 1 — Prova 1 (aula 12): modelo, DDL, carga e transações

Tag: `prova-1`. As transações são dadas na aula 11, um dia antes: a entrega é pequena e guiada pelo exercício do dia.

| # | Item | Arquivo | O que entregar |
|---|---|---|---|
| 1 | Modelo | `diagrama/` | Diagrama no ERD Concepts (conceitual e lógico) com cardinalidades, e a imagem exportada |
| 2 | Estrutura | `sql/01_ddl.sql` | Schema `clinica` (e um schema separado para dados sensíveis, se o grupo decidir), 8 ou mais tabelas, `PK`, `FK`, `UNIQUE`, `CHECK` e `DEFAULT` para as regras que o banco consegue garantir |
| 3 | Normalização | `README.md` | Justificar até a 3FN e dizer uma desnormalização feita de propósito, se houver |
| 4 | Carga | `sql/02_carga.sql` | 15 médicos, 6 especialidades, 50 pacientes, 3 convênios, 150 consultas (em todos os status), 100 atendimentos com prescrições e exames, bloqueios de agenda. Dados que **exercitam as regras** (paciente com 3 faltas, retorno em 30 dias) |
| 5 | Transações | `sql/03_transacoes.sql` | Agendamento como transação (verificar conflito, inserir a consulta e o pagamento pendente, tudo ou nada), com `ROLLBACK` quando falhar |
| 6 | Concorrência | `sql/03_transacoes.sql` + `evidencias/` | **Duas sessões disputando o mesmo horário do mesmo médico**: mostrar o problema, a solução (bloqueio de linha ou isolamento) e explicar por quê |
| 7 | Decisões | `README.md` | As respostas dos 6 pontos de decisão acima, por que a transação protege o que protege, divisão do trabalho e uso de IA |

Dado na aula: modelagem (9), análise de bancos (10), transações e ACID (11), DDL e normalização (revisão, aulas 2 e 3).

## Entrega 2 — Prova 2 (aula 16): funções SQL, subconsultas/CTE, `JSONB`, window functions e views

Tag: `prova-2`.

| # | Item | Arquivo | O que entregar |
|---|---|---|---|
| 1 | Funções SQL | `sql/04_consultas.sql` | 10 consultas, entre elas: protocolo com `LPAD`, nome com título (`Dr.`/`Dra.`) formatado, idade do paciente (`AGE`), horário de término (`início + intervalo`), consultas por mês (`DATE_TRUNC`), dia da semana mais movimentado (`TO_CHAR` ou `EXTRACT`), faixa etária (`CASE`), `COALESCE` para "Particular" quando não há convênio |
| 2 | Subconsultas e CTE | `sql/04_consultas.sql` | 3 ou mais: pacientes sem consulta nos últimos 6 meses, médicos com mais consultas que a média, taxa de faltas por médico feita com CTE em etapas |
| 3 | `JSONB` | `sql/04_consultas.sql` | 3 consultas sobre `dados_clinicos` (pacientes com alergia a um item, pressão acima de um valor, listar queixas) |
| 4 | Window functions | `sql/05_janelas_views.sql` | 2 consultas: ranking de médicos por especialidade em consultas realizadas (`RANK`) e faturamento acumulado por mês |
| 5 | Views | `sql/05_janelas_views.sql` | `vw_agenda_do_dia` e uma view materializada com faturamento mensal, com atualização |
| 6 | Decisões | `README.md` | Decisões, o que a IA errou, divisão do trabalho |

Dado na aula: funções SQL (13), subconsultas, CTE e `JSONB` (14), window functions e views (15).

## Entrega 3 — Prova 3 (aula 21): índice, funções, procedures e triggers

Tag: `prova-3`. Com o bloco de `PL/pgSQL` em três dias (aulas 18 a 20, com 40 min de projeto por dia), a entrega pede
**mais rotinas e testadas**, e a parte de índice segue enxuta.

| # | Item | Arquivo | O que entregar |
|---|---|---|---|
| 1 | Índice | `sql/06_indices.sql` + `evidencias/` | Carga em volume (100 mil consultas ou mais, com `generate_series`), **1 consulta lenta** (agenda de um médico em um período), `EXPLAIN` antes e depois do índice e explicação |
| 2 | Funções | `sql/07_funcoes.sql` | 3 ou mais: `calcular_valor(consulta)` (convênio, particular e retorno gratuito), `horario_disponivel(médico, início, tipo)` (dentro da agenda e sem conflito, retornando o motivo) e `paciente_pode_agendar(paciente)` (3 faltas em 90 dias). Cada uma com chamada de teste e resultado em `evidencias/` |
| 3 | Procedures | `sql/08_procedures.sql` | 3: `agendar_consulta(paciente, médico, início, tipo)` aplicando as regras principais, `cancelar_consulta(consulta)` (50% após o prazo de 24 horas) e `registrar_atendimento(consulta, ...)` (cria o atendimento e muda o status para `realizada`). Erros com `RAISE EXCEPTION` e mensagens claras, cada uma com um teste que dá certo e um que falha |
| 4 | Triggers | `sql/09_triggers.sql` | 2: **auditoria** de alterações no prontuário (quem, quando, antes e depois) e **regra de negócio** (ao mudar o status da consulta para `realizada`, gerar o pagamento com `calcular_valor`), com um teste de cada |
| 5 | Decisões | `README.md` | Onde cada regra ficou (função, procedure, trigger ou `CHECK`) e por quê, divisão do trabalho, uso de IA |

Dado na aula: índices e `generate_series` (17), funções (18), procedures (19), triggers (20).

## Entrega final — Prova 4 (aulas 23 e 24): apresentação

Tag: `final`.

- **Demonstração (6 min):** um cenário de ponta a ponta: paciente agenda, o sistema recusa um horário em conflito, a consulta
  é realizada com prontuário, o valor é calculado com convênio e o relatório mostra o faturamento. Executado ao vivo por uma procedure.
- **Desenvolvimento do projeto (4 min):** linha do tempo, decisões difíceis, dificuldades, o que a IA errou e o que o grupo aprendeu.
- **Entrega:** repositório com `instalar.sql` que recria o banco do zero e `README.md` final.

## Rubrica (parte do grupo, 10 pontos por prova)

| Prova | Item | Pontos |
|---|---|---|
| 1 | Modelo e justificativas (itens 1, 3 e 7) | 3,0 |
| 1 | DDL com regras no banco (item 2) | 2,5 |
| 1 | Carga que exercita as regras (item 4) | 1,5 |
| 1 | Transação e concorrência, com explicação (itens 5 e 6) | 3,0 |
| 2 | Funções SQL (item 1) | 2,5 |
| 2 | Subconsultas e CTE (item 2) | 2,0 |
| 2 | `JSONB` (item 3) | 1,0 |
| 2 | Window functions e views (itens 4 e 5) | 3,0 |
| 2 | Decisões e uso de IA (item 6) | 1,5 |
| 3 | Índice com `EXPLAIN` e análise (item 1) | 2,0 |
| 3 | Funções (item 2) | 2,0 |
| 3 | Procedures (item 3) | 2,0 |
| 3 | Triggers (item 4) | 2,5 |
| 3 | Decisões e uso de IA (item 5) | 1,5 |
| 4 | Demonstração: cenário de ponta a ponta, regras de negócio funcionando ao vivo | 4,0 |
| 4 | Desenvolvimento do projeto: linha do tempo, decisões e dificuldades | 2,5 |
| 4 | Uso de IA: o que a IA errou e o que o grupo corrigiu | 1,5 |
| 4 | Entrega: `instalar.sql` que recria o banco do zero, `README.md` e divisão do trabalho | 2,0 |

Penalidade: entrega que não roda do zero, sem `README.md` ou sem divisão do trabalho perde até 2 pontos.
Na prova 4 não há penalidade à parte: o critério «Entrega» já cobre `instalar.sql`, `README.md` e divisão do trabalho. As perguntas do professor entram na parte individual (40%).
A nota do aluno é 60% desta parte (grupo) e 40% individual (20% a parte apresentada e 20% a pergunta individual, D-36).

## Diferenças em relação à biblioteca

- O ponto forte é o **conflito de horários**: concorrência (prova 2) e regra na procedure (prova 3).
- A **proteção do prontuário** pesa na auditoria por trigger (prova 3) e na decisão de separar os dados sensíveis (ponto 6).
- O `JSONB` guarda dados clínicos que variam; na biblioteca guardava metadados do livro.
