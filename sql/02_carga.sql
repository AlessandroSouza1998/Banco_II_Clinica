-- =====================================================================
-- Clínica Médica — 02_carga.sql (seed)
-- Carga com os dados das Entradas 1 a 5, na ordem em que aconteceram.
-- Rodar logo depois de 01_ddl.sql (banco recém-criado): as chaves são
-- SERIAL e começam em 1, então os IDs usados abaixo seguem a ordem de
-- inserção (indicada nos comentários "-- id N").
-- As junções para conferir os dados ficam em 04_consultas.sql.
--
-- Todas as datas são relativas ao dia em que o script roda
-- (CURRENT_DATE - 40 = "40 dias atrás"), então a carga sempre fica atual.
--
-- Premissas (dados que as entradas não informam):
--   * data de nascimento = hoje - idade - 3 meses (a idade bate pelos próximos meses);
--   * preços iniciais valem desde 1 ano atrás;
--   * consultas antigas foram marcadas 7 dias antes da data da consulta;
--   * o reajuste (Entrada 3) entrou ontem, e as consultas da Entrada 4 foram
--     marcadas ontem às 08:00, depois do reajuste; as confirmadas confirmaram
--     ontem às 18:00 (véspera);
--   * pagamentos pagos foram quitados ao fim da consulta;
--   * cada paciente tem um prontuário, ligado à primeira consulta realizada dele
--     (Alice: 40 dias atrás; Bento: 20 dias atrás; Cecília: 12 dias atrás);
--   * CPF, e-mail e telefone não foram informados e ficam NULL;
--   * contatos de emergência são fictícios (criados só para a tabela ter dados).
-- =====================================================================

BEGIN;

-- =====================================================================
-- ENTRADA 1 — Cadastros
-- =====================================================================

INSERT INTO clinica.especialidade (nome) VALUES
    ('Cardiologia'),         -- id 1
    ('Clínica Geral'),       -- id 2
    ('Pediatria'),           -- id 3
    ('Dermatologia'),        -- id 4
    ('Ortopedia'),           -- id 5
    ('Neurologia');          -- id 6 (ainda sem médico)

INSERT INTO clinica.medico (nome, sexo, crm) VALUES
    ('Helena Costa', 'F', 'CRM-1001'),   -- id 1
    ('Rui Matos',    'M', 'CRM-1002'),   -- id 2
    ('Sofia Lins',   'F', 'CRM-1003'),   -- id 3
    ('Téo Alves',    'M', 'CRM-1004');   -- id 4

INSERT INTO clinica.medico_especialidade (id_medico, id_especialidade) VALUES
    (1, 1),   -- Helena: Cardiologia
    (1, 2),   -- Helena: Clínica Geral
    (2, 3),   -- Rui: Pediatria
    (3, 4),   -- Sofia: Dermatologia
    (4, 5);   -- Téo: Ortopedia

-- dia_semana: 0 = domingo, 1 = segunda ... 6 = sábado
INSERT INTO clinica.horario_atendimento (id_medico, dia_semana, hora_inicio, hora_fim) VALUES
    (1, 1, '08:00', '12:00'),   -- Helena, segunda manhã
    (1, 1, '14:00', '18:00'),   -- Helena, segunda tarde
    (2, 2, '08:00', '12:00'),   -- Rui, terça
    (3, 3, '13:00', '17:00'),   -- Sofia, quarta
    (4, 5, '08:00', '12:00');   -- Téo, sexta

-- Sofia Lins: congresso de daqui a 10 dias até o fim do dia daqui a 12 dias
INSERT INTO clinica.bloqueio_agenda (id_medico, inicio, fim, motivo, observacao) VALUES
    (3, (CURRENT_DATE + 10) + TIME '00:00', (CURRENT_DATE + 12) + TIME '23:59:59', 'congresso', 'Congresso');

INSERT INTO clinica.convenio (nome, percentual_cobertura) VALUES
    ('Saúde Mais', 70.00),   -- id 1
    ('VidaPlena',  50.00);   -- id 2

INSERT INTO clinica.paciente (nome, data_nascimento, id_convenio) VALUES
    ('Alice Pires',   (CURRENT_DATE - INTERVAL '34 years 3 months')::DATE, 1),     -- id 1
    ('Bento Rocha',   (CURRENT_DATE - INTERVAL '8 years 3 months')::DATE,  NULL),  -- id 2
    ('Cecília Souza', (CURRENT_DATE - INTERVAL '61 years 3 months')::DATE, 2),     -- id 3
    ('Davi Nunes',    (CURRENT_DATE - INTERVAL '45 years 3 months')::DATE, NULL),  -- id 4
    ('Elisa Moraes',  (CURRENT_DATE - INTERVAL '29 years 3 months')::DATE, 1);     -- id 5

-- Contatos de emergência: dados FICTÍCIOS (as entradas não informam contatos).
-- Um principal por paciente; alguns têm um segundo contato (relação 1:N).
INSERT INTO clinica.contato_emergencia (id_paciente, nome, parentesco, telefone, principal) VALUES
    (1, 'Marcos Pires',   'cônjuge', '(11) 90000-0101', TRUE),
    (1, 'Lúcia Pires',    'mãe',     '(11) 90000-0102', FALSE),
    (2, 'Carla Rocha',    'mãe',     '(11) 90000-0201', TRUE),
    (2, 'Paulo Rocha',    'pai',     '(11) 90000-0202', FALSE),
    (3, 'Roberto Souza',  'filho',   '(11) 90000-0301', TRUE),
    (4, 'Fernanda Nunes', 'irmã',    '(11) 90000-0401', TRUE),
    (5, 'Gustavo Moraes', 'irmão',   '(11) 90000-0501', TRUE);

INSERT INTO clinica.tipo_consulta (nome, duracao_minutos) VALUES
    ('Primeira consulta', 30),   -- id 1
    ('Retorno',           20),   -- id 2
    ('Exame de rotina',   45);   -- id 3

-- Preços iniciais. O da Primeira consulta (id 1) já sai encerrado anteontem
-- por causa do reajuste da Entrada 3.
INSERT INTO clinica.tabela_preco (id_tipo_consulta, valor, vigencia_inicio, vigencia_fim) VALUES
    (1, 200.00, CURRENT_DATE - 365, CURRENT_DATE - 2),   -- id 1
    (2, 120.00, CURRENT_DATE - 365, NULL),               -- id 2
    (3, 300.00, CURRENT_DATE - 365, NULL);               -- id 3

-- =====================================================================
-- ENTRADA 2 — Consultas antigas, pagamentos e prontuários
-- =====================================================================

-- A consulta guarda o convênio do paciente e a "foto" do preço vigente
-- no dia em que foi marcada (valor_tabela e percentual_cobertura).
-- Fim = início + duração do tipo; agendada_em = início - 7 dias.
-- Retornos apontam para a consulta anterior do mesmo paciente com o mesmo médico.
INSERT INTO clinica.consulta (id_paciente, id_medico, id_tipo_consulta, id_convenio, id_consulta_origem,
                              data_hora_inicio, data_hora_fim, status,
                              valor_tabela, percentual_cobertura,
                              agendada_em, cancelada_em) VALUES
    -- id 1: Alice, Helena, primeira consulta
    (1, 1, 1, 1,    NULL, (CURRENT_DATE - 40) + TIME '09:00', (CURRENT_DATE - 40) + TIME '09:30', 'realizada',
     200.00, 70.00, (CURRENT_DATE - 47) + TIME '09:00', NULL),
    -- id 2: Bento, Rui, primeira consulta
    (2, 2, 1, NULL, NULL, (CURRENT_DATE - 20) + TIME '10:00', (CURRENT_DATE - 20) + TIME '10:30', 'realizada',
     200.00,  0.00, (CURRENT_DATE - 27) + TIME '10:00', NULL),
    -- id 3: Alice, Helena, retorno da consulta 1
    (1, 1, 2, 1,    1,    (CURRENT_DATE - 15) + TIME '09:30', (CURRENT_DATE - 15) + TIME '09:50', 'realizada',
     120.00, 70.00, (CURRENT_DATE - 22) + TIME '09:30', NULL),
    -- id 4: Cecília, Sofia, exame de rotina
    (3, 3, 3, 2,    NULL, (CURRENT_DATE - 12) + TIME '08:00', (CURRENT_DATE - 12) + TIME '08:45', 'realizada',
     300.00, 50.00, (CURRENT_DATE - 19) + TIME '08:00', NULL),
    -- id 5: Bento, Rui, retorno da consulta 2
    (2, 2, 2, NULL, 2,    (CURRENT_DATE - 10) + TIME '14:00', (CURRENT_DATE - 10) + TIME '14:20', 'realizada',
     120.00,  0.00, (CURRENT_DATE - 17) + TIME '14:00', NULL),
    -- id 6: Davi, Helena, faltou
    (4, 1, 1, NULL, NULL, (CURRENT_DATE -  9) + TIME '15:00', (CURRENT_DATE -  9) + TIME '15:30', 'faltou',
     200.00,  0.00, (CURRENT_DATE - 16) + TIME '15:00', NULL),
    -- id 7: Davi, Helena, cancelou 8 horas antes
    (4, 1, 1, NULL, NULL, (CURRENT_DATE -  8) + TIME '10:00', (CURRENT_DATE -  8) + TIME '10:30', 'cancelada',
     200.00,  0.00, (CURRENT_DATE - 15) + TIME '10:00', (CURRENT_DATE - 8) + TIME '02:00');

-- Pagamentos (valores informados na Entrada 2). A falta do Davi (consulta 6) não gera pagamento.
-- gerado_em = agendada_em; pago_em = fim da consulta.
INSERT INTO clinica.pagamento (id_consulta, valor_total, valor_convenio, valor_paciente,
                               regra_aplicada, status, gerado_em, pago_em) VALUES
    (1, 200.00, 140.00,  60.00, 'normal',              'pago',     (CURRENT_DATE - 47) + TIME '09:00', (CURRENT_DATE - 40) + TIME '09:30'),
    (2, 200.00,   0.00, 200.00, 'normal',              'pago',     (CURRENT_DATE - 27) + TIME '10:00', (CURRENT_DATE - 20) + TIME '10:30'),
    (3,   0.00,   0.00,   0.00, 'retorno_gratuito',    'isento',   (CURRENT_DATE - 22) + TIME '09:30', NULL),
    (4, 300.00, 150.00, 150.00, 'normal',              'pago',     (CURRENT_DATE - 19) + TIME '08:00', (CURRENT_DATE - 12) + TIME '08:45'),
    (5,   0.00,   0.00,   0.00, 'retorno_gratuito',    'isento',   (CURRENT_DATE - 17) + TIME '14:00', NULL),
    (7, 100.00,   0.00, 100.00, 'cancelamento_tardio', 'pendente', (CURRENT_DATE - 15) + TIME '10:00', NULL);

-- Catálogos usados nos prontuários
INSERT INTO clinica.cid (codigo_cid, descricao) VALUES
    ('R07', 'Dor de garganta e no peito'),
    ('R50', 'Febre de origem desconhecida'),
    ('L30', 'Outras dermatites');

INSERT INTO clinica.medicamento (nome, principio_ativo, apresentacao) VALUES
    ('AAS',         'Ácido acetilsalicílico', 'comprimido 100 mg'),   -- id 1
    ('Atenolol',    'Atenolol',               'comprimido 25 mg'),    -- id 2
    ('Paracetamol', 'Paracetamol',            'gotas');               -- id 3

INSERT INTO clinica.exame (nome) VALUES
    ('Eletrocardiograma'),   -- id 1
    ('Biópsia de pele');     -- id 2

-- Prontuários
INSERT INTO sensivel.atendimento (id_consulta, inicio_atendimento, fim_atendimento, queixa_principal) VALUES
    (1, (CURRENT_DATE - 40) + TIME '09:00', (CURRENT_DATE - 40) + TIME '09:30', 'Dor no peito ao esforço'),   -- id 1: Alice
    (2, (CURRENT_DATE - 20) + TIME '10:00', (CURRENT_DATE - 20) + TIME '10:30', 'Febre há dois dias'),        -- id 2: Bento
    (4, (CURRENT_DATE - 12) + TIME '08:00', (CURRENT_DATE - 12) + TIME '08:45', 'Manchas na pele');           -- id 3: Cecília

INSERT INTO sensivel.diagnostico (id_atendimento, codigo_cid, principal) VALUES
    (1, 'R07', TRUE),
    (2, 'R50', TRUE),
    (3, 'L30', TRUE);

-- Receitas: Alice e Bento (Cecília não tem receita)
INSERT INTO sensivel.prescricao (id_atendimento, emitida_em) VALUES
    (1, (CURRENT_DATE - 40) + TIME '09:00'),   -- id 1: Alice
    (2, (CURRENT_DATE - 20) + TIME '10:00');   -- id 2: Bento

INSERT INTO sensivel.item_prescricao (id_prescricao, id_medicamento, dosagem, posologia) VALUES
    (1, 1, '100 mg', '1 comprimido ao dia'),
    (1, 2, '25 mg',  '1 comprimido pela manhã'),
    (2, 3, NULL,     '10 gotas a cada 6 horas');

-- Exames: Alice e Cecília (Bento não tem exame)
INSERT INTO sensivel.exame_solicitado (id_atendimento, id_exame) VALUES
    (1, 1),   -- Alice: Eletrocardiograma
    (3, 2);   -- Cecília: Biópsia de pele

-- =====================================================================
-- ENTRADA 3 — Reajuste: Primeira consulta de R$ 200,00 para R$ 240,00
-- O preço antigo (id 1) já foi inserido com vigencia_fim = anteontem;
-- aqui entra o novo. As consultas já marcadas não mudam, porque guardam
-- o valor_tabela do dia em que foram marcadas.
-- =====================================================================

INSERT INTO clinica.tabela_preco (id_tipo_consulta, valor, vigencia_inicio) VALUES
    (1, 240.00, CURRENT_DATE - 1);   -- id 4

-- =====================================================================
-- ENTRADA 4 — Consultas de hoje e futuras (marcadas ontem, após o reajuste)
-- =====================================================================

INSERT INTO clinica.consulta (id_paciente, id_medico, id_tipo_consulta, id_convenio, id_consulta_origem,
                              data_hora_inicio, data_hora_fim, status,
                              valor_tabela, percentual_cobertura,
                              agendada_em, confirmada_em) VALUES
    -- id 8: Alice, Helena, retorno da consulta 3
    (1, 1, 2, 1,    3,    (CURRENT_DATE    ) + TIME '09:00', (CURRENT_DATE    ) + TIME '09:20', 'confirmada',
     120.00, 70.00, (CURRENT_DATE - 1) + TIME '08:00', (CURRENT_DATE - 1) + TIME '18:00'),
    -- id 9: Cecília, Helena, primeira consulta
    (3, 1, 1, 2,    NULL, (CURRENT_DATE    ) + TIME '09:30', (CURRENT_DATE    ) + TIME '10:00', 'agendada',
     240.00, 50.00, (CURRENT_DATE - 1) + TIME '08:00', NULL),
    -- id 10: Bento, Rui, exame de rotina
    (2, 2, 3, NULL, NULL, (CURRENT_DATE    ) + TIME '14:00', (CURRENT_DATE    ) + TIME '14:45', 'confirmada',
     300.00,  0.00, (CURRENT_DATE - 1) + TIME '08:00', (CURRENT_DATE - 1) + TIME '18:00'),
    -- id 11: Alice, Sofia, primeira consulta
    (1, 3, 1, 1,    NULL, (CURRENT_DATE + 1) + TIME '08:00', (CURRENT_DATE + 1) + TIME '08:30', 'agendada',
     240.00, 70.00, (CURRENT_DATE - 1) + TIME '08:00', NULL),
    -- id 12: Elisa, Helena, primeira consulta (apagada na Entrada 5)
    (5, 1, 1, 1,    NULL, (CURRENT_DATE + 2) + TIME '10:00', (CURRENT_DATE + 2) + TIME '10:30', 'agendada',
     240.00, 70.00, (CURRENT_DATE - 1) + TIME '08:00', NULL);

-- Pagamentos pendentes (valores informados na Entrada 4)
INSERT INTO clinica.pagamento (id_consulta, valor_total, valor_convenio, valor_paciente,
                               regra_aplicada, status, gerado_em) VALUES
    ( 8,   0.00,   0.00,   0.00, 'retorno_gratuito', 'isento',   (CURRENT_DATE - 1) + TIME '08:00'),
    ( 9, 240.00, 120.00, 120.00, 'normal',           'pendente', (CURRENT_DATE - 1) + TIME '08:00'),
    (10, 300.00,   0.00, 300.00, 'normal',           'pendente', (CURRENT_DATE - 1) + TIME '08:00'),
    (11, 240.00, 168.00,  72.00, 'normal',           'pendente', (CURRENT_DATE - 1) + TIME '08:00'),
    (12, 240.00, 168.00,  72.00, 'normal',           'pendente', (CURRENT_DATE - 1) + TIME '08:00');

COMMIT;

-- =====================================================================
-- ENTRADA 5 — Correção: a consulta da Elisa (id 12, daqui a 2 dias) foi
-- marcada por engano. Apaga a consulta e o que pertence a ela numa
-- transação: ou apaga tudo, ou nada. (Ela não tem prontuário nem aviso.)
-- =====================================================================

BEGIN;

DELETE FROM clinica.pagamento WHERE id_consulta = 12;
DELETE FROM clinica.aviso     WHERE id_consulta = 12;
DELETE FROM clinica.consulta  WHERE id_consulta = 12;

COMMIT;
