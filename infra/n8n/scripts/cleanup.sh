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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
N8N_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${N8N_DIR}/.env"
DOCKER_CMD=(docker)

cat <<'EOF'
============================================================
Limpeza n8n + PostgreSQL
============================================================

Este script remove a instalacao Docker desta stack para permitir
comecar novamente do zero.

Serao removidos:
- containers da stack
- rede interna criada pelo docker compose
- volumes Docker da stack, incluindo dados do PostgreSQL e do n8n

Opcionalmente, tambem pode remover:
- arquivo .env
- imagens Docker nao utilizadas

Atencao: os dados removidos dos volumes nao serao recuperados.
============================================================
EOF

cd "${N8N_DIR}"
resolve_docker_cmd

echo
echo "Diretorio da stack: ${N8N_DIR}"
echo
read -r -p "Digite LIMPAR para confirmar a remocao dos containers e volumes: " confirmation

if [[ "${confirmation}" != "LIMPAR" ]]; then
  echo "Limpeza cancelada."
  exit 0
fi

"${DOCKER_CMD[@]}" compose down -v --remove-orphans
echo "Containers, rede interna e volumes da stack foram removidos."

if [[ -f "${ENV_FILE}" ]] && confirm "Deseja remover o arquivo .env?" "n"; then
  rm -f "${ENV_FILE}"
  echo ".env removido."
fi

if confirm "Deseja remover imagens Docker nao utilizadas com docker image prune -a?" "n"; then
  "${DOCKER_CMD[@]}" image prune -a
fi

echo
echo "Limpeza concluida. O repositorio clonado foi mantido para permitir uma nova instalacao."
