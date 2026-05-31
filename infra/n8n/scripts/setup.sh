#!/usr/bin/env bash
set -euo pipefail

print_intro() {
  cat <<'EOF'
============================================================
Setup n8n + PostgreSQL
============================================================

Criado por: Israel Goularte

Proposito:
Este setup foi criado para demonstrar, de forma pratica, as
vantagens da analise de dados com inteligencia artificial e o
potencial de ferramentas no-code para acelerar, organizar e
otimizar processos de analise.

Projeto original:
https://github.com/Israelgoularte/tcc_A_D_C_IA.git

============================================================
EOF
}

fail() {
  echo "Erro: $*" >&2
  exit 1
}

prompt_default() {
  local label="$1"
  local default_value="$2"
  local value

  read -r -p "${label} [${default_value}]: " value
  printf '%s' "${value:-$default_value}"
}

prompt_required() {
  local label="$1"
  local value=""

  while [[ -z "${value}" ]]; do
    read -r -p "${label}: " value
    if [[ -z "${value}" ]]; then
      echo "Valor obrigatorio." >&2
    fi
  done

  printf '%s' "${value}"
}

prompt_secret_or_generate() {
  local label="$1"
  local value=""

  read -r -s -p "${label} (pressione Enter para gerar automaticamente): " value
  echo >&2

  if [[ -z "${value}" ]]; then
    openssl rand -hex 24
  else
    printf '%s' "${value}"
  fi
}

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

confirm() {
  local label="$1"
  local default_value="${2:-n}"
  local answer
  local hint="[s/N]"

  if [[ "${default_value}" == "s" ]]; then
    hint="[S/n]"
  fi

  read -r -p "${label} ${hint}: " answer
  answer="${answer:-$default_value}"

  [[ "${answer}" == "s" || "${answer}" == "S" ]]
}

sudo_cmd() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

validate_ubuntu() {
  [[ -f /etc/os-release ]] || fail "nao foi possivel identificar o sistema operacional."

  # shellcheck disable=SC1091
  . /etc/os-release

  if [[ "${ID:-}" != "ubuntu" ]]; then
    fail "este setup foi preparado para Ubuntu. Sistema detectado: ${PRETTY_NAME:-desconhecido}."
  fi
}

install_base_packages() {
  echo "Instalando pacotes basicos: git, curl, ca-certificates, gnupg e openssl..."
  sudo_cmd apt-get update
  sudo_cmd apt-get install -y git curl ca-certificates gnupg openssl
}

configure_docker_repository() {
  # shellcheck disable=SC1091
  . /etc/os-release

  local codename="${VERSION_CODENAME:-}"
  [[ -n "${codename}" ]] || fail "nao foi possivel identificar VERSION_CODENAME do Ubuntu."

  echo "Configurando repositorio oficial do Docker para Ubuntu ${codename}..."
  sudo_cmd install -m 0755 -d /etc/apt/keyrings
  sudo_cmd curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo_cmd chmod a+r /etc/apt/keyrings/docker.asc

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable" |
    sudo_cmd tee /etc/apt/sources.list.d/docker.list >/dev/null
}

install_docker_packages() {
  echo "Instalando Docker Engine, Buildx e Docker Compose plugin..."
  configure_docker_repository
  sudo_cmd apt-get update
  sudo_cmd apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo_cmd systemctl enable --now docker >/dev/null 2>&1 || true
}

docker_available() {
  command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1
}

resolve_docker_cmd() {
  if docker info >/dev/null 2>&1; then
    DOCKER_CMD=(docker)
    return
  fi

  if sudo docker info >/dev/null 2>&1; then
    DOCKER_CMD=(sudo docker)
    return
  fi

  fail "Docker foi instalado, mas o daemon nao esta acessivel."
}

ensure_requirements() {
  validate_ubuntu

  local missing=()
  command -v git >/dev/null 2>&1 || missing+=("git")
  command -v curl >/dev/null 2>&1 || missing+=("curl")
  command -v openssl >/dev/null 2>&1 || missing+=("openssl")

  if ! command -v docker >/dev/null 2>&1; then
    missing+=("docker")
  elif ! docker compose version >/dev/null 2>&1; then
    missing+=("docker-compose-plugin")
  fi

  if [[ "${#missing[@]}" -eq 0 ]]; then
    echo "Requisitos ja instalados."
    resolve_docker_cmd
    return
  fi

  echo "O setup precisa instalar ou configurar os seguintes requisitos:"
  printf '- %s\n' "${missing[@]}"
  echo
  echo "Serao executadas acoes com sudo usando apt e, se necessario, o repositorio oficial do Docker:"
  echo "- atualizar indice de pacotes"
  echo "- instalar git, curl, ca-certificates, gnupg e openssl"
  echo "- configurar o repositorio oficial do Docker"
  echo "- instalar docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin e docker-compose-plugin"
  echo "- habilitar/iniciar o servico Docker"
  echo

  if ! confirm "Deseja continuar com a instalacao dos requisitos?" "s"; then
    echo "Instalacao cancelada pelo usuario antes de alterar o sistema."
    exit 0
  fi

  command -v sudo >/dev/null 2>&1 || [[ "${EUID}" -eq 0 ]] || fail "sudo nao esta instalado e o script nao esta rodando como root."

  install_base_packages

  if ! docker_available; then
    install_docker_packages
  fi

  docker_available || fail "Docker Compose plugin nao ficou disponivel apos a instalacao."
  resolve_docker_cmd
}

write_env_file() {
  local env_file="$1"

  umask 077
  cat > "${env_file}" <<EOF
POSTGRES_IMAGE_TAG=${POSTGRES_IMAGE_TAG}
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_CREDENTIAL_NAME=${POSTGRES_CREDENTIAL_NAME}

N8N_IMAGE_TAG=${N8N_IMAGE_TAG}
N8N_DOMAIN=${N8N_DOMAIN}
N8N_HOST=${N8N_DOMAIN}
N8N_PROTOCOL=${N8N_PROTOCOL}
WEBHOOK_URL=${N8N_PROTOCOL}://${N8N_DOMAIN}/
GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
N8N_SECURE_COOKIE=${N8N_SECURE_COOKIE}
N8N_METRICS=${N8N_METRICS}
N8N_DIAGNOSTICS_ENABLED=${N8N_DIAGNOSTICS_ENABLED}
N8N_PERSONALIZATION_ENABLED=${N8N_PERSONALIZATION_ENABLED}

TRAEFIK_NETWORK=${TRAEFIK_NETWORK}
TRAEFIK_CERT_RESOLVER=${TRAEFIK_CERT_RESOLVER}

N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
EOF

  chmod 600 "${env_file}"
}

wait_for_n8n() {
  echo "Aguardando o n8n ficar disponivel para importar credenciais..."

  for _ in $(seq 1 30); do
    if "${DOCKER_CMD[@]}" compose exec -T n8n node -e "fetch('http://127.0.0.1:5678/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))" >/dev/null 2>&1; then
      return
    fi

    sleep 5
  done

  fail "n8n nao ficou disponivel a tempo. Verifique os logs com: ${DOCKER_CMD[*]} compose logs -f n8n"
}

import_postgres_credential() {
  local container_id
  local tmp_file
  local container_file="/tmp/n8n-postgres-credential.json"

  if ! confirm "Deseja cadastrar automaticamente a credencial PostgreSQL dentro do n8n?" "s"; then
    echo "Credencial PostgreSQL nao importada. Sera necessario cadastrar manualmente no n8n."
    return
  fi

  wait_for_n8n

  container_id="$("${DOCKER_CMD[@]}" compose ps -q n8n)"
  [[ -n "${container_id}" ]] || fail "container do n8n nao encontrado."

  tmp_file="$(mktemp)"
  chmod 600 "${tmp_file}"

  cat > "${tmp_file}" <<EOF
[
  {
    "name": "$(json_escape "${POSTGRES_CREDENTIAL_NAME}")",
    "type": "postgres",
    "data": {
      "host": "postgres",
      "port": 5432,
      "database": "$(json_escape "${POSTGRES_DB}")",
      "user": "$(json_escape "${POSTGRES_USER}")",
      "password": "$(json_escape "${POSTGRES_PASSWORD}")",
      "ssl": "disable"
    }
  }
]
EOF

  "${DOCKER_CMD[@]}" cp "${tmp_file}" "${container_id}:${container_file}" >/dev/null
  rm -f "${tmp_file}"

  "${DOCKER_CMD[@]}" compose exec -T n8n n8n import:credentials --input="${container_file}"
  "${DOCKER_CMD[@]}" compose exec -T n8n rm -f "${container_file}" >/dev/null 2>&1 || true

  echo "Credencial PostgreSQL importada no n8n com o nome: ${POSTGRES_CREDENTIAL_NAME}"
}

print_intro

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
N8N_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${N8N_DIR}/.env"
DOCKER_CMD=(docker)

echo "Validando e instalando requisitos quando necessario..."
ensure_requirements

cd "${N8N_DIR}"

if [[ -f "${ENV_FILE}" ]]; then
  if ! confirm "O arquivo .env ja existe. Deseja sobrescrever?" "n"; then
    echo "Instalacao cancelada para preservar o .env existente."
    exit 0
  fi
fi

echo
echo "Informe os dados da instalacao."
echo

POSTGRES_IMAGE_TAG="$(prompt_default "Tag da imagem PostgreSQL" "16-alpine")"
POSTGRES_DB="$(prompt_default "Nome do banco PostgreSQL" "n8n")"
POSTGRES_USER="$(prompt_default "Usuario PostgreSQL" "n8n")"
POSTGRES_PASSWORD="$(prompt_secret_or_generate "Senha PostgreSQL")"
POSTGRES_CREDENTIAL_NAME="$(prompt_default "Nome da credencial PostgreSQL no n8n" "Postgres n8n")"

N8N_IMAGE_TAG="$(prompt_default "Versao fixa do n8n" "2.22.5")"
N8N_DOMAIN="$(prompt_required "Dominio do n8n, exemplo n8n.seu-dominio.com")"
N8N_PROTOCOL="$(prompt_default "Protocolo publico" "https")"
GENERIC_TIMEZONE="$(prompt_default "Timezone" "America/Sao_Paulo")"
N8N_SECURE_COOKIE="$(prompt_default "Usar cookie seguro no n8n" "true")"
N8N_METRICS="$(prompt_default "Habilitar metricas do n8n" "true")"
N8N_DIAGNOSTICS_ENABLED="$(prompt_default "Habilitar diagnosticos do n8n" "false")"
N8N_PERSONALIZATION_ENABLED="$(prompt_default "Habilitar personalizacao do n8n" "false")"
N8N_ENCRYPTION_KEY="$(openssl rand -hex 32)"

TRAEFIK_NETWORK="$(prompt_default "Rede externa do Traefik" "traefik_proxy")"
TRAEFIK_CERT_RESOLVER="$(prompt_default "Cert resolver do Traefik" "mytlschallenge")"

echo
echo "Resumo:"
echo "- Diretorio: ${N8N_DIR}"
echo "- Dominio n8n: ${N8N_PROTOCOL}://${N8N_DOMAIN}"
echo "- Versao n8n: ${N8N_IMAGE_TAG}"
echo "- Banco PostgreSQL: ${POSTGRES_DB}"
echo "- Usuario PostgreSQL: ${POSTGRES_USER}"
echo "- Credencial PostgreSQL no n8n: ${POSTGRES_CREDENTIAL_NAME}"
echo "- Rede Traefik: ${TRAEFIK_NETWORK}"
echo

if ! confirm "Confirmar criacao do .env com esses dados?" "s"; then
  echo "Instalacao cancelada. Nenhum arquivo foi alterado."
  exit 0
fi

write_env_file "${ENV_FILE}"
echo ".env criado com permissao 600."

if "${DOCKER_CMD[@]}" network inspect "${TRAEFIK_NETWORK}" >/dev/null 2>&1; then
  echo "Rede ${TRAEFIK_NETWORK} ja existe."
else
  if confirm "Rede ${TRAEFIK_NETWORK} nao existe. Deseja cria-la agora?" "s"; then
    "${DOCKER_CMD[@]}" network create "${TRAEFIK_NETWORK}" >/dev/null
    echo "Rede ${TRAEFIK_NETWORK} criada."
  else
    echo "Rede nao criada. O docker compose falhara se o Traefik nao tiver essa rede."
  fi
fi

if confirm "Deseja subir n8n e PostgreSQL agora?" "s"; then
  "${DOCKER_CMD[@]}" compose up -d
  echo
  "${DOCKER_CMD[@]}" compose ps
  echo
  import_postgres_credential
  echo
  echo "Instalacao concluida. Acesse: ${N8N_PROTOCOL}://${N8N_DOMAIN}"
else
  echo "Setup concluido. Para subir depois, execute:"
  echo "${DOCKER_CMD[*]} compose up -d"
  echo "Depois de subir os containers, cadastre a credencial PostgreSQL no n8n manualmente ou rode o setup novamente."
fi

echo
echo "Importante: nao altere N8N_ENCRYPTION_KEY depois de criar credenciais no n8n."
