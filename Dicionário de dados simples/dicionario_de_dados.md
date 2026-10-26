# Dicionário de dados simples — Clínica Médica

Banco PostgreSQL com dois schemas:

- **`clinica`**: cadastros, agenda, valores, pagamentos e avisos.
- **`sensivel`**: prontuário (atendimento, diagnóstico, prescrição, exames) e auditoria. Fica separado porque são dados
  de saúde, protegidos pela LGPD, e só o médico que atendeu pode ver tudo.

O modelo tem **22 tabelas** (16 no schema `clinica` e 6 no `sensivel`). Abaixo estão todas, começando pelas principais.

Legenda das chaves: **PK** = chave primária · **FK** = chave estrangeira · **UK** = valor único (`UNIQUE`).

---

## 1. `clinica.paciente`

Cadastro das pessoas atendidas pela clínica, particulares ou de convênio.

| Campo | Chave | Explicação |
|---|---|---|
| id_paciente | PK | Número que identifica o paciente. |
| nome | | Nome completo do paciente. |
| cpf | UK | CPF, só os 11 números (opcional). Não pode haver dois pacientes com o mesmo CPF. |
| data_nascimento | | Data de nascimento, usada para calcular a idade. |
| telefone | | Telefone/WhatsApp para contato e lembretes. |
| email | | E-mail para os lembretes de consulta. |
| id_convenio | FK | Convênio **atual** do paciente (→ `convenio`). Vazio (`NULL`) quando é particular. |
| numero_carteirinha | | Número da carteirinha do convênio atual. |
| data_regularizacao | | Data em que a recepção regularizou o paciente bloqueado por faltas. Faltas anteriores a essa data deixam de contar para o bloqueio. |
| data_cadastro | | Quando o paciente foi cadastrado. |

## 1.1 `clinica.contato_emergencia`

Telefones de emergência de cada paciente. Relação **1:N**: um paciente pode ter vários contatos e cada contato
pertence a um único paciente.

| Campo | Chave | Explicação |
|---|---|---|
| id_contato | PK | Número que identifica o contato. |
| id_paciente | FK | Paciente a quem o contato pertence (→ `paciente`). |
| nome | | Nome da pessoa a ser avisada. |
| parentesco | | Relação com o paciente (ex.: mãe, cônjuge, vizinho). |
| telefone | UK | Telefone do contato. `UNIQUE (id_paciente, telefone)`: o mesmo número não se repete para o mesmo paciente. |
| principal | | Marca o contato a ser chamado primeiro. No máximo um principal por paciente (índice único parcial). |

## 2. `clinica.medico`

Cadastro dos médicos que atendem na clínica.

| Campo | Chave | Explicação |
|---|---|---|
| id_medico | PK | Número que identifica o médico. |
| nome | | Nome completo do médico. |
| sexo | | `M` ou `F`, usado para escrever "Dr." ou "Dra." antes do nome. |
| crm | UK | Registro no Conselho Regional de Medicina (ex.: `CRM-1001`). Cada médico tem um CRM único. |
| uf_crm | | Estado do CRM (opcional). |
| email | | E-mail do médico. |
| telefone | | Telefone do médico. |
| ativo | | Indica se o médico ainda atende na clínica (não apagamos médicos que já têm consultas). |

## 3. `clinica.consulta`

O **horário marcado**: quem, com qual médico, quando, de que tipo e em que situação está. É o centro do modelo.

| Campo | Chave | Explicação |
|---|---|---|
| id_consulta | PK | Número que identifica a consulta. |
| protocolo | UK | Código legível da consulta, no formato `CL-2026-000123` (gerado com `LPAD`). |
| id_paciente | FK | Paciente da consulta (→ `paciente`). |
| id_medico | FK | Médico que vai atender (→ `medico`). |
| id_tipo_consulta | FK | Primeira consulta, retorno ou exame de rotina (→ `tipo_consulta`). |
| id_convenio | FK | Convênio usado **nesta** consulta, copiado do paciente na hora de marcar (→ `convenio`). `NULL` = particular. |
| id_consulta_origem | FK | Para retornos: a consulta anterior que originou o retorno (→ `consulta`, autorrelacionamento). Serve para checar a regra dos 30 dias. |
| data_hora_inicio | | Data e hora em que a consulta começa. |
| data_hora_fim | | Data e hora em que termina (início + duração do tipo). Usada para detectar conflito de horário. |
| status | | Situação: `agendada`, `confirmada`, `realizada`, `cancelada` ou `faltou` (`CHECK`). |
| valor_tabela | | Valor de tabela do tipo de consulta **no dia em que foi marcada** (cópia de `tabela_preco`). |
| percentual_cobertura | | Percentual que o convênio cobria no dia da marcação (cópia de `convenio`). 0 para particular. |
| agendada_em | | Quando a consulta foi marcada. |
| confirmada_em | | Quando o paciente confirmou. `NULL` = ainda não confirmou. |
| cancelada_em | | Quando foi cancelada. Comparado com `data_hora_inicio` para saber se foi com menos de 24 h. |

## 4. `sensivel.atendimento` (prontuário)

O **que aconteceu** na consulta: registro clínico feito pelo médico. Uma consulta realizada tem no máximo um atendimento.

| Campo | Chave | Explicação |
|---|---|---|
| id_atendimento | PK | Número que identifica o atendimento. |
| id_consulta | FK, UK | Consulta a que o atendimento pertence (→ `consulta`). Único: relação 1:1. O médico e o paciente vêm da consulta. |
| inicio_atendimento | | Hora em que o médico começou a atender de fato. |
| fim_atendimento | | Hora em que terminou o atendimento. |
| queixa_principal | | O que o paciente relata como motivo da consulta. |
| anamnese | | Histórico e relato detalhado colhido pelo médico. |
| dados_clinicos | | `JSONB` com o que varia de paciente para paciente: pressão, peso, temperatura, alergias, outras queixas. |
| observacoes | | Anotações livres do médico. |

## 5. `clinica.pagamento`

O valor a receber de cada consulta, separando a parte do convênio e a parte do paciente.

| Campo | Chave | Explicação |
|---|---|---|
| id_pagamento | PK | Número que identifica o pagamento. |
| id_consulta | FK, UK | Consulta cobrada (→ `consulta`). Único: um pagamento por consulta. |
| valor_total | | Valor final cobrado depois de aplicar as regras. |
| valor_convenio | | Parte que o convênio paga. |
| valor_paciente | | Parte que o paciente paga. `valor_convenio + valor_paciente = valor_total` (`CHECK`). |
| regra_aplicada | | Regra usada no cálculo: `normal`, `retorno_gratuito`, `cancelamento_sem_custo` ou `cancelamento_tardio` (50%). |
| status | | `pendente`, `pago`, `isento` (retorno gratuito, valor 0) ou `cancelado`. |
| gerado_em | | Quando o pagamento foi criado (na marcação, como pendente). |
| pago_em | | Quando foi pago. `NULL` enquanto pendente. |

## 6. `clinica.convenio`

Planos de saúde aceitos pela clínica.

| Campo | Chave | Explicação |
|---|---|---|
| id_convenio | PK | Número que identifica o convênio. |
| nome | UK | Nome do convênio. |
| percentual_cobertura | | Percentual do valor que o convênio cobre (0 a 100, `CHECK`). |
| telefone | | Telefone de contato do convênio. |
| ativo | | Indica se a clínica ainda aceita esse convênio. |

## 7. `clinica.tipo_consulta`

Os tipos de consulta e quanto tempo cada um ocupa na agenda.

| Campo | Chave | Explicação |
|---|---|---|
| id_tipo_consulta | PK | Número que identifica o tipo. |
| nome | UK | `Primeira consulta`, `Retorno` ou `Exame de rotina`. |
| duracao_minutos | | Duração: 30, 20 ou 45 minutos (`CHECK > 0`). |

## 8. `clinica.tabela_preco`

Histórico de valores de cada tipo de consulta. Quando o preço muda, entra uma nova linha e a antiga ganha data de fim.

| Campo | Chave | Explicação |
|---|---|---|
| id_preco | PK | Número que identifica o preço. |
| id_tipo_consulta | FK | Tipo de consulta a que o preço se refere (→ `tipo_consulta`). |
| valor | | Valor de tabela em reais (`CHECK >= 0`). |
| vigencia_inicio | | Data a partir da qual o valor vale. |
| vigencia_fim | | Último dia de validade. `NULL` = é o preço atual. |

## 9. `clinica.horario_atendimento`

A agenda semanal fixa de cada médico: em que dias e em que faixa de horário ele atende.

| Campo | Chave | Explicação |
|---|---|---|
| id_horario | PK | Número que identifica a faixa de horário. |
| id_medico | FK | Médico dono do horário (→ `medico`). |
| dia_semana | | Dia da semana, de 0 (domingo) a 6 (sábado) (`CHECK`). |
| hora_inicio | | Hora em que começa a atender nesse dia. |
| hora_fim | | Hora em que para de atender (`CHECK hora_fim > hora_inicio`). |

## 10. `clinica.bloqueio_agenda`

Períodos em que o médico **não** atende, mesmo sendo dia de agenda: férias, congresso etc.

| Campo | Chave | Explicação |
|---|---|---|
| id_bloqueio | PK | Número que identifica o bloqueio. |
| id_medico | FK | Médico bloqueado (→ `medico`). |
| inicio | | Início do bloqueio (data e hora). |
| fim | | Fim do bloqueio (`CHECK fim > inicio`). |
| motivo | | `ferias`, `congresso` ou `outro`. |
| observacao | | Detalhe livre (ex.: nome do congresso). |

## 11. `clinica.especialidade`

Lista de especialidades médicas da clínica.

| Campo | Chave | Explicação |
|---|---|---|
| id_especialidade | PK | Número que identifica a especialidade. |
| nome | UK | Nome da especialidade (ex.: Cardiologia). |
| descricao | | Descrição curta. |

## 12. `clinica.medico_especialidade`

Tabela associativa da relação **N:N** entre médico e especialidade (um médico pode ter várias especialidades e uma
especialidade tem vários médicos).

| Campo | Chave | Explicação |
|---|---|---|
| id_medico | PK, FK | Médico (→ `medico`). |
| id_especialidade | PK, FK | Especialidade (→ `especialidade`). |
| rqe | | Registro de Qualificação de Especialista do médico naquela especialidade. |

## 13. `clinica.aviso`

Fila de lembretes por e-mail e WhatsApp. O envio é feito por outro sistema; o banco guarda o que precisa ser avisado,
o que já foi e a resposta do paciente.

| Campo | Chave | Explicação |
|---|---|---|
| id_aviso | PK | Número que identifica o aviso. |
| id_consulta | FK | Consulta lembrada (→ `consulta`). `UNIQUE (id_consulta, canal)`: um aviso por canal. |
| canal | | `email` ou `whatsapp`. |
| destino | | E-mail ou telefone usado no envio (cópia do cadastro no momento). |
| programado_para | | Quando o aviso deve sair (véspera da consulta). |
| enviado_em | | Quando o outro sistema enviou. `NULL` = ainda não enviado. |
| status_envio | | `pendente`, `enviado` ou `falhou`. |
| resposta | | `confirmou`, `cancelou` ou `sem_resposta`. |
| respondido_em | | Quando o paciente respondeu. |

## 14. `clinica.cid`

Catálogo da Classificação Internacional de Doenças.

| Campo | Chave | Explicação |
|---|---|---|
| codigo_cid | PK | Código CID (ex.: `I10`, `J45.0`). |
| descricao | | Nome da doença ou condição. |

## 15. `sensivel.diagnostico`

Tabela associativa **N:N** entre atendimento e CID: um atendimento pode ter vários diagnósticos.

| Campo | Chave | Explicação |
|---|---|---|
| id_atendimento | PK, FK | Atendimento (→ `atendimento`). |
| codigo_cid | PK, FK | Código da doença (→ `cid`). |
| principal | | Marca qual é o diagnóstico principal do atendimento. |
| observacao | | Comentário do médico sobre o diagnóstico. |

## 16. `sensivel.prescricao`

Cabeçalho da receita emitida em um atendimento.

| Campo | Chave | Explicação |
|---|---|---|
| id_prescricao | PK | Número que identifica a receita. |
| id_atendimento | FK | Atendimento em que foi emitida (→ `atendimento`). |
| emitida_em | | Data e hora da emissão. |
| validade_dias | | Por quantos dias a receita vale. |
| observacao | | Orientações gerais ao paciente. |

## 17. `sensivel.item_prescricao`

Cada medicamento de uma receita (associativa **N:N** entre prescrição e medicamento).

| Campo | Chave | Explicação |
|---|---|---|
| id_item | PK | Número que identifica o item. |
| id_prescricao | FK | Receita a que o item pertence (→ `prescricao`). |
| id_medicamento | FK | Medicamento receitado (→ `medicamento`). |
| dosagem | | Dose (ex.: `500 mg`). |
| posologia | | Como tomar (ex.: `1 comprimido a cada 8 horas`). |
| quantidade | | Quantidade de caixas/unidades. |
| duracao_dias | | Por quantos dias tomar. |

## 18. `clinica.medicamento`

Catálogo de medicamentos que podem ser receitados.

| Campo | Chave | Explicação |
|---|---|---|
| id_medicamento | PK | Número que identifica o medicamento. |
| nome | | Nome comercial. |
| principio_ativo | | Substância ativa (ex.: dipirona). |
| apresentacao | | Forma e concentração (ex.: `comprimido 500 mg`). |

## 19. `sensivel.exame_solicitado`

Exames pedidos pelo médico em um atendimento (associativa **N:N** entre atendimento e exame).

| Campo | Chave | Explicação |
|---|---|---|
| id_exame_solicitado | PK | Número que identifica o pedido. |
| id_atendimento | FK | Atendimento em que o exame foi pedido (→ `atendimento`). |
| id_exame | FK | Exame pedido (→ `exame`). |
| urgente | | Indica se o exame é urgente. |
| justificativa | | Motivo clínico do pedido. |

## 20. `clinica.exame`

Catálogo de exames que podem ser pedidos.

| Campo | Chave | Explicação |
|---|---|---|
| id_exame | PK | Número que identifica o exame. |
| nome | UK | Nome do exame (ex.: Hemograma completo). |
| codigo | | Código do exame na tabela usada pelos convênios. |
| preparo | | Instruções de preparo para o paciente (jejum etc.). |

## 21. `sensivel.auditoria_prontuario`

Registro de toda alteração no prontuário, preenchido por trigger (entrega 3). Não tem FK de propósito: o histórico
precisa continuar existindo mesmo se o registro original for apagado.

| Campo | Chave | Explicação |
|---|---|---|
| id_auditoria | PK | Número que identifica o registro de auditoria. |
| tabela | | Tabela alterada (ex.: `atendimento`). |
| id_registro | | Id da linha alterada. |
| operacao | | `INSERT`, `UPDATE` ou `DELETE`. |
| usuario | | Usuário do banco que fez a alteração. |
| data_hora | | Quando a alteração aconteceu. |
| dados_antes | | Linha antes da alteração, em `JSONB`. |
| dados_depois | | Linha depois da alteração, em `JSONB`. |
