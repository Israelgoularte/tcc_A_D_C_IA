# Uso recomendado.

---

## Credenciais Kommo
- importe o Workflow [kommo_credenciais](kommo/kommo_credenciais.json) para o n8n e edite o Node "acesso_kommo" com o subdomain do kommo e o token de acesso obtido pelo processo documentado em [como obter o token de longa duração](../../crm_kommo/criando_credenciais/readme.md). O Subdomain você consegue coleta na URL do CRM Kommo, apos ter efetuado o login e so coleta oque tiver em [subdomai].kommo.com ( exemplo de url https://exemplo.kommo.com nesse caso o subdomain = exemplo).

- Esse Workflow sera responsavel por retornar internamente para outros workflows os dados para consumir a api do Kommo CRm.

---

## Criar Tabelas Iniciais no Banco de Dados
- Importar o workflow [Criar tabelas](banco_de_dados/Criar_tabelas.json) e depois executar o mesmo, ele vai criar as tabelas minimas necessarias para os testes que vamos executar. 

---

## Configurar o CRM
- Importar o workflow [criar_estrutura](kommo/kommo_criar_estrutura.json) esse workflow sera preciso definir o dominio do email no local indicado com nota, e caso queira fazer outra estrutura de testes basta alter o objeto json do local indicado no workflow. 

- Ao final e so executar o workflow.

---

