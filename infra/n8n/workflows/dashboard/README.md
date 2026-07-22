# Dashboard dinâmico

Esta implementação é uma simulação sem autenticação e sem configuração de
CORS. Os três workflows possuem responsabilidades separadas.

## Pagina DashBoard

Endpoint:

```text
GET https://SEU_DOMINIO/webhook/dashboard
```

Retorna a página HTML completa. A página:

- consulta a API de seções ao abrir;
- interpreta o contrato JSON;
- cria os componentes visuais;
- consulta a API de dados para cada componente;
- suporta componentes `kpi`, `tabela` e `barras`.

O HTML fonte está em `dashboard-page.html` e também é mantido em
`exemplo-dashboard.html`.

## API - Sections Dash

Endpoint:

```text
POST https://SEU_DOMINIO/webhook/dashboard/sections
```

Lê os registros da tabela `analise_dados.dashboard_secoes`. O campo `config`
(jsonb) contém a especificação JSON da seção. A API considera apenas seções
com `ativo = true`, ordena por `ordem` (e depois por `id`), valida, normaliza e
retorna as instruções que a página usará para montar o dashboard.

Exemplo de valor para `config`:

```json
{
  "versao": 1,
  "componentes": [
    {
      "id": "total-leads",
      "tipo": "kpi",
      "titulo": "Total de leads",
      "largura": 3,
      "campo_valor": "total",
      "formato": "numero",
      "consulta": {
        "operacao": "agregar",
        "entidade": "leads_unificados",
        "filtros": [],
        "metricas": [
          {
            "expressao": "count(id)",
            "alias": "total"
          }
        ],
        "limite": 1
      }
    }
  ]
}
```

O arquivo `exemplo_response.json` contém um contrato completo.

Registros cujo `config` esteja em HTML legado são ignorados e retornados em
`erros`. Eles devem ser convertidos para a especificação JSON.

> Migração: a tabela anterior `dashboard_html` (`conteudo text`) foi
> substituída por `dashboard_secoes` (`config jsonb`, com `ordem` e `ativo`).
> Em bases já existentes, aplique
> `infra/dados_ficticios/migrations/20260621_02_create_dashboard_secoes.sql`.

### Componentes

`kpi`:

- exige `campo_valor`;
- aceita `formato`: `texto`, `numero`, `moeda`, `percentual` ou `data`.

`tabela`:

- exige `colunas`;
- cada coluna informa `campo`, `titulo` e `formato`.

`barras`:

- exige `campo_categoria` e `campo_valor`;
- usa o maior valor retornado como escala.

Todos os componentes exigem:

- `id` único dentro da seção;
- `tipo`;
- `titulo`;
- `consulta`;
- `largura` entre 3 e 12 colunas.

## API - Dados Dashboard

Endpoint:

```text
POST https://SEU_DOMINIO/webhook/dashboard_dados
```

Recebe uma consulta estruturada e executa `Tool - Consultar CRM`.

```json
{
  "identificador": "leads-por-etapa",
  "consulta": {
    "operacao": "agregar",
    "entidade": "leads_unificados",
    "filtros": [],
    "agrupar_por": ["etapa_nome"],
    "metricas": [
      {
        "expressao": "count(id)",
        "alias": "quantidade"
      }
    ],
    "ordenacao": [
      {
        "campo": "quantidade",
        "direcao": "desc"
      }
    ],
    "limite": 20
  }
}
```

Resposta:

```json
{
  "sucesso": true,
  "identificador": "leads-por-etapa",
  "contexto": {
    "operacao": "agregar",
    "entidade": "leads_unificados",
    "limite": 20,
    "filtros_aplicados": 0
  },
  "total_retornado": 5,
  "dados": []
}
```

Em caso de falha na consulta, a API responde com HTTP 200 e o contrato de erro
abaixo, garantindo que a página sempre receba JSON válido e exiba a mensagem no
componente correspondente:

```json
{
  "sucesso": false,
  "identificador": "leads-por-etapa",
  "erro": "mensagem da falha",
  "total_retornado": 0,
  "dados": []
}
```

## Ordem de importação

1. `Tool - Consultar CRM`
2. `API - Dados Dashboard`
3. `API - Sections Dash`
4. `Pagina DashBoard`

O script `scripts/import-workflows.sh` executa essa importação como parte do
setup e das atualizações.
