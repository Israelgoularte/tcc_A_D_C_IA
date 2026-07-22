# Tool de consulta ao CRM

O workflow `Tool - Consultar CRM.json` e uma sub-workflow para uso no node
`Call n8n Workflow Tool` de um AI Agent.

Ele nao aceita SQL livre. A consulta e montada a partir de entidades, campos,
operadores e funcoes permitidos pelo codigo do workflow.

## Importacao

1. Importe `Tool - Consultar CRM.json` no n8n.
2. Confirme a credencial `Postgres n8n`.
3. Salve o workflow.
4. No workflow do agente, conecte um node `Call n8n Workflow Tool` na entrada
   `Tool` do AI Agent.
5. Selecione o workflow `Tool - Consultar CRM`.
6. Atualize os inputs do node para carregar o contrato da sub-workflow.
7. Marque os campos como definidos pelo modelo de IA.

## Descricao recomendada para a tool

```text
Consulta dados do CRM Kommo no PostgreSQL. Use para listar registros, filtrar
dados e calcular contagens, somas, medias, minimos e maximos. Nunca invente
entidades ou campos. Quando nao conhecer o schema, chame primeiro a operacao
catalogo. Os campos campos, filtros, agrupar_por, metricas e ordenacao devem ser
arrays JSON validos em formato de texto.
```

A tool normaliza JSON duplamente serializado, operadores SQL equivalentes e
nomes de metricas em ingles, sem remover as validacoes de seguranca.

## Entradas

| Entrada | Uso |
| --- | --- |
| `operacao` | `catalogo`, `listar` ou `agregar` |
| `entidade` | Entidade retornada pelo catalogo |
| `campos` | Array JSON com os campos da listagem |
| `filtros` | Array JSON com filtros |
| `agrupar_por` | Array JSON com campos de agrupamento |
| `metricas` | Array JSON com metricas |
| `ordenacao` | Array JSON com campos e direcao |
| `limite` | Quantidade entre 1 e 200 |

## Entidades

- `leads_unificados`: view recomendada para analises de leads com nomes de
  contato, empresa, funil, etapa e responsavel.
- `leads`
- `contatos`
- `empresas`
- `usuarios`
- `funis`
- `etapas`
- `insights`
- `dashboard_html`: seções salvas como especificações JSON; o campo `conteudo`
  precisa ser solicitado explicitamente.

Use a operacao `catalogo` para obter a lista exata de campos.

## Operadores de filtro

- `igual`
- `diferente`
- `maior`
- `maior_ou_igual`
- `menor`
- `menor_ou_igual`
- `contem`
- `em`
- `entre`
- `nulo`
- `nao_nulo`

Tambem sao aceitos os simbolos `=`, `!=`, `<>`, `>`, `>=`, `<` e `<=`.

Exemplo:

```json
[
  {
    "campo": "criado_em",
    "operador": "entre",
    "valor": ["2026-01-01", "2026-12-31"]
  },
  {
    "campo": "utm_source",
    "operador": "igual",
    "valor": "google"
  }
]
```

## Metricas

Funcoes permitidas:

- `contar`
- `somar`
- `media`
- `minimo`
- `maximo`

Tambem sao aceitos `count`, `sum`, `avg`, `min` e `max`. A propriedade da
metrica pode ser `funcao` ou `operacao`.

O formato compacto com `expressao` tambem e aceito:

```json
[
  {
    "expressao": "count(id)",
    "alias": "quantidade"
  },
  {
    "expressao": "sum(venda)",
    "alias": "valor"
  }
]
```

Somente expressoes simples no formato `funcao(campo)` sao permitidas.

Exemplo para faturamento por origem:

```json
{
  "operacao": "agregar",
  "entidade": "leads_unificados",
  "filtros": "[]",
  "agrupar_por": "[\"utm_source\"]",
  "metricas": "[{\"funcao\":\"contar\",\"campo\":\"*\",\"alias\":\"total_leads\"},{\"funcao\":\"somar\",\"campo\":\"venda\",\"alias\":\"faturamento\"}]",
  "ordenacao": "[{\"campo\":\"faturamento\",\"direcao\":\"desc\"}]",
  "limite": 20
}
```

## Prompt recomendado para o AI Agent

```text
Voce e um analista de dados do CRM.

Use a tool Consultar CRM para responder perguntas que dependam do banco.
Antes da primeira consulta, use catalogo se nao tiver certeza sobre entidades
ou campos. Para analises de leads, prefira leads_unificados.

Regras:
- Nunca invente resultados.
- Nunca solicite SQL livre para a tool.
- Use listar para registros e agregar para indicadores.
- Use datas em ISO 8601.
- Aplique o menor limite suficiente para responder.
- Informe filtros e periodo utilizados.
- Diferencie quantidade de leads de soma de vendas.
- Nao exponha telefone ou email quando a pergunta puder ser respondida sem
  dados pessoais.
- Se a tool retornar zero registros, diga que nao encontrou dados para os
  filtros informados.
```

## Seguranca

Em producao, configure no n8n uma credencial PostgreSQL com usuario dedicado
somente leitura e acesso apenas ao schema `analise_dados`.

Exemplo, executado por um administrador e com uma senha fornecida fora do
codigo:

```sql
CREATE ROLE agente_consulta LOGIN PASSWORD 'defina-fora-do-repositorio';
GRANT CONNECT ON DATABASE n8n TO agente_consulta;
GRANT USAGE ON SCHEMA analise_dados TO agente_consulta;
GRANT SELECT ON ALL TABLES IN SCHEMA analise_dados TO agente_consulta;
ALTER DEFAULT PRIVILEGES IN SCHEMA analise_dados
GRANT SELECT ON TABLES TO agente_consulta;
```

Nao use a credencial administrativa do PostgreSQL no AI Agent.
