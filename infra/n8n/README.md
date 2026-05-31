# n8n com PostgreSQL

Infraestrutura Docker para executar uma instancia do n8n com banco PostgreSQL persistente e roteamento via Traefik.

## Requisitos

- Git
- Docker
- Docker Compose
- Traefik ja configurado na maquina/servidor
- Rede externa do Traefik disponivel

## Instalacao

Clone o repositorio:

```powershell
git clone https://github.com/Israelgoularte/tcc_A_D_C_IA.git
cd tcc_A_D_C_IA\infra\n8n
```

Crie o arquivo de ambiente:

```powershell
Copy-Item .env.exemple .env
```

Edite o arquivo `.env` antes de subir os containers:

```env
POSTGRES_PASSWORD=troque_por_uma_senha_forte
N8N_ENCRYPTION_KEY=troque_por_uma_chave_forte_com_40_ou_mais_caracteres
N8N_DOMAIN=n8n.seu-dominio.com
N8N_HOST=n8n.seu-dominio.com
WEBHOOK_URL=https://n8n.seu-dominio.com/
```

Garanta que a rede externa do Traefik exista:

```powershell
docker network create traefik_proxy
```

Se a rede ja existir, o Docker retornara erro informando que ela ja existe. Nesse caso, pode seguir normalmente.

Suba os containers:

```powershell
docker compose up -d
```

Verifique o status:

```powershell
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

```powershell
docker compose down
```

Atualizar somente depois de alterar conscientemente a versao em `.env`:

```powershell
docker compose pull
docker compose up -d
```

Backup simples dos volumes Docker deve ser planejado antes de uso em producao, principalmente para:

- `postgres_data`
- `n8n_data`

## Cuidados

- Nao versione o arquivo `.env`.
- Nao altere `N8N_ENCRYPTION_KEY` depois de criar credenciais no n8n, pois isso pode impedir a leitura das credenciais salvas.
- Mantenha `POSTGRES_PASSWORD` e `N8N_ENCRYPTION_KEY` fora de logs, prints e commits.
- Antes de atualizar o n8n, teste em ambiente separado e leia as notas de release.
