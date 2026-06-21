#!/usr/bin/env bash

# Funcoes compartilhadas pelos scripts setup.sh e update.sh.
# Este arquivo deve ser carregado com source.

remote_fail() {
  echo "Erro: $*" >&2
  exit 1
}

read_script_env_value() {
  local env_file="$1"
  local key="$2"
  local value

  value="$(
    grep -E "^[[:space:]]*${key}=" "${env_file}" |
      tail -n 1 |
      sed -E "s/^[[:space:]]*${key}=//" || true
  )"

  value="${value%$'\r'}"

  if [[ "${value}" == \"*\" && "${value}" == *\" ]]; then
    value="${value:1:${#value}-2}"
  elif [[ "${value}" == \'*\' && "${value}" == *\' ]]; then
    value="${value:1:${#value}-2}"
  fi

  printf '%s' "${value}"
}

load_execution_config() {
  local script_env_file="${SCRIPT_DIR}/.env"

  EXECUTION_MODE="local"
  SSH_HOST=""
  SSH_USER=""
  SSH_PORT="22"
  SSH_PASSWORD=""
  SSH_PRIVATE_KEY=""
  SSH_STRICT_HOST_KEY_CHECKING="accept-new"
  REMOTE_PATH="n8n-stack"

  if [[ -f "${script_env_file}" ]]; then
    EXECUTION_MODE="$(read_script_env_value "${script_env_file}" "EXECUTION_MODE")"
    SSH_HOST="$(read_script_env_value "${script_env_file}" "SSH_HOST")"
    SSH_USER="$(read_script_env_value "${script_env_file}" "SSH_USER")"
    SSH_PORT="$(read_script_env_value "${script_env_file}" "SSH_PORT")"
    SSH_PASSWORD="$(read_script_env_value "${script_env_file}" "SSH_PASSWORD")"
    SSH_PRIVATE_KEY="$(read_script_env_value "${script_env_file}" "SSH_PRIVATE_KEY")"
    SSH_STRICT_HOST_KEY_CHECKING="$(read_script_env_value "${script_env_file}" "SSH_STRICT_HOST_KEY_CHECKING")"
    REMOTE_PATH="$(read_script_env_value "${script_env_file}" "REMOTE_PATH")"
  fi

  EXECUTION_MODE="${EXECUTION_MODE:-local}"
  SSH_PORT="${SSH_PORT:-22}"
  SSH_STRICT_HOST_KEY_CHECKING="${SSH_STRICT_HOST_KEY_CHECKING:-accept-new}"
  REMOTE_PATH="${REMOTE_PATH:-n8n-stack}"
}

should_execute_remotely() {
  [[ "${EXECUTION_MODE}" == "ssh" ]]
}

validate_remote_config() {
  [[ -n "${SSH_HOST}" ]] || remote_fail "SSH_HOST nao foi definido em scripts/.env."
  [[ -n "${SSH_USER}" ]] || remote_fail "SSH_USER nao foi definido em scripts/.env."
  [[ "${SSH_PORT}" =~ ^[0-9]+$ ]] || remote_fail "SSH_PORT deve ser numerico."
  [[ "${SSH_STRICT_HOST_KEY_CHECKING}" =~ ^(true|false|accept-new)$ ]] ||
    remote_fail "SSH_STRICT_HOST_KEY_CHECKING deve ser true, false ou accept-new."
  [[ "${REMOTE_PATH}" =~ ^[A-Za-z0-9._/-]+$ ]] ||
    remote_fail "REMOTE_PATH contem caracteres nao permitidos."
  [[ "${REMOTE_PATH}" != /* ]] ||
    remote_fail "REMOTE_PATH deve ser relativo ao diretorio pessoal do usuario SSH."
  [[ "${REMOTE_PATH}" != *".."* ]] ||
    remote_fail "REMOTE_PATH nao pode conter '..'."

  if [[ -n "${SSH_PRIVATE_KEY}" ]]; then
    [[ -f "${SSH_PRIVATE_KEY}" ]] ||
      remote_fail "Chave SSH nao encontrada: ${SSH_PRIVATE_KEY}"
  fi

  command -v ssh >/dev/null 2>&1 || remote_fail "comando ssh nao encontrado."
  command -v tar >/dev/null 2>&1 || remote_fail "comando tar nao encontrado."

  if [[ -n "${SSH_PASSWORD}" ]]; then
    command -v sshpass >/dev/null 2>&1 ||
      remote_fail "SSH_PASSWORD foi configurado, mas sshpass nao esta instalado. Instale com: sudo apt-get install -y sshpass"
  fi
}

build_ssh_command() {
  SSH_CONTROL_PATH="/tmp/n8n-ssh-%C"

  if [[ -n "${SSH_PASSWORD}" ]]; then
    export SSHPASS="${SSH_PASSWORD}"
    SSH_COMMAND=(sshpass -e ssh)
  else
    SSH_COMMAND=(ssh)
  fi

  SSH_COMMAND+=(
    -p "${SSH_PORT}"
    -o ControlMaster=auto
    -o ControlPersist=120
    -o "ControlPath=${SSH_CONTROL_PATH}"
  )

  if [[ -n "${SSH_PRIVATE_KEY}" ]]; then
    SSH_COMMAND+=(-i "${SSH_PRIVATE_KEY}")
  fi

  case "${SSH_STRICT_HOST_KEY_CHECKING}" in
    true)
      SSH_COMMAND+=(-o StrictHostKeyChecking=yes)
      ;;
    accept-new)
      SSH_COMMAND+=(-o StrictHostKeyChecking=accept-new)
      ;;
    false)
      SSH_COMMAND+=(
        -o StrictHostKeyChecking=no
        -o UserKnownHostsFile=/dev/null
      )
      ;;
  esac

  SSH_TARGET="${SSH_USER}@${SSH_HOST}"
}

close_ssh_connection() {
  if [[ "${SSH_CONNECTION_OPEN:-false}" != "true" ]]; then
    return
  fi

  "${SSH_COMMAND[@]}" -O exit "${SSH_TARGET}" >/dev/null 2>&1 || true
  SSH_CONNECTION_OPEN=false
  unset SSHPASS
}

upload_stack() {
  local remote_path_quoted

  printf -v remote_path_quoted '%q' "${REMOTE_PATH}"

  echo "Conectando e sincronizando infra/n8n com ${SSH_USER}@${SSH_HOST}:${SSH_PORT}..."

  if ! tar \
    --exclude='./.env' \
    --exclude='./scripts/.env' \
    --exclude='./backups' \
    -czf - \
    -C "${N8N_DIR}" . |
    "${SSH_COMMAND[@]}" "${SSH_TARGET}" \
      "command -v bash >/dev/null &&
       command -v tar >/dev/null &&
       mkdir -p ${remote_path_quoted} &&
       tar -xzf - -C ${remote_path_quoted}"; then
    remote_fail "falha ao conectar ou sincronizar os arquivos com o servidor remoto."
  fi

  SSH_CONNECTION_OPEN=true
}

execute_remote_script() {
  local script_name="$1"
  shift

  local remote_path_quoted
  local remote_command
  local argument
  local argument_quoted

  printf -v remote_path_quoted '%q' "${REMOTE_PATH}"
  remote_command="cd ${remote_path_quoted} && bash scripts/${script_name} --local"

  for argument in "$@"; do
    printf -v argument_quoted '%q' "${argument}"
    remote_command+=" ${argument_quoted}"
  done

  echo "Executando ${script_name} no servidor remoto..."
  "${SSH_COMMAND[@]}" -t "${SSH_TARGET}" "${remote_command}"
}

run_remote_operation() {
  local script_name="$1"
  shift

  validate_remote_config
  build_ssh_command
  SSH_CONNECTION_OPEN=false
  trap close_ssh_connection EXIT

  upload_stack
  execute_remote_script "${script_name}" "$@"

  close_ssh_connection
  trap - EXIT
}
