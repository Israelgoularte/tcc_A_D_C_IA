#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "Erro: $*" >&2
  exit 1
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

resolve_docker_cmd() {
  if command -v docker >/dev/null 2>&1 &&
    docker info >/dev/null 2>&1; then
    DOCKER_CMD=(docker)
    return
  fi

  if command -v sudo >/dev/null 2>&1 &&
    sudo docker info >/dev/null 2>&1; then
    DOCKER_CMD=(sudo docker)
    return
  fi

  fail "Docker nao esta disponivel ou o daemon nao esta acessivel."
}

validate_stack() {
  [[ -f "${ENV_FILE}" ]] ||
    fail "arquivo ${ENV_FILE} nao encontrado. Execute setup.sh primeiro."
  [[ -f "${N8N_DIR}/docker-compose.yml" ]] ||
    fail "docker-compose.yml nao encontrado."

  "${DOCKER_CMD[@]}" compose config --quiet
}

update_repository() {
  local repository_root

  command -v git >/dev/null 2>&1 || {
    echo "Git nao encontrado; os arquivos locais atuais serao utilizados."
    return
  }

  repository_root="$(git -C "${N8N_DIR}" rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -n "${repository_root}" ]] || return

  if [[ -n "$(git -C "${repository_root}" status --porcelain)" ]]; then
    echo "Repositorio possui alteracoes locais; git pull foi ignorado para nao sobrescreve-las."
    return
  fi

  if confirm "Deseja buscar a versao mais recente do repositorio?" "s"; then
    git -C "${repository_root}" pull --ff-only
  fi
}

backup_postgres() {
  local backup_dir="${N8N_DIR}/backups"
  local timestamp
  local backup_file

  if ! "${DOCKER_CMD[@]}" compose ps --status running postgres |
    grep -q "postgres"; then
    echo "PostgreSQL nao esta em execucao; backup automatico nao foi criado."
    return
  fi

  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  backup_file="${backup_dir}/postgres-${timestamp}.sql.gz"
  mkdir -p "${backup_dir}"
  chmod 700 "${backup_dir}"

  echo "Criando backup do PostgreSQL em ${backup_file}..."
  "${DOCKER_CMD[@]}" compose exec -T postgres sh -lc \
    'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --no-privileges' |
    gzip > "${backup_file}"

  [[ -s "${backup_file}" ]] || fail "o backup do PostgreSQL ficou vazio."
  chmod 600 "${backup_file}"
}

wait_for_service() {
  local service="$1"
  local attempts="${2:-30}"
  local container_id
  local status

  echo "Aguardando o servico ${service} ficar saudavel..."

  for _ in $(seq 1 "${attempts}"); do
    container_id="$("${DOCKER_CMD[@]}" compose ps -q "${service}")"

    if [[ -n "${container_id}" ]]; then
      status="$("${DOCKER_CMD[@]}" inspect \
        --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
        "${container_id}")"

      if [[ "${status}" == "healthy" || "${status}" == "running" ]]; then
        return
      fi

      if [[ "${status}" == "unhealthy" || "${status}" == "exited" ]]; then
        "${DOCKER_CMD[@]}" compose logs --tail 80 "${service}" >&2
        fail "o servico ${service} terminou com status ${status}."
      fi
    fi

    sleep 5
  done

  "${DOCKER_CMD[@]}" compose logs --tail 80 "${service}" >&2
  fail "timeout aguardando o servico ${service}."
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
N8N_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${N8N_DIR}/.env"
DOCKER_CMD=(docker)
SKIP_GIT_PULL=false

# shellcheck source=remote-execution.sh
source "${SCRIPT_DIR}/remote-execution.sh"

load_execution_config

if [[ "${1:-}" == "--local" ]]; then
  shift
elif should_execute_remotely; then
  run_remote_operation "update.sh" "--skip-git-pull" "$@"
  exit 0
elif [[ "${EXECUTION_MODE}" != "local" ]]; then
  remote_fail "EXECUTION_MODE deve ser local ou ssh."
fi

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --skip-git-pull)
      SKIP_GIT_PULL=true
      ;;
    *)
      fail "argumento desconhecido: $1"
      ;;
  esac
  shift
done

cat <<'EOF'
============================================================
Atualizacao n8n + PostgreSQL
============================================================

O processo valida a stack, cria um backup do PostgreSQL, baixa
as imagens configuradas e recria somente os containers necessarios.

O arquivo .env, os volumes e a N8N_ENCRYPTION_KEY sao preservados.
============================================================
EOF

cd "${N8N_DIR}"
resolve_docker_cmd

if [[ "${SKIP_GIT_PULL}" != "true" ]]; then
  update_repository
fi

validate_stack
backup_postgres

echo "Baixando imagens configuradas..."
"${DOCKER_CMD[@]}" compose pull

echo "Aplicando atualizacao..."
"${DOCKER_CMD[@]}" compose up -d --remove-orphans

wait_for_service "postgres"
wait_for_service "n8n"

echo
"${DOCKER_CMD[@]}" compose ps
echo
echo "Atualizacao concluida."
