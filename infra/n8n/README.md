# n8n com PostgreSQL

Infraestrutura Docker para executar uma instancia do n8n com banco PostgreSQL persistente e roteamento via Traefik.

## Requisitos no Ubuntu

- Ubuntu 22.04 ou superior
- Git instalado
- Docker instalado
- Docker Compose instalado
- Traefik ja configurado na maquina ou servidor
- Rede externa do Traefik disponivel

## Instalacao

Atualize os pacotes e instale o Git, se necessario:

```bash
sudo apt update
sudo apt install -y git
```

Clone o repositorio:

```bash
git clone https://github.com/Israelgoularte/tcc_A_D_C_IA.git
cd tcc_A_D_C_IA/infra/n8n
```

### Instalacao guiada

Execute o setup interativo:

```bash
chmod +x scripts/setup.sh
bash scripts/setup.sh
```

O setup:

- mostra as informacoes de autoria e proposito do projeto
- valida se o sistema e Ubuntu
- verifica e instala requisitos quando necessario
- pede confirmacao antes de instalar pacotes ou configurar Docker
- instala `git`, `curl`, `ca-certificates`, `gnupg`, `openssl`, Docker Engine e Docker Compose plugin
- solicita os dados necessarios no terminal
- gera a `N8N_ENCRYPTION_KEY`
- cria o `.env`
- verifica a rede do Traefik
- pergunta se deve subir os containers
- importa automaticamente uma credencial PostgreSQL no n8n para os workflows acessarem o banco

### Como responder as perguntas do setup

Quando aparecer uma pergunta com valor entre colchetes, esse e o valor padrao. Para aceitar o padrao, pressione `Enter`.

Exemplo:

```text
Tag da imagem PostgreSQL [16-alpine]:
```

Nesse caso, pressione `Enter` para usar `16-alpine`.

| Pergunta | O que informar | Recomendado |
| --- | --- | --- |
| `Tag da imagem PostgreSQL [16-alpine]` | Versao da imagem Docker do PostgreSQL. | Pressione `Enter`. |
| `Nome do banco PostgreSQL [n8n]` | Nome do banco usado pelo n8n. | Pressione `Enter`. |
| `Usuario PostgreSQL [n8n]` | Usuario do banco PostgreSQL. | Pressione `Enter`. |
| `Senha PostgreSQL` | Senha do banco. Se pressionar `Enter`, o setup gera uma senha automaticamente. | Pressione `Enter` ou informe uma senha forte. |
| `Nome da credencial PostgreSQL no n8n [Postgres n8n]` | Nome da credencial criada dentro do n8n para uso nos workflows. | Pressione `Enter`. |
| `Versao fixa do n8n [2.22.5]` | Versao da imagem Docker do n8n. | Pressione `Enter`. |
| `Dominio do n8n` | Dominio publico que apontara para o n8n. | Exemplo: `n8n.seu-dominio.com`. |
| `Protocolo publico [https]` | Protocolo usado no acesso externo. | Pressione `Enter` se usar Traefik com HTTPS. |
| `Timezone [America/Sao_Paulo]` | Fuso horario da instancia. | Pressione `Enter`. |
| `Usar cookie seguro no n8n [true]` | Mantem cookies seguros para HTTPS. | Pressione `Enter`. |
| `Habilitar metricas do n8n [true]` | Habilita endpoint de metricas. | Pressione `Enter`. |
| `Habilitar diagnosticos do n8n [false]` | Envio de diagnosticos/telemetria. | Pressione `Enter`. |
| `Habilitar personalizacao do n8n [false]` | Personalizacao/telemetria de experiencia. | Pressione `Enter`. |
| `Rede externa do Traefik [traefik_proxy]` | Nome da rede Docker usada pelo Traefik. | Pressione `Enter`, salvo se seu Traefik usa outro nome. |
| `Cert resolver do Traefik [mytlschallenge]` | Nome do resolver TLS configurado no Traefik. | Use o nome configurado no seu Traefik. |

Exemplo de preenchimento comum:

```text
Tag da imagem PostgreSQL [16-alpine]: Enter
Nome do banco PostgreSQL [n8n]: Enter
Usuario PostgreSQL [n8n]: Enter
Senha PostgreSQL: Enter
Nome da credencial PostgreSQL no n8n [Postgres n8n]: Enter
Versao fixa do n8n [2.22.5]: Enter
Dominio do n8n, exemplo n8n.seu-dominio.com: n8n.meudominio.com
Protocolo publico [https]: Enter
Timezone [America/Sao_Paulo]: Enter
Usar cookie seguro no n8n [true]: Enter
Habilitar metricas do n8n [true]: Enter
Habilitar diagnosticos do n8n [false]: Enter
Habilitar personalizacao do n8n [false]: Enter
Rede externa do Traefik [traefik_proxy]: Enter
Cert resolver do Traefik [mytlschallenge]: Enter
```

Ao final, o setup mostra um resumo e pergunta se pode criar o `.env`. Depois pergunta se deve criar a rede do Traefik, quando ela nao existir, e se deve subir os containers.

Quando os containers sobem pelo setup, ele tambem pergunta se deve cadastrar automaticamente a credencial PostgreSQL dentro do n8n. Aceite essa etapa para evitar o cadastro manual da conexao nos workflows.

### Limpeza para recomecar do zero

Execute o script de limpeza:

```bash
chmod +x scripts/cleanup.sh
bash scripts/cleanup.sh
```

Esse script remove containers, rede interna e volumes da stack, incluindo os dados do PostgreSQL e do n8n. Ele pede confirmacao digitando `LIMPAR` antes da remocao e tambem pergunta separadamente se deve remover `.env`, rede externa do Traefik e imagens Docker nao utilizadas.

### Instalacao manual

Crie o arquivo de ambiente:

```bash
cp .env.exemple .env
```

Gere automaticamente a chave de criptografia do n8n:

```bash
chmod +x scripts/generate-encryption-key.sh
bash scripts/generate-encryption-key.sh
```

Edite o arquivo `.env` antes de subir os containers:

```bash
nano .env
```

Valores minimos que devem ser ajustados:

```env
POSTGRES_PASSWORD=troque_por_uma_senha_forte
N8N_DOMAIN=n8n.seu-dominio.com
N8N_HOST=n8n.seu-dominio.com
WEBHOOK_URL=https://n8n.seu-dominio.com/
```

Garanta que a rede externa do Traefik exista:

```bash
docker network create traefik_proxy
```

Se a rede ja existir, o Docker retornara erro informando que ela ja existe. Nesse caso, pode seguir normalmente.

Suba os containers:

```bash
docker compose up -d
```

Verifique o status:

```bash
docker compose ps
docker compose logs -f n8n
```

## Acesso

O acesso ao n8n deve ser feito pelo dominio configurado em `N8N_DOMAIN`.

Exemplo:

```text
https://n8n.seu-dominio.com
```

## Versoes fixadas

O n8n esta fixado na versao `2.22.5` por meio da variavel:

```env
N8N_IMAGE_TAG=2.22.5
```

Isso evita atualizacoes automaticas quando os containers forem recriados.

## Comandos uteis

Parar os containers:

```bash
docker compose down
```

Atualizar somente depois de alterar conscientemente a versao em `.env`:

```bash
docker compose pull
docker compose up -d
```

Reiniciar os containers:

```bash
docker compose restart
```

Ver logs do PostgreSQL:

```bash
docker compose logs -f postgres
```

Backup simples dos volumes Docker deve ser planejado antes de uso em producao, principalmente para:

- `postgres_data`
- `n8n_data`

## Cuidados

- Nao versione o arquivo `.env`.
- Nao altere `N8N_ENCRYPTION_KEY` depois de criar credenciais no n8n, pois isso pode impedir a leitura das credenciais salvas.
- Mantenha `POSTGRES_PASSWORD` e `N8N_ENCRYPTION_KEY` fora de logs, prints e commits.
- Antes de atualizar o n8n, teste em ambiente separado e leia as notas de release.
