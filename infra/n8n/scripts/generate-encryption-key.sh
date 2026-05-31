#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
N8N_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${N8N_DIR}/.env"
ENV_EXAMPLE_FILE="${N8N_DIR}/.env.exemple"

if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ ! -f "${ENV_EXAMPLE_FILE}" ]]; then
    echo "Arquivo .env nao encontrado e .env.exemple tambem nao existe." >&2
    exit 1
  fi

  cp "${ENV_EXAMPLE_FILE}" "${ENV_FILE}"
  chmod 600 "${ENV_FILE}"
fi

ENCRYPTION_KEY="$(openssl rand -hex 32)"

if grep -q '^N8N_ENCRYPTION_KEY=' "${ENV_FILE}"; then
  sed -i "s/^N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY}/" "${ENV_FILE}"
else
  printf '\nN8N_ENCRYPTION_KEY=%s\n' "${ENCRYPTION_KEY}" >> "${ENV_FILE}"
fi

chmod 600 "${ENV_FILE}"

echo "N8N_ENCRYPTION_KEY gerada e salva em ${ENV_FILE}."
echo "Guarde esse arquivo com seguranca. Nao altere essa chave depois de criar credenciais no n8n."
