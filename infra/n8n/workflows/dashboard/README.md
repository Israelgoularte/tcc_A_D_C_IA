# Endpoint de dados para dashboards

O workflow `API - Dados Dashboard.json` disponibiliza um endpoint HTTP
somente leitura que reutiliza a sub-workflow `Tool - Consultar CRM`.

## Configuracao

Este projeto usa um ambiente de simulacao. Os endpoints nao exigem
autenticacao e nao aplicam configuracao de CORS.

Importe primeiro `Tool - Consultar CRM.json`. Depois importe este workflow,
abra o node `Consultar CRM` e confirme que a sub-workflow selecionada e
`Tool - Consultar CRM`.

Ative os dois workflows para habilitar as URLs de producao:

```text
API - Dados Dashboard
API - Sections Dash

POST https://SEU_DOMINIO/webhook/dashboard_dados
POST https://SEU_DOMINIO/webhook/dashboard/sections
```

Se apenas `API - Sections Dash` estiver ativo, o shell conseguira listar as
secoes, mas o JavaScript interno delas falhara ao consultar os indicadores.
Nesse caso, o n8n retorna que o webhook `POST dashboard_dados` nao esta
registrado.

## Consultar catalogo

```bash
curl -X POST "https://SEU_DOMINIO/webhook/dashboard_dados" \
  -H "Content-Type: application/json" \
  -d '{"operacao":"catalogo"}'
```

## Listar leads

```json
{
  "operacao": "listar",
  "entidade": "leads_unificados",
  "campos": ["nome", "venda", "etapa_nome", "criado_em"],
  "filtros": [
    {
      "campo": "criado_em",
      "operador": "entre",
      "valor": ["2026-01-01", "2026-12-31"]
    }
  ],
  "ordenacao": [
    {
      "campo": "venda",
      "direcao": "desc"
    }
  ],
  "limite": 100
}
```

## Indicadores agregados

```json
{
  "operacao": "agregar",
  "entidade": "leads_unificados",
  "filtros": [],
  "agrupar_por": ["servicos", "etapa_nome"],
  "metricas": [
    {
      "expressao": "count(id)",
      "alias": "quantidade"
    },
    {
      "expressao": "sum(venda)",
      "alias": "valor"
    }
  ],
  "ordenacao": [
    {
      "campo": "valor",
      "direcao": "desc"
    }
  ],
  "limite": 200
}
```
6e870fd777f8b0ddfe50d9c1f4ae3f71a1936f11063b018081b7a32f39b8400a
## API de sections

O workflow `API - Sections Dash.json` lista todos os registros da tabela
`analise_dados.dashboard_html`, ordenados pelo `id`.

```bash
curl -X POST "https://SEU_DOMINIO/webhook/dashboard/sections" \
  -H "Content-Type: application/json" \
  -d '{}'
```

Resposta:

```json
[
  {
    "sucesso": true,
    "total": 1,
    "secoes": [
      {
        "json": {
          "id": "1",
          "nome": "Resumo comercial",
          "descricao": "Indicadores gerais do CRM",
          "conteudo": "<section>...</section>"
        },
        "pairedItem": {
          "item": 0
        }
      }
    ]
  }
]
```

O HTML principal normaliza tanto esse formato do n8n quanto o formato direto
sem os wrappers de `json` e array externo.

## Resposta

```json
{
  "sucesso": true,
  "contexto": {
    "operacao": "listar",
    "entidade": "leads_unificados",
    "limite": 100,
    "filtros_aplicados": 1
  },
  "total_retornado": 10,
  "dados": []
}
```

Nao coloque a chave diretamente no JavaScript entregue ao navegador. Em
producao, prefira chamar este endpoint por um backend ou proxy autenticado.

## Dashboard HTML principal

O arquivo `exemplo-dashboard.html` e o shell principal. Ele:

- consulta `API - Sections Dash`
- cria a navegacao lateral
- carrega cada registro como uma section
- executa o CSS e JavaScript armazenados em `conteudo`
- disponibiliza `window.DashboardAPI` para as sections consultarem dados

Abra o arquivo, informe a URL base do n8n e clique em
`Carregar dashboard`.

## Formato do campo conteudo

Cada registro deve possuir exatamente uma `<section>` raiz:

```html
<section id="resumo-comercial" class="resumo-comercial">
  <style>
    #resumo-comercial {
      padding: 24px;
    }

    #resumo-comercial .valor {
      font-size: 2rem;
      font-weight: 700;
    }
  </style>

  <div class="valor" data-total-leads>Carregando...</div>

  <script>
    (async () => {
      const [resultado] = await DashboardAPI.consultar({
        operacao: "agregar",
        entidade: "leads_unificados",
        metricas: [
          {
            expressao: "count(id)",
            alias: "total"
          }
        ],
        limite: 1
      });

      document
        .querySelector("#resumo-comercial [data-total-leads]")
        .textContent = DashboardAPI.formatarNumero(resultado.total);
    })().catch((error) => {
      document
        .querySelector("#resumo-comercial [data-total-leads]")
        .textContent = error.message;
    });
  </script>
</section>
```

Funcoes disponiveis:

- `DashboardAPI.consultar(payload)`
- `DashboardAPI.formatarMoeda(valor)`
- `DashboardAPI.formatarNumero(valor)`
- `DashboardAPI.formatarData(valor)`
- `DashboardAPI.registrarCleanup(funcao)`

Use IDs e classes exclusivos em cada section para evitar conflitos entre o CSS
e JavaScript dos registros.

Esse exemplo e adequado apenas para simulacao. Antes de usar em producao,
adicione autenticacao, autorizacao e uma politica de origem adequada.

O conteudo da tabela e executado como codigo no navegador. Somente usuarios
administrativos confiaveis devem poder inserir ou editar `dashboard_html`.
