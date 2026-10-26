-- =====================================================================
-- Clínica Médica — 01_ddl.sql
-- Estrutura do banco (PostgreSQL).
--   schema clinica  : cadastros, agenda, valores, pagamentos e avisos
--   schema sensivel : prontuário (atendimento, diagnóstico, prescrição,
--                     exames) e auditoria
-- Recria tudo do zero: pode ser executado várias vezes.
-- =====================================================================

DROP SCHEMA IF EXISTS sensivel CASCADE;
DROP SCHEMA IF EXISTS clinica CASCADE;

CREATE SCHEMA clinica;
CREATE SCHEMA sensivel;

-- ---------------------------------------------------------------------
-- Especialidades e médicos
-- ---------------------------------------------------------------------
CREATE TABLE clinica.especialidade (
    id_especialidade  SERIAL       PRIMARY KEY,
    nome              VARCHAR(80)  NOT NULL UNIQUE,
    descricao         TEXT
);

CREATE TABLE clinica.medico (
    id_medico  SERIAL        PRIMARY KEY,
    nome       VARCHAR(120)  NOT NULL,
    sexo       CHAR(1)       NOT NULL CHECK (sexo IN ('M', 'F')),
    crm        VARCHAR(10)   NOT NULL UNIQUE,
    uf_crm     CHAR(2),
    email      VARCHAR(120),
    telefone   VARCHAR(20),
    ativo      BOOLEAN       NOT NULL DEFAULT TRUE
);

-- N:N médico x especialidade
CREATE TABLE clinica.medico_especialidade (
    id_medico         INT          NOT NULL REFERENCES clinica.medico (id_medico),
    id_especialidade  INT          NOT NULL REFERENCES clinica.especialidade (id_especialidade),
    rqe               VARCHAR(10),
    PRIMARY KEY (id_medico, id_especialidade)
);

-- ---------------------------------------------------------------------
-- Agenda do médico
-- ---------------------------------------------------------------------
CREATE TABLE clinica.horario_atendimento (
    id_horario   SERIAL    PRIMARY KEY,
    id_medico    INT       NOT NULL REFERENCES clinica.medico (id_medico),
    dia_semana   SMALLINT  NOT NULL CHECK (dia_semana BETWEEN 0 AND 6),  -- 0 = domingo ... 6 = sábado
    hora_inicio  TIME      NOT NULL,
    hora_fim     TIME      NOT NULL,
    CHECK (hora_fim > hora_inicio),
    UNIQUE (id_medico, dia_semana, hora_inicio)
);

CREATE TABLE clinica.bloqueio_agenda (
    id_bloqueio  SERIAL       PRIMARY KEY,
    id_medico    INT          NOT NULL REFERENCES clinica.medico (id_medico),
    inicio       TIMESTAMP    NOT NULL,
    fim          TIMESTAMP    NOT NULL,
    motivo       VARCHAR(20)  NOT NULL CHECK (motivo IN ('ferias', 'congresso', 'outro')),
    observacao   TEXT,
    CHECK (fim > inicio)
);

-- ---------------------------------------------------------------------
-- Convênios e pacientes
-- ---------------------------------------------------------------------
CREATE TABLE clinica.convenio (
    id_convenio           SERIAL        PRIMARY KEY,
    nome                  VARCHAR(80)   NOT NULL UNIQUE,
    percentual_cobertura  NUMERIC(5,2)  NOT NULL CHECK (percentual_cobertura BETWEEN 0 AND 100),
    telefone              VARCHAR(20),
    ativo                 BOOLEAN       NOT NULL DEFAULT TRUE
);

CREATE TABLE clinica.paciente (
    id_paciente         SERIAL        PRIMARY KEY,
    nome                VARCHAR(120)  NOT NULL,
    cpf                 CHAR(11)      UNIQUE CHECK (cpf ~ '^[0-9]{11}$'),
    data_nascimento     DATE          NOT NULL CHECK (data_nascimento <= CURRENT_DATE),
    telefone            VARCHAR(20),
    email               VARCHAR(120),
    id_convenio         INT           REFERENCES clinica.convenio (id_convenio),  -- NULL = particular
    numero_carteirinha  VARCHAR(30),
    data_regularizacao  TIMESTAMP,
    data_cadastro       TIMESTAMP     NOT NULL DEFAULT now()
);

-- 1:N paciente -> contatos de emergência
CREATE TABLE clinica.contato_emergencia (
    id_contato   SERIAL        PRIMARY KEY,
    id_paciente  INT           NOT NULL REFERENCES clinica.paciente (id_paciente),
    nome         VARCHAR(120)  NOT NULL,
    parentesco   VARCHAR(30),
    telefone     VARCHAR(20)   NOT NULL,
    principal    BOOLEAN       NOT NULL DEFAULT FALSE,
    UNIQUE (id_paciente, telefone)
);

-- no máximo um contato principal por paciente
CREATE UNIQUE INDEX ux_contato_emergencia_principal
    ON clinica.contato_emergencia (id_paciente) WHERE principal;

-- ---------------------------------------------------------------------
-- Tipos de consulta e histórico de preços
-- ---------------------------------------------------------------------
CREATE TABLE clinica.tipo_consulta (
    id_tipo_consulta  SERIAL       PRIMARY KEY,
    nome              VARCHAR(30)  NOT NULL UNIQUE,
    duracao_minutos   INT          NOT NULL CHECK (duracao_minutos > 0)
);

CREATE TABLE clinica.tabela_preco (
    id_preco          SERIAL         PRIMARY KEY,
    id_tipo_consulta  INT            NOT NULL REFERENCES clinica.tipo_consulta (id_tipo_consulta),
    valor             NUMERIC(10,2)  NOT NULL CHECK (valor >= 0),
    vigencia_inicio   DATE           NOT NULL,
    vigencia_fim      DATE,                                   -- NULL = preço atual
    CHECK (vigencia_fim IS NULL OR vigencia_fim >= vigencia_inicio),
    UNIQUE (id_tipo_consulta, vigencia_inicio)
);

-- no máximo um preço vigente (sem vigencia_fim) por tipo de consulta
CREATE UNIQUE INDEX ux_tabela_preco_vigente
    ON clinica.tabela_preco (id_tipo_consulta) WHERE vigencia_fim IS NULL;

-- ---------------------------------------------------------------------
-- Consulta (o horário marcado)
-- ---------------------------------------------------------------------
CREATE SEQUENCE clinica.seq_protocolo;

CREATE TABLE clinica.consulta (
    id_consulta           SERIAL         PRIMARY KEY,
    protocolo             VARCHAR(14)    NOT NULL UNIQUE
                          DEFAULT 'CL-' || to_char(now(), 'YYYY') || '-'
                                  || LPAD(nextval('clinica.seq_protocolo')::TEXT, 6, '0'),
    id_paciente           INT            NOT NULL REFERENCES clinica.paciente (id_paciente),
    id_medico             INT            NOT NULL REFERENCES clinica.medico (id_medico),
    id_tipo_consulta      INT            NOT NULL REFERENCES clinica.tipo_consulta (id_tipo_consulta),
    id_convenio           INT            REFERENCES clinica.convenio (id_convenio),   -- convênio usado NESTA consulta
    id_consulta_origem    INT            REFERENCES clinica.consulta (id_consulta),   -- retorno: consulta anterior
    data_hora_inicio      TIMESTAMP      NOT NULL,
    data_hora_fim         TIMESTAMP      NOT NULL,
    status                VARCHAR(12)    NOT NULL DEFAULT 'agendada'
                          CHECK (status IN ('agendada', 'confirmada', 'realizada', 'cancelada', 'faltou')),
    valor_tabela          NUMERIC(10,2)  NOT NULL CHECK (valor_tabela >= 0),           -- foto do preço na marcação
    percentual_cobertura  NUMERIC(5,2)   NOT NULL DEFAULT 0
                          CHECK (percentual_cobertura BETWEEN 0 AND 100),             -- foto da cobertura na marcação
    agendada_em           TIMESTAMP      NOT NULL DEFAULT now(),
    confirmada_em         TIMESTAMP,
    cancelada_em          TIMESTAMP,
    CHECK (data_hora_fim > data_hora_inicio),
    CHECK (id_consulta_origem IS NULL OR id_consulta_origem <> id_consulta),
    CHECK (id_convenio IS NOT NULL OR percentual_cobertura = 0),
    CHECK ((status = 'cancelada') = (cancelada_em IS NOT NULL)),
    CHECK (status <> 'confirmada' OR confirmada_em IS NOT NULL),
    CHECK (confirmada_em IS NULL OR confirmada_em >= agendada_em),
    CHECK (cancelada_em  IS NULL OR cancelada_em  >= agendada_em)
);

-- ---------------------------------------------------------------------
-- Pagamento (1:1 com a consulta)
-- ---------------------------------------------------------------------
CREATE TABLE clinica.pagamento (
    id_pagamento    SERIAL         PRIMARY KEY,
    id_consulta     INT            NOT NULL UNIQUE REFERENCES clinica.consulta (id_consulta),
    valor_total     NUMERIC(10,2)  NOT NULL CHECK (valor_total >= 0),
    valor_convenio  NUMERIC(10,2)  NOT NULL DEFAULT 0 CHECK (valor_convenio >= 0),
    valor_paciente  NUMERIC(10,2)  NOT NULL DEFAULT 0 CHECK (valor_paciente >= 0),
    regra_aplicada  VARCHAR(30)    NOT NULL DEFAULT 'normal'
                    CHECK (regra_aplicada IN ('normal', 'retorno_gratuito',
                                              'cancelamento_sem_custo', 'cancelamento_tardio')),
    status          VARCHAR(10)    NOT NULL DEFAULT 'pendente'
                    CHECK (status IN ('pendente', 'pago', 'isento', 'cancelado')),
    gerado_em       TIMESTAMP      NOT NULL DEFAULT now(),
    pago_em         TIMESTAMP,
    CHECK (valor_convenio + valor_paciente = valor_total),
    CHECK ((status = 'pago') = (pago_em IS NOT NULL)),
    CHECK (status <> 'isento' OR valor_total = 0),
    CHECK (regra_aplicada <> 'retorno_gratuito' OR status = 'isento')   -- retorno gratuito é sempre isento
);

-- ---------------------------------------------------------------------
-- Avisos (lembretes por e-mail / WhatsApp; o envio é feito por outro sistema)
-- ---------------------------------------------------------------------
CREATE TABLE clinica.aviso (
    id_aviso         SERIAL        PRIMARY KEY,
    id_consulta      INT           NOT NULL REFERENCES clinica.consulta (id_consulta),
    canal            VARCHAR(10)   NOT NULL CHECK (canal IN ('email', 'whatsapp')),
    destino          VARCHAR(120)  NOT NULL,
    programado_para  TIMESTAMP     NOT NULL,
    enviado_em       TIMESTAMP,
    status_envio     VARCHAR(10)   NOT NULL DEFAULT 'pendente'
                     CHECK (status_envio IN ('pendente', 'enviado', 'falhou')),
    resposta         VARCHAR(15)   NOT NULL DEFAULT 'sem_resposta'
                     CHECK (resposta IN ('confirmou', 'cancelou', 'sem_resposta')),
    respondido_em    TIMESTAMP,
    UNIQUE (id_consulta, canal),
    CHECK (status_envio <> 'enviado' OR enviado_em IS NOT NULL)
);

-- ---------------------------------------------------------------------
-- Catálogos usados pelo prontuário (não são sigilosos)
-- ---------------------------------------------------------------------
CREATE TABLE clinica.cid (
    codigo_cid  VARCHAR(8)    PRIMARY KEY,
    descricao   VARCHAR(255)  NOT NULL
);

CREATE TABLE clinica.medicamento (
    id_medicamento   SERIAL        PRIMARY KEY,
    nome             VARCHAR(120)  NOT NULL,
    principio_ativo  VARCHAR(120),
    apresentacao     VARCHAR(60),
    UNIQUE (nome, apresentacao)
);

CREATE TABLE clinica.exame (
    id_exame  SERIAL        PRIMARY KEY,
    nome      VARCHAR(120)  NOT NULL UNIQUE,
    codigo    VARCHAR(20),
    preparo   TEXT
);

-- ---------------------------------------------------------------------
-- Prontuário (schema sensivel)
-- ---------------------------------------------------------------------
CREATE TABLE sensivel.atendimento (
    id_atendimento      SERIAL     PRIMARY KEY,
    id_consulta         INT        NOT NULL UNIQUE REFERENCES clinica.consulta (id_consulta),
    inicio_atendimento  TIMESTAMP  NOT NULL,
    fim_atendimento     TIMESTAMP,
    queixa_principal    TEXT       NOT NULL,
    anamnese            TEXT,
    dados_clinicos      JSONB      NOT NULL DEFAULT '{}'::JSONB,
    observacoes         TEXT,
    CHECK (fim_atendimento IS NULL OR fim_atendimento > inicio_atendimento)
);

-- N:N atendimento x CID
CREATE TABLE sensivel.diagnostico (
    id_atendimento  INT         NOT NULL REFERENCES sensivel.atendimento (id_atendimento),
    codigo_cid      VARCHAR(8)  NOT NULL REFERENCES clinica.cid (codigo_cid),
    principal       BOOLEAN     NOT NULL DEFAULT FALSE,
    observacao      TEXT,
    PRIMARY KEY (id_atendimento, codigo_cid)
);

-- no máximo um diagnóstico principal por atendimento
CREATE UNIQUE INDEX ux_diagnostico_principal
    ON sensivel.diagnostico (id_atendimento) WHERE principal;

CREATE TABLE sensivel.prescricao (
    id_prescricao   SERIAL     PRIMARY KEY,
    id_atendimento  INT        NOT NULL REFERENCES sensivel.atendimento (id_atendimento),
    emitida_em      TIMESTAMP  NOT NULL DEFAULT now(),
    validade_dias   INT        CHECK (validade_dias > 0),
    observacao      TEXT
);

-- N:N prescrição x medicamento
CREATE TABLE sensivel.item_prescricao (
    id_item         SERIAL        PRIMARY KEY,
    id_prescricao   INT           NOT NULL REFERENCES sensivel.prescricao (id_prescricao),
    id_medicamento  INT           NOT NULL REFERENCES clinica.medicamento (id_medicamento),
    dosagem         VARCHAR(40),
    posologia       VARCHAR(120)  NOT NULL,
    quantidade      INT           CHECK (quantidade > 0),
    duracao_dias    INT           CHECK (duracao_dias > 0),
    UNIQUE (id_prescricao, id_medicamento)
);

-- N:N atendimento x exame
CREATE TABLE sensivel.exame_solicitado (
    id_exame_solicitado  SERIAL   PRIMARY KEY,
    id_atendimento       INT      NOT NULL REFERENCES sensivel.atendimento (id_atendimento),
    id_exame             INT      NOT NULL REFERENCES clinica.exame (id_exame),
    urgente              BOOLEAN  NOT NULL DEFAULT FALSE,
    justificativa        TEXT,
    UNIQUE (id_atendimento, id_exame)
);

-- Auditoria do prontuário (preenchida por trigger na entrega 3).
-- Sem FK de propósito: o histórico continua existindo mesmo se a linha original for apagada.
CREATE TABLE sensivel.auditoria_prontuario (
    id_auditoria  BIGSERIAL    PRIMARY KEY,
    tabela        VARCHAR(40)  NOT NULL,
    id_registro   INT          NOT NULL,
    operacao      VARCHAR(10)  NOT NULL CHECK (operacao IN ('INSERT', 'UPDATE', 'DELETE')),
    usuario       VARCHAR(60)  NOT NULL DEFAULT current_user,
    data_hora     TIMESTAMP    NOT NULL DEFAULT now(),
    dados_antes   JSONB,
    dados_depois  JSONB
);
