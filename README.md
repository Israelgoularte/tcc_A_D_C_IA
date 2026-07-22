# Análise de Dados com IA

Modelo de análise de dados comerciais com inteligência artificial, integrando
**n8n**, **Kommo CRM** e **PostgreSQL**. O sistema recebe eventos de leads e
contatos do Kommo, persiste os dados de forma estruturada, permite que um agente
de IA consulte e analise as informações e gera dashboards dinâmicos para apoiar a
tomada de decisão.

## Empresa de simulação — Company IG

Empresa fictícia que vende desenvolvimento de software sob demanda, capta leads
por tráfego pago (Meta e Google) e conta com 10 vendedores. O CRM Kommo é
estruturado para esse cenário. Em `infra/crm_kommo` ficam os arquivos JSON com a
configuração mínima usada nos testes, e em `infra/dados_ficticios` a base de
clientes fictícios para importação.

## Estrutura do repositório

- `infra/n8n` — stack Docker (Traefik, PostgreSQL, n8n), scripts de operação e os
  workflows (setup, integração Kommo, agente de IA e dashboard).
- `infra/dados_ficticios` — DDL do schema `analise_dados`, dados fictícios e
  migrações SQL.
- `infra/crm_kommo` — configuração do Kommo e instruções de credenciais.
- `projeto.md` — documentação detalhada da arquitetura, banco de dados,
  workflows, prompt do agente e considerações de segurança.

## Instalação

1. Siga o passo a passo de instalação do servidor em `infra/n8n/README.md`.
2. Após a instalação, acesse a URL e crie o usuário administrador.
3. Faça login, vá em Settings > Usage and Plan e solicite o Unlock. Um código
   será enviado ao e-mail informado para ativar a licença e liberar recursos
   extras do n8n.
4. Importe os workflows (o `infra/n8n/scripts/import-workflows.sh` faz isso
   automaticamente durante o setup e as atualizações).

## Banco de dados

O schema `analise_dados` é criado pelo DDL em
`infra/dados_ficticios/kommo_schema.sql` (ou pelos workflows de setup). As
seções do dashboard ficam na tabela `dashboard_secoes` (campo `config` em
`jsonb`). Para bases já existentes, há migrações incrementais em
`infra/dados_ficticios/migrations`.

## Dashboard

Três workflows com responsabilidades separadas:

- **Pagina DashBoard** — serve a página HTML completa.
- **API - Sections Dash** — retorna as instruções (JSON) de como montar as
  seções, a partir de `dashboard_secoes`.
- **API - Dados Dashboard** — retorna os dados de cada componente via
  `Tool - Consultar CRM`.

Detalhes do contrato e dos componentes em `infra/n8n/workflows/dashboard/README.md`.

## Agente de IA

Assistente de análise e apoio à decisão. Responde perguntas sobre os dados do
CRM (somente leitura, sem SQL livre) e, quando solicitado, cria, atualiza, oculta
ou remove seções do dashboard usando exclusivamente as tools disponíveis. O
prompt e as regras estão documentados em `projeto.md`.

## Segurança

O ambiente é uma simulação: os endpoints do dashboard não exigem autenticação e
as credenciais de teste são simplificadas. As medidas necessárias para produção
estão listadas em `projeto.md`.
