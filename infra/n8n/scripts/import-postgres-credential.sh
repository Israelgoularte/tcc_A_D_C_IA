#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "Erro: $*" >&2
  exit 1
}

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

resolve_docker_cmd() {
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    DOCKER_CMD=(docker)
    return
  fi

  if command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
    DOCKER_CMD=(sudo docker)
    return
  fi

  fail "Docker nao esta disponivel ou o daemon nao esta acessivel."
}

read_env_value() {
  local env_file="$1"
  local key="$2"
  local value

  value="$(grep -E "^${key}=" "${env_file}" | tail -n 1 | cut -d '=' -f 2- || true)"
  printf '%s' "${value}"
}

load_env() {
  local env_file="$1"

  [[ -f "${env_file}" ]] || fail "arquivo .env nao encontrado em ${env_file}."

  POSTGRES_DB="$(read_env_value "${env_file}" "POSTGRES_DB")"
  POSTGRES_USER="$(read_env_value "${env_file}" "POSTGRES_USER")"
  POSTGRES_PASSWORD="$(read_env_value "${env_file}" "POSTGRES_PASSWORD")"
  POSTGRES_CREDENTIAL_ID="$(read_env_value "${env_file}" "POSTGRES_CREDENTIAL_ID")"
  POSTGRES_CREDENTIAL_NAME="$(read_env_value "${env_file}" "POSTGRES_CREDENTIAL_NAME")"

  : "${POSTGRES_DB:?POSTGRES_DB nao definido no .env}"
  : "${POSTGRES_USER:?POSTGRES_USER nao definido no .env}"
  : "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD nao definido no .env}"
  POSTGRES_CREDENTIAL_ID="${POSTGRES_CREDENTIAL_ID:-75T88sJeS9BfaHBO}"
  POSTGRES_CREDENTIAL_NAME="${POSTGRES_CREDENTIAL_NAME:-Postgres n8n}"
}

wait_for_n8n() {
  echo "Aguardando o n8n ficar disponivel..."

  for _ in $(seq 1 30); do
    if "${DOCKER_CMD[@]}" compose exec -T n8n node -e "fetch('http://127.0.0.1:5678/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))" >/dev/null 2>&1; then
      return
    fi

    sleep 5
  done

  fail "n8n nao ficou disponivel a tempo. Verifique os logs com: ${DOCKER_CMD[*]} compose logs -f n8n"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
N8N_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${N8N_DIR}/.env"
DOCKER_CMD=(docker)

cd "${N8N_DIR}"
resolve_docker_cmd
load_env "${ENV_FILE}"
wait_for_n8n

tmp_file="$(mktemp)"
container_file="/tmp/n8n-postgres-credential.json"

chmod 600 "${tmp_file}"
cat > "${tmp_file}" <<EOF
[
  {
    "name": "$(json_escape "${POSTGRES_CREDENTIAL_NAME}")",
    "id": "$(json_escape "${POSTGRES_CREDENTIAL_ID}")",
    "type": "postgres",
    "data": {
      "host": "postgres",
      "port": 5432,
      "database": "$(json_escape "${POSTGRES_DB}")",
      "user": "$(json_escape "${POSTGRES_USER}")",
      "password": "$(json_escape "${POSTGRES_PASSWORD}")",
      "ssl": "disable",
      "schema": "public"
    }
  }
]
EOF

"${DOCKER_CMD[@]}" compose exec -T n8n sh -lc "cat > '${container_file}' && n8n import:credentials --input='${container_file}' && rm -f '${container_file}'" < "${tmp_file}"
rm -f "${tmp_file}"

echo "Credencial PostgreSQL importada no n8n com o nome: ${POSTGRES_CREDENTIAL_NAME}"
