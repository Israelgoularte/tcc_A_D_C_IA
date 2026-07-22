-- Migração 20260713_01
-- Corrige os achados A1 e A2 do relatório de testes (testes/resultados_testes.md):
--
-- A2a: etapas duplicadas (id_externo repetido) multiplicavam leads na view
--      vw_leads_com_dados_unificados. Remove duplicatas (mantém o menor id)
--      e substitui o índice não-único por índice único parcial.
-- A2b: data_contrato preenchida para leads fora de etapa de ganho, violando a
--      regra do projeto. Zera data_contrato de leads que não estão em etapa
--      "won".
-- A1:  cria funções que validam o JSON do campo config e retornam sucesso/erro
--      como dados (sem lançar exceção), para que o agente de IA receba o erro
--      como observação e se autocorrija, em vez de abortar o workflow.
--      Requer apontar as tools create_section/update_section do workflow chat
--      para SELECT * FROM analise_dados.criar_secao(...)/atualizar_secao(...).

BEGIN;

-- A2a: dedupe de etapas + índice único
DELETE FROM analise_dados.etapas e
USING analise_dados.etapas d
WHERE e.id_externo = d.id_externo
  AND e.id > d.id;

DROP INDEX IF EXISTS analise_dados.idx_etapas_id_externo;
CREATE UNIQUE INDEX IF NOT EXISTS ux_etapas_id_externo_not_null
    ON analise_dados.etapas(id_externo)
    WHERE id_externo IS NOT NULL;

-- A2b: data_contrato somente em etapa de ganho
UPDATE analise_dados.leads l
SET data_contrato = NULL
WHERE data_contrato IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM analise_dados.etapas et
    WHERE et.id_externo = l.etapa_id_externo
      AND lower(et.nome) LIKE '%won%'
  );

-- A1: funções seguras de criação/atualização de seções
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
