-- Dados ficticios para simulacao de importacao no Kommo CRM
-- Periodo dos leads: 2025-01-01 a 2025-12-31
-- Total de leads gerados: 6000
-- Observacao: todos os dados pessoais, empresas, telefones e emails sao ficticios.

BEGIN;

DROP VIEW IF EXISTS vw_kommo_import_leads;
DROP TABLE IF EXISTS lead_contatos;
DROP TABLE IF EXISTS leads;
DROP TABLE IF EXISTS contatos;
DROP TABLE IF EXISTS empresas;
DROP TABLE IF EXISTS etapas_funil;
DROP TABLE IF EXISTS funis;
DROP TABLE IF EXISTS usuarios_responsaveis;

CREATE TABLE usuarios_responsaveis (
    id                  integer PRIMARY KEY,
    nome                text NOT NULL,
    papel               text NOT NULL CHECK (papel IN ('SDR', 'Closer'))
);

CREATE TABLE funis (
    id                  integer PRIMARY KEY,
    nome                text NOT NULL UNIQUE
);

CREATE TABLE etapas_funil (
    id                  integer PRIMARY KEY,
    funil_id            integer NOT NULL REFERENCES funis(id),
    nome                text NOT NULL,
    descricao           text NOT NULL,
    ordem               integer NOT NULL,
    UNIQUE (funil_id, nome)
);

CREATE TABLE empresas (
    id                  integer PRIMARY KEY,
    id_externo          text DEFAULT '',
    nome                text NOT NULL,
    telefone            text NOT NULL,
    email               text NOT NULL,
    ltv                 numeric(12,2) NOT NULL DEFAULT 0,
    data_ultimo_contrato date,
    criado_em           timestamp NOT NULL,
    atualizado_em       timestamp NOT NULL
);

CREATE TABLE contatos (
    id                  integer PRIMARY KEY,
    id_externo          text DEFAULT '',
    empresa_id          integer NOT NULL REFERENCES empresas(id),
    nome                text NOT NULL,
    telefone            text NOT NULL,
    email               text NOT NULL,
    cargo               text NOT NULL,
    criado_em           timestamp NOT NULL,
    atualizado_em       timestamp NOT NULL
);

CREATE TABLE leads (
    id                  integer PRIMARY KEY,
    id_externo          text DEFAULT '',
    empresa_id          integer NOT NULL REFERENCES empresas(id),
    etapa_funil_id      integer NOT NULL REFERENCES etapas_funil(id),
    usuario_responsavel_id integer NOT NULL REFERENCES usuarios_responsaveis(id),
    nome                text NOT NULL,
    venda               numeric(12,2),
    utm_source          text NOT NULL,
    utm_campaign        text NOT NULL,
    utm_medium          text NOT NULL,
    utm_content         text NOT NULL,
    servicos            text NOT NULL,
    data_contrato       date,
    criado_em           timestamp NOT NULL,
    atualizado_em       timestamp NOT NULL,
    CHECK (atualizado_em >= criado_em)
);

CREATE TABLE lead_contatos (
    lead_id             integer NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    contato_id          integer NOT NULL REFERENCES contatos(id) ON DELETE CASCADE,
    papel_no_lead       text NOT NULL DEFAULT 'Contato relacionado',
    PRIMARY KEY (lead_id, contato_id)
);

INSERT INTO usuarios_responsaveis (id, nome, papel) VALUES
    (1, 'Ana Ribeiro', 'SDR'),
    (2, 'Bruno Martins', 'SDR'),
    (3, 'Carla Nogueira', 'SDR'),
    (4, 'Diego Almeida', 'SDR'),
    (5, 'Eduarda Lima', 'Closer'),
    (6, 'Felipe Rocha', 'Closer'),
    (7, 'Gabriela Torres', 'Closer'),
    (8, 'Henrique Costa', 'Closer'),
    (9, 'Isabela Freitas', 'Closer'),
    (10, 'Joao Pereira', 'Closer');

INSERT INTO funis (id, nome) VALUES
    (1, 'Funil de Qualificacao'),
    (2, 'Funil de Vendas');

INSERT INTO etapas_funil (id, funil_id, nome, descricao, ordem) VALUES
    (1, 1, 'Novo Lead', 'Leads que foram recentemente adicionados ao sistema e ainda nao passaram por nenhuma qualificacao.', 1),
    (2, 1, 'Contato Inicial', 'Leads que foram contatados pela primeira vez por telefone, email ou outro canal.', 2),
    (3, 1, 'Qualificacao em Andamento', 'Leads em processo de qualificacao para avaliar potencial como cliente.', 3),
    (4, 1, 'Qualificado', 'Leads considerados qualificados e com potencial para se tornarem clientes.', 4),
    (5, 1, 'Desqualificado', 'Leads considerados desqualificados ou sem potencial no momento.', 5),
    (6, 2, 'Novo Lead Qualificado', 'Leads qualificados e prontos para abordagem comercial.', 1),
    (7, 2, 'Contato de Vendas', 'Leads contatados pela equipe de vendas para discutir necessidades e solucoes.', 2),
    (8, 2, 'Proposta Enviada', 'Clientes potenciais que receberam uma proposta comercial.', 3),
    (9, 2, 'Negociacao', 'Clientes potenciais em negociacao de termos e condicoes.', 4),
    (10, 2, 'Fechado - Ganhou', 'Clientes potenciais que aceitaram a proposta.', 5),
    (11, 2, 'Fechado - Perdido', 'Clientes potenciais que rejeitaram a proposta ou nao seguiram adiante.', 6);

-- 900 empresas ficticias. Uma empresa pode estar em varios leads e varios contatos.
INSERT INTO empresas (id, nome, telefone, email, ltv, data_ultimo_contrato, criado_em, atualizado_em)
SELECT
    gs AS id,
    format('%s %s %s', prefixo.nome, segmento.nome, lpad(gs::text, 4, '0')) AS nome,
    format('+55 11 9%04s-%04s', ((gs * 37) % 10000)::text, ((gs * 91) % 10000)::text) AS telefone,
    lower(format('empresa%s@exemplo.test', gs)) AS email,
    0::numeric(12,2) AS ltv,
    NULL::date AS data_ultimo_contrato,
    timestamp '2024-10-01' + ((gs % 92) * interval '1 day') AS criado_em,
    timestamp '2025-01-01' + ((gs % 365) * interval '1 day') AS atualizado_em
FROM generate_series(1, 900) AS gs
CROSS JOIN LATERAL (
    SELECT (ARRAY['Grupo','Instituto','Comercial','Tecnologia','Solucoes','Holding','Consultoria','Distribuidora','Industria','Servicos'])[1 + (gs % 10)]
) AS prefixo(nome)
CROSS JOIN LATERAL (
    SELECT (ARRAY['Alvorada','Norte','Horizonte','Central','Prime','Vector','Atlas','Delta','Solar','Nexus','Aurora','Sigma'])[1 + (gs % 12)]
) AS segmento(nome);

-- 2200 contatos ficticios. Cada contato pertence a apenas uma empresa.
INSERT INTO contatos (id, empresa_id, nome, telefone, email, cargo, criado_em, atualizado_em)
SELECT
    gs AS id,
    1 + ((gs * 17) % 900) AS empresa_id,
    format('%s %s', primeiro.nome, sobrenome.nome) AS nome,
    format('+55 11 9%04s-%04s', ((gs * 53) % 10000)::text, ((gs * 29) % 10000)::text) AS telefone,
    lower(format('%s.%s.%s@contato.exemplo.test', primeiro.slug, sobrenome.slug, gs)) AS email,
    cargo.nome AS cargo,
    timestamp '2024-11-01' + ((gs % 61) * interval '1 day') AS criado_em,
    timestamp '2025-01-01' + ((gs % 365) * interval '1 day') AS atualizado_em
FROM generate_series(1, 2200) AS gs
CROSS JOIN LATERAL (
    SELECT * FROM (VALUES
        ('Amanda','amanda'), ('Bernardo','bernardo'), ('Camila','camila'), ('Daniel','daniel'),
        ('Elisa','elisa'), ('Fernando','fernando'), ('Giovana','giovana'), ('Igor','igor'),
        ('Larissa','larissa'), ('Marcos','marcos'), ('Natalia','natalia'), ('Otavio','otavio'),
        ('Patricia','patricia'), ('Rafael','rafael'), ('Sofia','sofia'), ('Thiago','thiago')
    ) AS nomes(nome, slug)
    OFFSET (gs % 16) LIMIT 1
) AS primeiro
CROSS JOIN LATERAL (
    SELECT * FROM (VALUES
        ('Silva','silva'), ('Oliveira','oliveira'), ('Santos','santos'), ('Souza','souza'),
        ('Costa','costa'), ('Almeida','almeida'), ('Ferreira','ferreira'), ('Rodrigues','rodrigues'),
        ('Gomes','gomes'), ('Martins','martins'), ('Barbosa','barbosa'), ('Ribeiro','ribeiro')
    ) AS nomes(nome, slug)
    OFFSET ((gs * 3) % 12) LIMIT 1
) AS sobrenome
CROSS JOIN LATERAL (
    SELECT (ARRAY['CEO','Diretor Comercial','Gerente de Marketing','Coordenador de Vendas','Analista de Operacoes','Gerente Financeiro','Head de Growth','Supervisor de Atendimento'])[1 + (gs % 8)]
) AS cargo(nome);

-- Distribuicao mensal propositalmente desigual para simular sazonalidade em 2025.
-- Total: 6000 leads.
WITH distribuicao_mensal(mes, quantidade) AS (
    VALUES
        (1, 320),
        (2, 280),
        (3, 410),
        (4, 520),
        (5, 650),
        (6, 740),
        (7, 430),
        (8, 360),
        (9, 580),
        (10, 720),
        (11, 610),
        (12, 380)
), base AS (
    SELECT
        row_number() OVER (ORDER BY mes, seq) AS id,
        mes,
        seq,
        quantidade,
        make_date(2025, mes, 1) + (((seq - 1) * 28 / quantidade)::int) AS data_base
    FROM distribuicao_mensal
    CROSS JOIN LATERAL generate_series(1, quantidade) AS seq
), enriquecido AS (
    SELECT
        id,
        mes,
        seq,
        data_base,
        1 + ((id * 19) % 900) AS empresa_id,
        CASE
            WHEN (id % 100) < 18 THEN 1
            WHEN (id % 100) < 34 THEN 2
            WHEN (id % 100) < 50 THEN 3
            WHEN (id % 100) < 62 THEN 4
            WHEN (id % 100) < 70 THEN 5
            WHEN (id % 100) < 79 THEN 6
            WHEN (id % 100) < 86 THEN 7
            WHEN (id % 100) < 92 THEN 8
            WHEN (id % 100) < 96 THEN 9
            WHEN (id % 100) < 98 THEN 10
            ELSE 11
        END AS etapa_funil_id
    FROM base
)
INSERT INTO leads (
    id,
    empresa_id,
    etapa_funil_id,
    usuario_responsavel_id,
    nome,
    venda,
    utm_source,
    utm_campaign,
    utm_medium,
    utm_content,
    servicos,
    data_contrato,
    criado_em,
    atualizado_em
)
SELECT
    e.id,
    e.empresa_id,
    e.etapa_funil_id,
    CASE WHEN e.etapa_funil_id <= 5 THEN 1 + ((e.id * 7) % 4) ELSE 5 + ((e.id * 11) % 6) END AS usuario_responsavel_id,
    format('Lead %s - %s', lpad(e.id::text, 5, '0'), emp.nome) AS nome,
    CASE
        WHEN e.etapa_funil_id = 10 THEN (1500 + ((e.id * 137) % 48500))::numeric(12,2)
        ELSE NULL
    END AS venda,
    (ARRAY['google','meta','linkedin','organico','indicacao','email','youtube','evento'])[1 + (e.id % 8)] AS utm_source,
    format('campanha_%s_2025', lower(to_char(e.data_base, 'TMMonth'))) AS utm_campaign,
    (ARRAY['cpc','social','email','referral','organic','display'])[1 + ((e.id * 2) % 6)] AS utm_medium,
    (ARRAY['criativo_a','criativo_b','ebook','webinar','landing_page','remarketing','comparativo'])[1 + ((e.id * 5) % 7)] AS utm_content,
    (ARRAY['Automacao de CRM','Analise de Dados com IA','Integracao Kommo e n8n','Dashboard Comercial','Consultoria de Processos','Implantacao de Funil','Treinamento Comercial'])[1 + ((e.id * 3) % 7)] AS servicos,
    CASE WHEN e.etapa_funil_id = 10 THEN (e.data_base + ((e.id % 9) * interval '1 day'))::date ELSE NULL END AS data_contrato,
    e.data_base + (((e.id * 37) % 86400) * interval '1 second') AS criado_em,
    e.data_base + (((e.id * 37) % 86400) * interval '1 second') + ((1 + (e.id % 21)) * interval '1 day') AS atualizado_em
FROM enriquecido e
JOIN empresas emp ON emp.id = e.empresa_id;

-- Relacao muitos-para-muitos entre leads e contatos.
-- Todo lead recebe ao menos 1 contato. Parte dos leads recebe 2 ou 3 contatos.
INSERT INTO lead_contatos (lead_id, contato_id, papel_no_lead)
SELECT
    l.id AS lead_id,
    c.id AS contato_id,
    'Contato principal' AS papel_no_lead
FROM leads l
JOIN LATERAL (
    SELECT id
    FROM contatos c
    WHERE c.empresa_id = l.empresa_id
    ORDER BY ((c.id * 31 + l.id * 17) % 997)
    LIMIT 1
) c ON true;

INSERT INTO lead_contatos (lead_id, contato_id, papel_no_lead)
SELECT
    l.id AS lead_id,
    c.id AS contato_id,
    'Influenciador' AS papel_no_lead
FROM leads l
JOIN LATERAL (
    SELECT id
    FROM contatos c
    WHERE c.empresa_id = l.empresa_id
    ORDER BY ((c.id * 43 + l.id * 13) % 991)
    OFFSET 1 LIMIT 1
) c ON true
WHERE l.id % 3 = 0
ON CONFLICT DO NOTHING;

INSERT INTO lead_contatos (lead_id, contato_id, papel_no_lead)
SELECT
    l.id AS lead_id,
    c.id AS contato_id,
    'Decisor' AS papel_no_lead
FROM leads l
JOIN LATERAL (
    SELECT id
    FROM contatos c
    WHERE c.empresa_id = l.empresa_id
    ORDER BY ((c.id * 59 + l.id * 7) % 983)
    OFFSET 2 LIMIT 1
) c ON true
WHERE l.id % 10 = 0
ON CONFLICT DO NOTHING;

-- Atualiza LTV e data do ultimo contrato das empresas com base nos leads ganhos.
UPDATE empresas e
SET
    ltv = COALESCE(v.total_vendas, 0),
    data_ultimo_contrato = v.ultimo_contrato,
    atualizado_em = GREATEST(e.atualizado_em, COALESCE(v.ultimo_contrato::timestamp, e.atualizado_em))
FROM (
    SELECT
        empresa_id,
        SUM(venda) AS total_vendas,
        MAX(data_contrato) AS ultimo_contrato
    FROM leads
    WHERE etapa_funil_id = 10
    GROUP BY empresa_id
) v
WHERE v.empresa_id = e.id;

-- View achatada para exportacao como planilha de importacao no Kommo CRM.
-- Uma linha por lead, com os contatos vinculados agregados em campos separados por ponto e virgula.
CREATE VIEW vw_kommo_import_leads AS
SELECT
    l.id AS lead_id_local,
    l.id_externo AS lead_id_externo,
    l.nome AS lead_nome,
    l.venda,
    u.nome AS usuario_responsavel,
    u.papel AS tipo_usuario_responsavel,
    f.nome AS funil,
    ef.nome AS etapa_funil,
    l.utm_source,
    l.utm_campaign AS utm_campaing,
    l.utm_medium,
    l.utm_content,
    l.servicos,
    l.data_contrato,
    l.criado_em AS lead_criado_em,
    l.atualizado_em AS lead_atualizado_em,
    e.id AS empresa_id_local,
    e.id_externo AS empresa_id_externo,
    e.nome AS empresa_nome,
    e.telefone AS empresa_telefone,
    e.email AS empresa_email,
    e.ltv AS empresa_ltv,
    e.data_ultimo_contrato AS empresa_data_ultimo_contrato,
    string_agg(c.id::text, '; ' ORDER BY c.id) AS contato_ids_locais,
    string_agg(c.id_externo, '; ' ORDER BY c.id) AS contato_ids_externos,
    string_agg(c.nome, '; ' ORDER BY c.id) AS contatos_nomes,
    string_agg(c.telefone, '; ' ORDER BY c.id) AS contatos_telefones,
    string_agg(c.email, '; ' ORDER BY c.id) AS contatos_emails,
    string_agg(c.cargo, '; ' ORDER BY c.id) AS contatos_cargos
FROM leads l
JOIN usuarios_responsaveis u ON u.id = l.usuario_responsavel_id
JOIN etapas_funil ef ON ef.id = l.etapa_funil_id
JOIN funis f ON f.id = ef.funil_id
JOIN empresas e ON e.id = l.empresa_id
JOIN lead_contatos lc ON lc.lead_id = l.id
JOIN contatos c ON c.id = lc.contato_id
GROUP BY
    l.id,
    u.id,
    f.id,
    ef.id,
    e.id;

-- Consultas de validacao rapida.
-- SELECT count(*) FROM leads; -- 6000
-- SELECT date_trunc('month', criado_em)::date AS mes, count(*) FROM leads GROUP BY 1 ORDER BY 1;
-- SELECT funil, etapa_funil, count(*) FROM vw_kommo_import_leads GROUP BY 1,2 ORDER BY 1,2;

COMMIT;
