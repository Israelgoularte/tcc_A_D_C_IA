# Projeto: Análise de Dados com IA

## Objetivo

Criar um ambiente de simulação integrado ao Kommo CRM para:

- receber e persistir eventos de leads e contatos;
- consultar dados comerciais de forma estruturada e segura;
- permitir que um agente de IA gere análises e recomendações;
- criar e carregar seções HTML dinâmicas em um dashboard.

## Infraestrutura

### Servidor

- [x] Sistema operacional: Ubuntu 24.04 LTS
- [x] CPU: 2 núcleos
- [x] Memória: 8 GB
- [x] Disco: 100 GB
- [x] Largura de banda: 8 TB

### Docker

Arquivo principal: `infra/n8n/docker-compose.yml`.

- [x] Traefik
  - Imagem: `traefik:${TRAEFIK_IMAGE_TAG:-latest}`
  - Responsável pelo proxy reverso e terminação TLS.
  - Emite certificados HTTPS com Let's Encrypt.
  - Expõe as portas `80` e `443`.
  - Mantém os certificados no volume `traefik_data`.

- [x] PostgreSQL
  - Imagem: `postgres:${POSTGRES_IMAGE_TAG:-16-alpine}`
  - Usa autenticação SCRAM-SHA-256.
  - Persiste os dados no volume `postgres_data`.
  - Possui health check com `pg_isready`.
  - Permanece acessível somente pela rede interna do Docker.

- [x] n8n
  - Imagem: `n8nio/n8n:${N8N_IMAGE_TAG:-2.22.5}`
  - Armazena credenciais, execuções e configurações no PostgreSQL.
  - Persiste os dados no volume `n8n_data`.
  - Monta os workflows locais em `/workflows`.
  - Aguarda o PostgreSQL ficar saudável antes de iniciar.
  - É publicado externamente pelo Traefik.

### Redes e volumes

- [x] Rede `internal`: comunicação entre n8n e PostgreSQL.
- [x] Rede `proxy`: comunicação entre n8n e Traefik.
- [x] Volume `traefik_data`: certificados TLS.
- [x] Volume `postgres_data`: dados do PostgreSQL.
- [x] Volume `n8n_data`: dados persistentes do n8n.

### Variáveis de ambiente

O arquivo de referência é `infra/n8n/.env.exemple`. Antes de subir o ambiente, deve ser criado um arquivo `.env` com:

- credenciais do PostgreSQL;
- domínio e URL pública do n8n;
- e-mail usado pelo Let's Encrypt;
- chave `N8N_ENCRYPTION_KEY`;
- tags das imagens, quando for necessário sobrescrever as versões padrão.

O arquivo `.env` real não deve ser versionado. A `N8N_ENCRYPTION_KEY` deve ser longa, aleatória e mantida estável, pois é usada para proteger as credenciais armazenadas pelo n8n.

## PostgreSQL

O DDL principal está em `infra/dados_ficticios/kommo_schema.sql`.

### Schema

- [x] Schema: `analise_dados`

### Tabelas

- [x] `usuarios`
  - Armazena os usuários comerciais sincronizados com o Kommo.
  - Campos principais: `id_externo`, `nome`, `papel`, `criado_em` e `atualizado_em`.

- [x] `funis`
  - Armazena os funis comerciais.
  - Campos principais: `id_externo`, `nome`, `criado_em` e `atualizado_em`.

- [x] `etapas`
  - Armazena as etapas de cada funil.
  - Relaciona-se com `funis`.
  - Campos principais: `id_externo`, `funil_id_externo`, `nome`, `descricao` e `ordem`.

- [x] `empresas`
  - Armazena empresas vinculadas aos contatos e leads.
  - Campos principais: `id_externo`, `nome`, `telefone`, `email`, `ltv` e `data_ultimo_contrato`.

- [x] `contatos`
  - Armazena os contatos sincronizados com o Kommo.
  - Relaciona-se com `empresas`.
  - Campos principais: `id_externo`, `empresa_id_externo`, `nome`, `telefone`, `email` e `cargo`.

- [x] `leads`
  - Armazena as oportunidades comerciais.
  - Relaciona o lead a contato, empresa, etapa, funil e usuário responsável.
  - Campos principais: `id_externo`, `nome`, `venda`, campos UTM, `servicos`, `data_contrato`, `criado_em` e `atualizado_em`.
  - `data_contrato` deve ser preenchida somente quando o lead estiver em uma etapa de ganho.

- [x] `insights`
  - Armazena análises e recomendações geradas.
  - Campos principais: `titulo_da_analise`, `oque_foi_analisado`, `resultado` e `recomendado`.
  - Os conteúdos estruturados são armazenados em colunas `JSONB`.

- [x] `dashboard_secoes`
  - Armazena as seções dinâmicas do dashboard (substitui a antiga `dashboard_html`).
  - Campos: `id`, `nome`, `descricao`, `ordem`, `ativo`, `config`, `criado_em` e `atualizado_em`.
  - `config` é `jsonb` e contém a especificação JSON declarativa (`versao` e `componentes`).
  - `ordem` define a posição da seção; `ativo` permite ocultar uma seção sem apagá-la.
  - Migração para bases existentes: `migrations/20260621_02_create_dashboard_secoes.sql`.

### View analítica

- [x] `analise_dados.vw_leads_com_dados_unificados`
  - Consolida leads, contatos, empresas, funis, etapas e usuários.
  - É a principal fonte para consultas analíticas do agente de IA.
  - Evita que o agente precise conhecer ou montar manualmente todos os relacionamentos.

### Integridade e performance

- [x] Chaves primárias e estrangeiras.
- [x] Restrições de unicidade para identificadores externos.
- [x] Índices para relacionamentos, datas e campos usados nas consultas.
- [x] Função e triggers para atualização automática de `atualizado_em`.

### Migrações

O arquivo `kommo_schema.sql` recria estruturas e deve ser usado apenas na inicialização ou no reset da simulação. Em um ambiente com dados reais, alterações devem ser aplicadas por migrações incrementais.

Migração existente:

- `infra/dados_ficticios/migrations/20260621_create_dashboard_html.sql`

## n8n

Os workflows estão armazenados em `infra/n8n/workflows`.

### Setup

- [x] `01_kommo_credenciais`
  - Armazena as credenciais usadas nos testes.
  - Esta abordagem é aceita somente para a simulação. Em produção, usar o gerenciador de credenciais do n8n e OAuth2 quando disponível.

- [x] `02_Criar_tabelas`
  - Executa o DDL necessário para criar o schema e as tabelas.

- [x] `03_kommo_criar_estrutura`
  - Cria a estrutura do Kommo usada na simulação.

- [x] `04_dados_de_teste`
  - Gera dados fictícios para as análises.

- [x] `ajuste_bd`
  - Aplica ajustes complementares no banco de dados.

- [x] `Reset`
  - Remove a estrutura criada para permitir reiniciar a simulação.
  - É destrutivo e não deve ser executado em produção.

### Integração Kommo

- [x] `Kommo - Evento Contato`
  - Recebe eventos de criação, atualização e exclusão de contatos.
  - Normaliza os dados e atualiza a tabela `contatos`.

- [x] `Kommo - Evento Lead`
  - Recebe eventos de criação, atualização e exclusão de leads.
  - Normaliza os dados e atualiza a tabela `leads`.

### Dashboard

- [x] `API - Dados Dashboard`
  - Endpoint `POST /webhook/dashboard_dados`.
  - Recebe uma consulta estruturada da seção.
  - Encaminha a consulta ao workflow `Tool - Consultar CRM`.
  - Não aceita SQL livre.
  - Em caso de falha, responde com HTTP 200 e contrato de erro (`sucesso: false`, `erro`, `dados: []`).

- [x] `API - Sections Dash`
  - Endpoint `POST /webhook/dashboard/sections`.
  - Lista as seções ativas armazenadas na tabela `dashboard_secoes`, ordenadas por `ordem`.
  - Lê o campo `config` (jsonb), valida e normaliza o contrato.
  - Retorna até 200 registros por chamada.

- [x] `Pagina DashBoard`
  - Expõe a página HTML principal do dashboard.
  - Carrega dinamicamente as seções retornadas pela API.

- [x] `exemplo-dashboard.html`
  - Exemplo local do dashboard principal.
  - Usa o contrato definido em `exemplo_response.json`.

### Agente de IA

- [x] `chat`
  - Disponibiliza a interface de conversa com o agente.
  - Usa memória de conversa armazenada no PostgreSQL.
  - Pode consultar o CRM e administrar as seções do dashboard.

- [x] `Tool - Consultar CRM`
  - Constrói consultas de leitura a partir de uma entrada estruturada.
  - Permite operações de catálogo, listagem e agregação.
  - Valida entidades, campos, métricas, filtros, ordenação e limite.
  - Limita o retorno a 200 registros.
  - Não executa SQL fornecido diretamente pelo modelo.

- [x] `sections_existentes`
  - Lista as seções cadastradas.

- [x] `sections_content`
  - Obtém o conteúdo de uma seção existente.

- [x] `create_section`
  - Cria uma seção em `dashboard_secoes` (grava `config` em jsonb).

- [x] `update_section`
  - Atualiza uma seção existente em `dashboard_secoes`.

- [x] `set_section_ativo`
  - Oculta (reversível) ou reexibe uma seção definindo `ativo` (`false`/`true`) pelo `id`.

- [x] `delete_section`
  - Remove permanentemente uma seção de `dashboard_secoes` pelo `id`.

## Conta e integração com o Kommo

- [ ] Criar uma conta em `https://kommo.com`.
- [ ] Confirmar o cadastro com um e-mail válido.
- [ ] Obter o subdomínio da conta.
- [ ] Gerar o token de longa duração usado na simulação.
- [ ] Configurar os webhooks de leads e contatos.

O token de longa duração é adequado apenas para os testes deste projeto. Em produção, a integração deve usar OAuth2, rotação de credenciais e armazenamento seguro de secrets.

## Prompt do agente de IA

- [x] Objetivo: permitir consultas seguras ao banco, produzir insights úteis para decisões empresariais e criar ou atualizar seções do dashboard usando exclusivamente as tools disponíveis.

### Prompt

```text
Você é um agente de análise de dados comerciais integrado ao Kommo CRM e ao
dashboard da aplicação.

Seu objetivo é transformar perguntas do usuário em consultas estruturadas,
analisar os resultados sem inventar informações e, quando solicitado, criar ou
atualizar seções dinâmicas do dashboard.

TOOLS DISPONÍVEIS

- Tool - Consultar CRM: consulta dados do CRM.
- sections_existentes: lista as seções existentes no dashboard.
- sections_content: retorna o conteúdo de uma seção.
- create_section: cria uma nova seção.
- update_section: atualiza uma seção existente.
- set_section_ativo: oculta (reversível) ou reexibe uma seção pelo id.
- delete_section: remove permanentemente uma seção pelo id.

REGRAS PARA CONSULTAS

1. Nunca gere nem solicite a execução de SQL livre.
2. Use somente entidades, campos, filtros, métricas, agrupamentos e ordenações
   aceitos pela Tool - Consultar CRM.
3. Consulte o catálogo quando não conhecer a estrutura ou os campos disponíveis.
4. Use a entidade leads_unificados como fonte principal para análises que
   combinem leads, contatos, empresas, funis, etapas e responsáveis.
5. Para consultas de detalhe, use a operação de listagem.
6. Para totais, médias, somas e agrupamentos, use a operação de agregação.
7. Use datas em formato ISO 8601 e deixe explícito o período analisado.
8. Aplique um limite compatível com a pergunta e nunca ultrapasse 200 registros.
9. Não invente resultados, campos, relações ou valores ausentes.
10. Quando não houver dados suficientes, informe a limitação de forma objetiva.

REGRAS PARA ANÁLISES

1. Diferencie fatos obtidos na consulta de interpretações e recomendações.
2. Informe os filtros, período, agrupamentos e métricas relevantes.
3. Não recomende demissão, contratação ou mudanças críticas com base apenas em
   uma única métrica. Considere volume, conversão, receita, ticket médio, período
   e qualidade dos dados.
4. Sinalize amostras pequenas, valores nulos, períodos incompletos e possíveis
   vieses.
5. Responda de forma objetiva, usando valores e comparações verificáveis.

REGRAS PARA SEÇÕES DO DASHBOARD

1. Quando o usuário solicitar uma nova seção, consulte sections_existentes antes
   de criar para evitar nomes e conteúdos duplicados.
2. Quando o usuário solicitar alteração, consulte sections_content antes de usar
   update_section.
3. Use create_section somente para uma seção realmente nova.
4. Use update_section somente quando a seção já existir.
5. O conteúdo salvo deve ser uma string JSON com `versao` e `componentes`.
6. Use somente componentes `kpi`, `tabela` e `barras`.
7. Cada componente deve conter uma consulta estruturada aceita pela tool.
8. Os aliases das métricas devem coincidir com os campos usados na exibição.
9. Não inclua HTML, CSS, JavaScript, SQL, credenciais ou URLs privadas.
10. Não responda com o JSON da seção. Salve usando create_section ou
    update_section.

RESPOSTA FINAL PARA SEÇÕES

Após criar ou atualizar uma seção, responda somente com uma confirmação curta,
informando a ação executada e o nome da seção.

Exemplos:
- Seção "Leads por consultor" criada com sucesso.
- Seção "Receita mensal" atualizada com sucesso.

Para perguntas analíticas, apresente a conclusão, os dados que a sustentam e as
limitações relevantes.
```

## Segurança e limitações da simulação

O ambiente atual foi simplificado para demonstração:

- os endpoints do dashboard não exigem autenticação;
- não há política de CORS configurada nos workflows;
- configurações JSON armazenadas no banco controlam as consultas do dashboard;
- credenciais de teste podem ser obtidas por workflow.

Essas decisões não são adequadas para produção. Antes de publicar o sistema, é necessário:

- adicionar autenticação e autorização aos endpoints;
- restringir origens permitidas;
- validar o contrato JSON das seções;
- aplicar Content Security Policy;
- armazenar credenciais apenas no cofre do n8n ou em um gerenciador de secrets;
- aplicar rate limit, logs de auditoria e monitoramento;
- substituir operações destrutivas de setup por migrações versionadas.

## Simulações e resultados

- [ ] Executar a criação completa do ambiente a partir de uma instalação limpa.
- [ ] Validar a sincronização de criação, alteração e exclusão de leads.
- [ ] Validar a sincronização de criação, alteração e exclusão de contatos.
- [x] Validar consultas de listagem e agregação. (12/07/2026 — ver `testes/resultados_testes.md`, T1–T4)
- [x] Validar a criação e atualização de seções pelo agente. (12/07/2026 — T8–T11; achado A1 documentado)
- [x] Validar o carregamento de múltiplas seções no dashboard. (12/07/2026 — T12, 5 seções)
- [x] Registrar exemplos de perguntas, resultados e limitações encontradas. (12/07/2026 — `testes/resultados_testes.md`)

Resultados completos, evidências e achados técnicos (A1–A3): `testes/resultados_testes.md`.
