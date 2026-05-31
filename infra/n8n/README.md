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
