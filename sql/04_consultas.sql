-- =====================================================================
-- Clínica Médica — 04_consultas.sql
-- Consultas com JOIN para conferir os dados carregados em 02_carga.sql
-- (troca os IDs pelos nomes). Rodar depois de 01_ddl.sql e 02_carga.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Médicos e suas especialidades (Neurologia aparece sem médico)
-- ---------------------------------------------------------------------
SELECT e.nome AS especialidade, m.nome AS medico, m.crm
FROM clinica.especialidade e
LEFT JOIN clinica.medico_especialidade me ON me.id_especialidade = e.id_especialidade
LEFT JOIN clinica.medico               m  ON m.id_medico         = me.id_medico
ORDER BY e.nome, m.nome;

-- ---------------------------------------------------------------------
-- 2. Agenda semanal dos médicos
-- ---------------------------------------------------------------------
SELECT m.nome AS medico, h.dia_semana, h.hora_inicio, h.hora_fim
FROM clinica.horario_atendimento h
JOIN clinica.medico m ON m.id_medico = h.id_medico
ORDER BY m.nome, h.dia_semana, h.hora_inicio;

-- ---------------------------------------------------------------------
-- 3. Bloqueios de agenda
-- ---------------------------------------------------------------------
SELECT m.nome AS medico, b.inicio, b.fim, b.motivo, b.observacao
FROM clinica.bloqueio_agenda b
JOIN clinica.medico m ON m.id_medico = b.id_medico
ORDER BY b.inicio;

-- ---------------------------------------------------------------------
-- 4. Pacientes e convênio (NULL = particular)
-- ---------------------------------------------------------------------
SELECT p.nome AS paciente, p.data_nascimento,
       COALESCE(c.nome, 'Particular') AS convenio,
       COALESCE(c.percentual_cobertura, 0) AS cobertura
FROM clinica.paciente p
LEFT JOIN clinica.convenio c ON c.id_convenio = p.id_convenio
ORDER BY p.nome;

-- ---------------------------------------------------------------------
-- 5. Contatos de emergência
-- ---------------------------------------------------------------------
SELECT p.nome AS paciente, ce.nome AS contato, ce.parentesco, ce.telefone, ce.principal
FROM clinica.contato_emergencia ce
JOIN clinica.paciente p ON p.id_paciente = ce.id_paciente
ORDER BY p.nome, ce.principal DESC;

-- ---------------------------------------------------------------------
-- 6. Histórico de preços por tipo de consulta (reajuste da Entrada 3)
-- ---------------------------------------------------------------------
SELECT t.nome AS tipo, t.duracao_minutos, tp.valor, tp.vigencia_inicio, tp.vigencia_fim
FROM clinica.tabela_preco tp
JOIN clinica.tipo_consulta t ON t.id_tipo_consulta = tp.id_tipo_consulta
ORDER BY t.nome, tp.vigencia_inicio;

-- ---------------------------------------------------------------------
-- 7. Consultas completas, com retorno de origem e pagamento
-- ---------------------------------------------------------------------
SELECT co.id_consulta, co.protocolo, co.data_hora_inicio, co.status,
       p.nome  AS paciente,
       m.nome  AS medico,
       t.nome  AS tipo,
       COALESCE(cv.nome, 'Particular') AS convenio,
       co.valor_tabela, co.percentual_cobertura,
       orig.data_hora_inicio AS retorno_de,
       pg.valor_total, pg.valor_convenio, pg.valor_paciente,
       pg.regra_aplicada, pg.status AS status_pagamento
FROM clinica.consulta co
JOIN clinica.paciente       p    ON p.id_paciente       = co.id_paciente
JOIN clinica.medico         m    ON m.id_medico         = co.id_medico
JOIN clinica.tipo_consulta  t    ON t.id_tipo_consulta  = co.id_tipo_consulta
LEFT JOIN clinica.convenio  cv   ON cv.id_convenio      = co.id_convenio
LEFT JOIN clinica.consulta  orig ON orig.id_consulta    = co.id_consulta_origem
LEFT JOIN clinica.pagamento pg   ON pg.id_consulta      = co.id_consulta
ORDER BY co.data_hora_inicio;

-- ---------------------------------------------------------------------
-- 8. Agenda de hoje
-- ---------------------------------------------------------------------
SELECT co.data_hora_inicio, co.data_hora_fim, m.nome AS medico, p.nome AS paciente,
       t.nome AS tipo, co.status
FROM clinica.consulta co
JOIN clinica.paciente      p ON p.id_paciente      = co.id_paciente
JOIN clinica.medico        m ON m.id_medico        = co.id_medico
JOIN clinica.tipo_consulta t ON t.id_tipo_consulta = co.id_tipo_consulta
WHERE co.data_hora_inicio::DATE = CURRENT_DATE
ORDER BY co.data_hora_inicio;

-- ---------------------------------------------------------------------
-- 9. Prontuário: atendimento, diagnóstico principal e médico
-- ---------------------------------------------------------------------
SELECT p.nome AS paciente, m.nome AS medico, a.inicio_atendimento,
       a.queixa_principal, d.codigo_cid, cid.descricao AS diagnostico
FROM sensivel.atendimento a
JOIN clinica.consulta     co  ON co.id_consulta    = a.id_consulta
JOIN clinica.paciente     p   ON p.id_paciente     = co.id_paciente
JOIN clinica.medico       m   ON m.id_medico       = co.id_medico
LEFT JOIN sensivel.diagnostico d ON d.id_atendimento = a.id_atendimento AND d.principal
LEFT JOIN clinica.cid     cid ON cid.codigo_cid    = d.codigo_cid
ORDER BY a.inicio_atendimento;

-- ---------------------------------------------------------------------
-- 10. Receitas e seus medicamentos
-- ---------------------------------------------------------------------
SELECT p.nome AS paciente, pr.emitida_em, md.nome AS medicamento,
       md.apresentacao, ip.dosagem, ip.posologia
FROM sensivel.item_prescricao ip
JOIN sensivel.prescricao  pr ON pr.id_prescricao  = ip.id_prescricao
JOIN sensivel.atendimento a  ON a.id_atendimento  = pr.id_atendimento
JOIN clinica.consulta     co ON co.id_consulta    = a.id_consulta
JOIN clinica.paciente     p  ON p.id_paciente     = co.id_paciente
JOIN clinica.medicamento  md ON md.id_medicamento = ip.id_medicamento
ORDER BY p.nome, md.nome;

-- ---------------------------------------------------------------------
-- 11. Exames solicitados
-- ---------------------------------------------------------------------
SELECT p.nome AS paciente, a.inicio_atendimento, ex.nome AS exame, es.urgente
FROM sensivel.exame_solicitado es
JOIN sensivel.atendimento a  ON a.id_atendimento = es.id_atendimento
JOIN clinica.consulta     co ON co.id_consulta   = a.id_consulta
JOIN clinica.paciente     p  ON p.id_paciente    = co.id_paciente
JOIN clinica.exame        ex ON ex.id_exame      = es.id_exame
ORDER BY p.nome;
