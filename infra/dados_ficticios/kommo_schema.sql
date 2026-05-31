-- Schema das entidades usadas para sincronizacao e analise de dados do Kommo CRM.
-- Este arquivo cria apenas tabelas, indices, triggers e views. Nao insere dados.

BEGIN;

DROP VIEW IF EXISTS vw_leads_com_dados_unificados;
DROP TABLE IF EXISTS insights;
DROP TABLE IF EXISTS leads;
DROP TABLE IF EXISTS contatos;
DROP TABLE IF EXISTS empresas;
DROP TABLE IF EXISTS etapas;
DROP TABLE IF EXISTS funis;
DROP TABLE IF EXISTS usuarios;
DROP FUNCTION IF EXISTS preencher_timestamps_padrao();

CREATE FUNCTION preencher_timestamps_padrao()
RETURNS trigger AS $$
BEGIN
    IF NEW.criado_em IS NULL THEN
        NEW.criado_em := now();
    END IF;

    IF NEW.atualizado_em IS NULL THEN
        NEW.atualizado_em := now();
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE usuarios (
    id bigserial PRIMARY KEY,
    id_externo text,
    nome text NOT NULL,
    papel text NOT NULL CHECK (papel IN ('SDR', 'Closer')),
    criado_em timestamptz,
    atualizado_em timestamptz
);

CREATE TABLE funis (
    id bigserial PRIMARY KEY,
    id_externo text,
    nome text NOT NULL,
    criado_em timestamptz,
    atualizado_em timestamptz
);

CREATE TABLE etapas (
    id bigserial PRIMARY KEY,
    id_externo text,
    funil_id bigint REFERENCES funis(id),
    funil_id_externo text,
    nome text NOT NULL,
    descricao text,
    ordem integer,
    criado_em timestamptz,
    atualizado_em timestamptz
);

CREATE TABLE empresas (
    id bigserial PRIMARY KEY,
    id_externo text,
    nome text NOT NULL,
    telefone text,
    email text,
    ltv numeric(12,2) DEFAULT 0,
    data_ultimo_contrato date,
    criado_em timestamptz,
    atualizado_em timestamptz
);

CREATE TABLE contatos (
    id bigserial PRIMARY KEY,
    id_externo text,
    empresa_id bigint REFERENCES empresas(id),
    empresa_id_externo text,
    nome text NOT NULL,
    telefone text,
    email text,
    cargo text,
    criado_em timestamptz,
    atualizado_em timestamptz
);

CREATE TABLE leads (
    id bigserial PRIMARY KEY,
    id_externo text,
    contato_id_externo text,
    empresa_id_externo text,
    etapa_id_externo text,
    funil_id_externo text,
    usuario_responsavel_id_externo text,
    nome text NOT NULL,
    venda numeric(12,2),
    utm_source text,
    utm_campaing text,
    utm_medium text,
    utm_content text,
    servicos text,
    data_contrato date,
    criado_em timestamptz,
    atualizado_em timestamptz
);

CREATE TABLE insights (
    id bigserial PRIMARY KEY,
    titulo_da_analise text NOT NULL,
    oque_foi_analisado jsonb NOT NULL DEFAULT '{}'::jsonb,
    resultado jsonb NOT NULL DEFAULT '{}'::jsonb,
    recomendado jsonb NOT NULL DEFAULT '{}'::jsonb,
    criado_em timestamptz,
    atualizado_em timestamptz
);

CREATE UNIQUE INDEX ux_usuarios_id_externo_not_null ON usuarios(id_externo) WHERE id_externo IS NOT NULL;
CREATE UNIQUE INDEX ux_funis_id_externo_not_null ON funis(id_externo) WHERE id_externo IS NOT NULL;
CREATE INDEX idx_etapas_id_externo ON etapas(id_externo);
CREATE UNIQUE INDEX ux_empresas_id_externo_not_null ON empresas(id_externo) WHERE id_externo IS NOT NULL;
CREATE UNIQUE INDEX ux_contatos_id_externo_not_null ON contatos(id_externo) WHERE id_externo IS NOT NULL;
CREATE UNIQUE INDEX ux_leads_id_externo_not_null ON leads(id_externo) WHERE id_externo IS NOT NULL;

CREATE INDEX idx_etapas_funil_id_externo ON etapas(funil_id_externo);
CREATE INDEX idx_contatos_empresa_id_externo ON contatos(empresa_id_externo);
CREATE INDEX idx_leads_contato_id_externo ON leads(contato_id_externo);
CREATE INDEX idx_leads_empresa_id_externo ON leads(empresa_id_externo);
CREATE INDEX idx_leads_etapa_id_externo ON leads(etapa_id_externo);
CREATE INDEX idx_leads_funil_id_externo ON leads(funil_id_externo);
CREATE INDEX idx_leads_usuario_responsavel_id_externo ON leads(usuario_responsavel_id_externo);
CREATE INDEX idx_leads_criado_em ON leads(criado_em);
CREATE INDEX idx_insights_criado_em ON insights(criado_em);

CREATE TRIGGER trg_usuarios_timestamps
BEFORE INSERT OR UPDATE ON usuarios
FOR EACH ROW EXECUTE FUNCTION preencher_timestamps_padrao();

CREATE TRIGGER trg_funis_timestamps
BEFORE INSERT OR UPDATE ON funis
FOR EACH ROW EXECUTE FUNCTION preencher_timestamps_padrao();

CREATE TRIGGER trg_etapas_timestamps
BEFORE INSERT OR UPDATE ON etapas
FOR EACH ROW EXECUTE FUNCTION preencher_timestamps_padrao();

CREATE TRIGGER trg_empresas_timestamps
BEFORE INSERT OR UPDATE ON empresas
FOR EACH ROW EXECUTE FUNCTION preencher_timestamps_padrao();

CREATE TRIGGER trg_contatos_timestamps
BEFORE INSERT OR UPDATE ON contatos
FOR EACH ROW EXECUTE FUNCTION preencher_timestamps_padrao();

CREATE TRIGGER trg_leads_timestamps
BEFORE INSERT OR UPDATE ON leads
FOR EACH ROW EXECUTE FUNCTION preencher_timestamps_padrao();

CREATE TRIGGER trg_insights_timestamps
BEFORE INSERT OR UPDATE ON insights
FOR EACH ROW EXECUTE FUNCTION preencher_timestamps_padrao();

CREATE VIEW vw_leads_com_dados_unificados AS
SELECT
    l.id,
    l.id_externo,
    l.nome,
    l.venda,
    l.contato_id_externo,
    c.nome AS contato_nome,
    c.telefone AS contato_telefone,
    c.email AS contato_email,
    c.cargo AS contato_cargo,
    l.empresa_id_externo,
    e.nome AS empresa_nome,
    e.telefone AS empresa_telefone,
    e.email AS empresa_email,
    e.ltv AS empresa_ltv,
    l.funil_id_externo,
    f.nome AS funil_nome,
    l.etapa_id_externo,
    et.nome AS etapa_nome,
    et.ordem AS etapa_ordem,
    l.usuario_responsavel_id_externo,
    u.nome AS usuario_responsavel_nome,
    u.papel AS usuario_responsavel_papel,
    l.utm_source,
    l.utm_campaing,
    l.utm_medium,
    l.utm_content,
    l.servicos,
    l.data_contrato,
    l.criado_em,
    l.atualizado_em
FROM leads l
LEFT JOIN contatos c ON c.id_externo = l.contato_id_externo
LEFT JOIN empresas e ON e.id_externo = l.empresa_id_externo
LEFT JOIN funis f ON f.id_externo = l.funil_id_externo
LEFT JOIN etapas et ON et.id_externo = l.etapa_id_externo
LEFT JOIN usuarios u ON u.id_externo = l.usuario_responsavel_id_externo;

COMMIT;
