#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[startup] %s\n' "$*"
}

ensure_user() {
  if ! id codex >/dev/null 2>&1; then
    useradd -m -s /bin/bash codex
  fi

  local password="${SSH_PASSWORD:-codex}"
  echo "codex:${password}" | chpasswd

  mkdir -p /home/codex/.ssh
  touch /home/codex/.ssh/authorized_keys
  chmod 700 /home/codex/.ssh
  chmod 600 /home/codex/.ssh/authorized_keys
  chown -R codex:codex /home/codex
}

configure_ssh() {
  mkdir -p /var/run/sshd

  cat >/etc/ssh/sshd_config <<'SSHEOF'
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin no
PasswordAuthentication yes
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
UsePAM yes
X11Forwarding no
PrintMotd no
Subsystem sftp /usr/lib/openssh/sftp-server
SSHEOF

  ssh-keygen -A >/dev/null 2>&1 || true
}

setup_shell_profile() {
  cat >/home/codex/.bashrc <<'BASHRC'
export OPENAI_BASE_URL="${OPENAI_BASE_URL:-http://127.0.0.1:11434/v1}"
export OPENAI_API_KEY="${OPENAI_API_KEY:-ollama}"
export LOCAL_MODEL="${LOCAL_MODEL:-qwen3-coder:30b}"
export PATH="$PATH:/usr/local/bin"
cd /workspace || true
BASHRC
  chown codex:codex /home/codex/.bashrc
}

start_ollama() {
  log "Starting Ollama server"
  ollama serve >/var/log/ollama.log 2>&1 &
  OLLAMA_PID=$!

  for _ in $(seq 1 60); do
    if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
      log "Ollama is healthy"
      return 0
    fi
    sleep 1
  done

  log "Ollama did not become ready in time"
  return 1
}

pull_model_if_enabled() {
  local model="${LOCAL_MODEL:-qwen3-coder:30b}"
  if [[ "${AUTO_PULL_MODEL:-true}" != "true" ]]; then
    log "Skipping model pull (AUTO_PULL_MODEL != true)"
    return
  fi

  log "Ensuring model is available: ${model}"
  if ollama show "$model" >/dev/null 2>&1; then
    log "Model already present"
    return
  fi

  nohup bash -lc "ollama pull '$model' >>/var/log/ollama-model-pull.log 2>&1" >/dev/null 2>&1 &
  log "Model pull started in background (see /var/log/ollama-model-pull.log)"
}

install_qwen_code_if_enabled() {
  if [[ "${AUTO_INSTALL_QWEN_CODE:-false}" != "true" ]]; then
    return
  fi

  if command -v qwen >/dev/null 2>&1; then
    log "Qwen Code already installed"
    return
  fi

  log "Installing Qwen Code CLI"
  npm install -g @qwen-code/qwen-code >/var/log/qwen-code-install.log 2>&1 || {
    log "Qwen Code install failed (see /var/log/qwen-code-install.log)"
    return 1
  }
}

start_sshd() {
  log "Starting SSH daemon"
  /usr/sbin/sshd -D -e &
  SSHD_PID=$!
}

cleanup() {
  set +e
  [[ -n "${SSHD_PID:-}" ]] && kill "$SSHD_PID" >/dev/null 2>&1
  [[ -n "${OLLAMA_PID:-}" ]] && kill "$OLLAMA_PID" >/dev/null 2>&1
}

main() {
  ensure_user
  configure_ssh
  setup_shell_profile
  start_ollama
  pull_model_if_enabled
  install_qwen_code_if_enabled
  start_sshd

  trap cleanup EXIT INT TERM
  wait -n "$SSHD_PID" "$OLLAMA_PID"
}

main "$@"
