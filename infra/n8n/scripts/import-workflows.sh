#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "Erro: $*" >&2
  exit 1
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

wait_for_n8n() {
  echo "Aguardando o n8n ficar disponivel..."

  for _ in $(seq 1 30); do
    if "${DOCKER_CMD[@]}" compose exec -T n8n node -e \
      "fetch('http://127.0.0.1:5678/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))" \
      >/dev/null 2>&1; then
      return
    fi

    sleep 5
  done

  fail "n8n nao ficou disponivel a tempo."
}

list_workflows() {
  "${DOCKER_CMD[@]}" compose exec -T n8n node <<'NODE'
const fs = require('fs');
const path = require('path');

const root = '/workflows';
const files = [];

function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const fullPath = path.join(directory, entry.name);

    if (entry.isDirectory()) {
      walk(fullPath);
    } else if (entry.isFile() && entry.name.endsWith('.json')) {
      files.push(fullPath);
    }
  }
}

walk(root);

for (const file of files.sort()) {
  let workflow;

  try {
    workflow = JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    console.error(`JSON invalido ignorado: ${file}: ${error.message}`);
    continue;
  }

  const isWorkflow =
    workflow &&
    Array.isArray(workflow.nodes) &&
    workflow.connections &&
    typeof workflow.connections === 'object' &&
    typeof workflow.id === 'string' &&
    workflow.id.trim() !== '';

  if (!isWorkflow) {
    console.error(`Arquivo auxiliar ignorado: ${file}`);
    continue;
  }

  const fields = [
    file,
    workflow.id,
    workflow.active === true ? 'true' : 'false',
    String(workflow.name || path.basename(file))
  ];

  console.log(fields.map((value) =>
    Buffer.from(value, 'utf8').toString('base64')
  ).join('\t'));
}
NODE
}

decode_base64() {
  printf '%s' "$1" | base64 --decode
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
N8N_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCKER_CMD=(docker)

cd "${N8N_DIR}"
resolve_docker_cmd
wait_for_n8n

mapfile -t workflow_records < <(list_workflows)

if [[ "${#workflow_records[@]}" -eq 0 ]]; then
  fail "nenhum workflow valido foi encontrado em ${N8N_DIR}/workflows."
fi

declare -A workflow_ids=()
declare -a active_workflow_ids=()
imported_count=0

for record in "${workflow_records[@]}"; do
  IFS=$'\t' read -r file_b64 id_b64 active_b64 name_b64 <<< "${record}"

  workflow_file="$(decode_base64 "${file_b64}")"
  workflow_id="$(decode_base64 "${id_b64}")"
  workflow_active="$(decode_base64 "${active_b64}")"
  workflow_name="$(decode_base64 "${name_b64}")"

  if [[ -n "${workflow_ids[${workflow_id}]:-}" ]]; then
    fail "ID duplicado ${workflow_id}: ${workflow_ids[${workflow_id}]} e ${workflow_file}."
  fi

  workflow_ids["${workflow_id}"]="${workflow_file}"

  echo "Importando workflow: ${workflow_name}"
  "${DOCKER_CMD[@]}" compose exec -T n8n \
    n8n import:workflow --input="${workflow_file}"

  if [[ "${workflow_active}" == "true" ]]; then
    active_workflow_ids+=("${workflow_id}")
  fi

  imported_count=$((imported_count + 1))
done

for workflow_id in "${active_workflow_ids[@]}"; do
  echo "Publicando workflow ativo: ${workflow_id}"
  "${DOCKER_CMD[@]}" compose exec -T n8n \
    n8n publish:workflow --id="${workflow_id}"
done

# Os comandos de publicacao alteram diretamente o banco e exigem reinicio.
"${DOCKER_CMD[@]}" compose restart n8n
wait_for_n8n

echo "${imported_count} workflow(s) importado(s) recursivamente."
echo "${#active_workflow_ids[@]} workflow(s) publicado(s)."
