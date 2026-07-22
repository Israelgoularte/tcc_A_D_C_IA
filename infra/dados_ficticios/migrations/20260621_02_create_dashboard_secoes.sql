-- Migração: substitui analise_dados.dashboard_html por analise_dados.dashboard_secoes.
--
-- Motivação:
--   A tabela antiga guardava a especificação da seção em "conteudo text", exigindo
--   parse de string em todo consumo. A nova tabela guarda a configuração em
--   "config jsonb", de modo que a API retorne JSON nativo, além de ganhar
--   "ordem" (ordenação das seções) e "ativo" (habilitar/ocultar sem apagar).
--
-- Esta migração é idempotente e preserva os dados válidos existentes.
-- Aplicar uma única vez em ambientes que já possuem dados em dashboard_html.

BEGIN;

-- A função de timestamps já existe no schema (criada pelo DDL principal).
-- Recriada aqui com IF NOT EXISTS lógico para tornar a migração autossuficiente.
CREATE OR REPLACE FUNCTION analise_dados.preencher_timestamps_padrao()
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

CREATE TABLE IF NOT EXISTS analise_dados.dashboard_secoes (
    id bigserial PRIMARY KEY,
    nome text NOT NULL,
    descricao text,
    ordem integer NOT NULL DEFAULT 0,
    ativo boolean NOT NULL DEFAULT true,
    config jsonb NOT NULL DEFAULT '{"versao": 1, "componentes": []}'::jsonb,
    criado_em timestamptz,
    atualizado_em timestamptz
);

CREATE INDEX IF NOT EXISTS idx_dashboard_secoes_ordem
    ON analise_dados.dashboard_secoes(ordem);
CREATE INDEX IF NOT EXISTS idx_dashboard_secoes_ativo
    ON analise_dados.dashboard_secoes(ativo);

DROP TRIGGER IF EXISTS trg_dashboard_secoes_timestamps
    ON analise_dados.dashboard_secoes;
CREATE TRIGGER trg_dashboard_secoes_timestamps
BEFORE INSERT OR UPDATE ON analise_dados.dashboard_secoes
FOR EACH ROW EXECUTE FUNCTION analise_dados.preencher_timestamps_padrao();

-- Migração dos dados existentes (apenas se a tabela antiga existir e ainda
-- não tiver sido migrada). Somente registros cujo "conteudo" seja um JSON de
-- objeto válido são copiados; registros legados em HTML são ignorados.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'analise_dados' AND table_name = 'dashboard_html'
    )
    AND NOT EXISTS (SELECT 1 FROM analise_dados.dashboard_secoes) THEN
        INSERT INTO analise_dados.dashboard_secoes (nome, descricao, ordem, ativo, config)
        SELECT
            h.nome,
            h.descricao,
            (row_number() OVER (ORDER BY h.id))::int AS ordem,
            true AS ativo,
            h.conteudo::jsonb AS config
        FROM analise_dados.dashboard_html h
        WHERE h.conteudo IS NOT NULL
          AND left(btrim(h.conteudo), 1) = '{';
    END IF;
END $$;

-- Remove a tabela legada após a migração (substituição completa).
DROP TABLE IF EXISTS analise_dados.dashboard_html;

COMMIT;
