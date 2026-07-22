BEGIN;

CREATE SCHEMA IF NOT EXISTS analise_dados;

CREATE TABLE IF NOT EXISTS analise_dados.dashboard_html (
    id bigserial PRIMARY KEY,
    nome text NOT NULL,
    descricao text,
    conteudo text NOT NULL
);

COMMIT;
