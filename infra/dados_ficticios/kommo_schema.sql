-- Schema das entidades usadas para sincronizacao e analise de dados do Kommo CRM.
-- Este arquivo cria apenas tabelas, indices, triggers e views. Nao insere dados.

BEGIN;

CREATE SCHEMA IF NOT EXISTS analise_dados;
SET search_path TO analise_dados;

DROP VIEW IF EXISTS analise_dados.vw_leads_com_dados_unificados;
DROP TABLE IF EXISTS analise_dados.dashboard_secoes;
DROP TABLE IF EXISTS analise_dados.dashboard_html;
DROP TABLE IF EXISTS analise_dados.insights;
DROP TABLE IF EXISTS analise_dados.leads;
DROP TABLE IF EXISTS analise_dados.contatos;
DROP TABLE IF EXISTS analise_dados.empresas;
DROP TABLE IF EXISTS analise_dados.etapas;
DROP TABLE IF EXISTS analise_dados.funis;
DROP TABLE IF EXISTS analise_dados.usuarios;
DROP FUNCTION IF EXISTS analise_dados.preencher_timestamps_padrao();

CREATE FUNCTION analise_dados.preencher_timestamps_padrao()
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

CREATE TABLE analise_dados.usuarios (
    id bigserial PRIMARY KEY,
    id_externo text,
    nome text NOT NULL,
    papel text NOT NULL CONSTRAINT usuarios_papel_check CHECK (
        lower(papel) IN ('sdr', 'closer')
        OR lower(papel) ~ '^sdr_[0-9]+$'
    ),
    criado_em timestamptz,
    atualizado_em timestamptz
);

CREATE TABLE analise_dados.funis (
    id bigserial PRIMARY KEY,
    id_externo text,
    nome text NOT NULL,
    criado_em timestamptz,
    atualizado_em timestamptz
);

CREATE TABLE analise_dados.etapas (
    id bigserial PRIMARY KEY,
    id_externo text,
    funil_id bigint REFERENCES analise_dados.funis(id),
    funil_id_externo text,
    nome text NOT NULL,
    descricao text,
    ordem integer,
    criado_em timestamptz,
    atualizado_em timestamptz
);

CREATE TABLE analise_dados.empresas (
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

CREATE TABLE analise_dados.contatos (
    id bigserial PRIMARY KEY,
    id_externo text,
    empresa_id bigint REFERENCES analise_dados.empresas(id),
    empresa_id_externo text,
    nome text NOT NULL,
    telefone text,
    email text,
    cargo text,
    criado_em timestamptz,
    atualizado_em timestamptz
);

CREATE TABLE analise_dados.leads (
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

CREATE TABLE analise_dados.insights (
    id bigserial PRIMARY KEY,
    titulo_da_analise text NOT NULL,
    oque_foi_analisado jsonb NOT NULL DEFAULT '{}'::jsonb,
    resultado jsonb NOT NULL DEFAULT '{}'::jsonb,
    recomendado jsonb NOT NULL DEFAULT '{}'::jsonb,
    criado_em timestamptz,
    atualizado_em timestamptz
);

CREATE TABLE analise_dados.dashboard_secoes (
    id bigserial PRIMARY KEY,
    nome text NOT NULL,
    descricao text,
    ordem integer NOT NULL DEFAULT 0,
    ativo boolean NOT NULL DEFAULT true,
    config jsonb NOT NULL DEFAULT '{"versao": 1, "componentes": []}'::jsonb,
    criado_em timestamptz,
    atualizado_em timestamptz
);

CREATE UNIQUE INDEX ux_usuarios_id_externo_not_null ON analise_dados.usuarios(id_externo) WHERE id_externo IS NOT NULL;
CREATE UNIQUE INDEX ux_funis_id_externo_not_null ON analise_dados.funis(id_externo) WHERE id_externo IS NOT NULL;
CREATE UNIQUE INDEX ux_etapas_id_externo_not_null ON analise_dados.etapas(id_externo) WHERE id_externo IS NOT NULL;
CREATE UNIQUE INDEX ux_empresas_id_externo_not_null ON analise_dados.empresas(id_externo) WHERE id_externo IS NOT NULL;
CREATE UNIQUE INDEX ux_contatos_id_externo_not_null ON analise_dados.contatos(id_externo) WHERE id_externo IS NOT NULL;
CREATE UNIQUE INDEX ux_leads_id_externo_not_null ON analise_dados.leads(id_externo) WHERE id_externo IS NOT NULL;

CREATE INDEX idx_etapas_funil_id_externo ON analise_dados.etapas(funil_id_externo);
CREATE INDEX idx_contatos_empresa_id_externo ON analise_dados.contatos(empresa_id_externo);
CREATE INDEX idx_leads_contato_id_externo ON analise_dados.leads(contato_id_externo);
CREATE INDEX idx_leads_empresa_id_externo ON analise_dados.leads(empresa_id_externo);
CREATE INDEX idx_leads_etapa_id_externo ON analise_dados.leads(etapa_id_externo);
CREATE INDEX idx_leads_funil_id_externo ON analise_dados.leads(funil_id_externo);
CREATE INDEX idx_leads_usuario_responsavel_id_externo ON analise_dados.leads(usuario_responsavel_id_externo);
CREATE INDEX idx_leads_criado_em ON analise_dados.leads(criado_em);
CREATE INDEX idx_insights_criado_em ON analise_dados.insights(criado_em);
CREATE INDEX idx_dashboard_secoes_ordem ON analise_dados.dashboard_secoes(ordem);
CREATE INDEX idx_dashboard_secoes_ativo ON analise_dados.dashboard_secoes(ativo);

CREATE TRIGGER trg_usuarios_timestamps
BEFORE INSERT OR UPDATE ON analise_dados.usuarios
FOR EACH ROW EXECUTE FUNCTION analise_dados.preencher_timestamps_padrao();

CREATE TRIGGER trg_funis_timestamps
BEFORE INSERT OR UPDATE ON analise_dados.funis
FOR EACH ROW EXECUTE FUNCTION analise_dados.preencher_timestamps_padrao();

CREATE TRIGGER trg_etapas_timestamps
BEFORE INSERT OR UPDATE ON analise_dados.etapas
FOR EACH ROW EXECUTE FUNCTION analise_dados.preencher_timestamps_padrao();

CREATE TRIGGER trg_empresas_timestamps
BEFORE INSERT OR UPDATE ON analise_dados.empresas
FOR EACH ROW EXECUTE FUNCTION analise_dados.preencher_timestamps_padrao();

CREATE TRIGGER trg_contatos_timestamps
BEFORE INSERT OR UPDATE ON analise_dados.contatos
FOR EACH ROW EXECUTE FUNCTION analise_dados.preencher_timestamps_padrao();

CREATE TRIGGER trg_leads_timestamps
BEFORE INSERT OR UPDATE ON analise_dados.leads
FOR EACH ROW EXECUTE FUNCTION analise_dados.preencher_timestamps_padrao();

CREATE TRIGGER trg_insights_timestamps
BEFORE INSERT OR UPDATE ON analise_dados.insights
FOR EACH ROW EXECUTE FUNCTION analise_dados.preencher_timestamps_padrao();

CREATE TRIGGER trg_dashboard_secoes_timestamps
BEFORE INSERT OR UPDATE ON analise_dados.dashboard_secoes
FOR EACH ROW EXECUTE FUNCTION analise_dados.preencher_timestamps_padrao();

CREATE VIEW analise_dados.vw_leads_com_dados_unificados AS
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
FROM analise_dados.leads l
LEFT JOIN analise_dados.contatos c ON c.id_externo = l.contato_id_externo
LEFT JOIN analise_dados.empresas e ON e.id_externo = l.empresa_id_externo
LEFT JOIN analise_dados.funis f ON f.id_externo = l.funil_id_externo
LEFT JOIN analise_dados.etapas et ON et.id_externo = l.etapa_id_externo
LEFT JOIN analise_dados.usuarios u ON u.id_externo = l.usuario_responsavel_id_externo;

-- Funções seguras para o agente de IA criar/atualizar seções do dashboard.
-- Validam o JSON do campo config e retornam sucesso/erro como dados (nunca
-- lançam exceção), permitindo que o agente se autocorrija.

CREATE OR REPLACE FUNCTION analise_dados.criar_secao(p_nome text, p_descricao text, p_config text)
RETURNS TABLE(sucesso boolean, erro text, id bigint, nome text, ordem integer, ativo boolean) AS $FN$
DECLARE v_config jsonb; v_row analise_dados.dashboard_secoes;
BEGIN
  BEGIN
    v_config := p_config::jsonb;
  EXCEPTION WHEN others THEN
    RETURN QUERY SELECT false, 'config invalido: ' || SQLERRM || '. Gere novamente uma string JSON valida com as chaves versao e componentes.', NULL::bigint, p_nome, NULL::integer, NULL::boolean;
    RETURN;
  END;
  IF v_config IS NULL OR NOT (v_config ? 'versao') OR NOT (v_config ? 'componentes') OR jsonb_typeof(v_config->'componentes') <> 'array' THEN
    RETURN QUERY SELECT false, 'config deve ser um objeto JSON com as chaves versao e componentes (array).', NULL::bigint, p_nome, NULL::integer, NULL::boolean;
    RETURN;
  END IF;
  INSERT INTO analise_dados.dashboard_secoes (nome, descricao, ordem, ativo, config)
  VALUES (p_nome, p_descricao, coalesce((SELECT max(ds.ordem) + 1 FROM analise_dados.dashboard_secoes ds), 0), true, v_config)
  RETURNING * INTO v_row;
  RETURN QUERY SELECT true, NULL::text, v_row.id, v_row.nome, v_row.ordem, v_row.ativo;
END;
$FN$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION analise_dados.atualizar_secao(p_id bigint, p_nome text, p_descricao text, p_config text)
RETURNS TABLE(sucesso boolean, erro text, id bigint, nome text, ordem integer, ativo boolean) AS $FN$
DECLARE v_config jsonb; v_row analise_dados.dashboard_secoes;
BEGIN
  BEGIN
    v_config := p_config::jsonb;
  EXCEPTION WHEN others THEN
    RETURN QUERY SELECT false, 'config invalido: ' || SQLERRM || '. Gere novamente uma string JSON valida com as chaves versao e componentes.', p_id, p_nome, NULL::integer, NULL::boolean;
    RETURN;
  END;
  IF v_config IS NULL OR NOT (v_config ? 'versao') OR NOT (v_config ? 'componentes') OR jsonb_typeof(v_config->'componentes') <> 'array' THEN
    RETURN QUERY SELECT false, 'config deve ser um objeto JSON com as chaves versao e componentes (array).', p_id, p_nome, NULL::integer, NULL::boolean;
    RETURN;
  END IF;
  UPDATE analise_dados.dashboard_secoes ds
  SET nome = coalesce(p_nome, ds.nome), descricao = coalesce(p_descricao, ds.descricao), config = v_config, atualizado_em = now()
  WHERE ds.id = p_id
  RETURNING * INTO v_row;
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'secao nao encontrada para o id ' || p_id || '. Consulte sections_existentes para obter o id correto.', p_id, p_nome, NULL::integer, NULL::boolean;
    RETURN;
  END IF;
  RETURN QUERY SELECT true, NULL::text, v_row.id, v_row.nome, v_row.ordem, v_row.ativo;
END;
$FN$ LANGUAGE plpgsql;

COMMIT;
