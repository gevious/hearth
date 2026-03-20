#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: ./script/bootstrap.sh [options]

Builds and starts the local agent container, then prints SSH/login details.

Options:
  --container-name <name>  Container name (default: agentarium-local)
  --ssh-port <port>        Host SSH port (default: 2222)
  --ollama-port <port>     Host Ollama port (default: 11434)
  --model <name>           Ollama model to pre-pull (default: qwen3-coder:30b)
  --password <value>       SSH password for user codex (default: codex)
  --no-build               Skip image build.
  --no-model-pull          Skip auto model pull on startup.
  --install-qwen-code      Install qwen-code CLI on container startup.
  -h, --help               Show this help text.
USAGE
}

CONTAINER_NAME="agentarium-local"
SSH_PORT="2222"
OLLAMA_PORT="11434"
LOCAL_MODEL="qwen3-coder:30b"
SSH_PASSWORD="codex"
DO_BUILD=true
AUTO_PULL_MODEL=true
AUTO_INSTALL_QWEN_CODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --container-name)
      CONTAINER_NAME="$2"; shift 2 ;;
    --ssh-port)
      SSH_PORT="$2"; shift 2 ;;
    --ollama-port)
      OLLAMA_PORT="$2"; shift 2 ;;
    --model)
      LOCAL_MODEL="$2"; shift 2 ;;
    --password)
      SSH_PASSWORD="$2"; shift 2 ;;
    --no-build)
      DO_BUILD=false; shift ;;
    --no-model-pull)
      AUTO_PULL_MODEL=false; shift ;;
    --install-qwen-code)
      AUTO_INSTALL_QWEN_CODE=true; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1 ;;
  esac
done

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Required command missing: $1" >&2; exit 1; }
}

require_cmd docker

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "Docker Compose is required (docker compose or docker-compose)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

mkdir -p workspace data/ollama data/home-codex

COMMON_ENV=(
  CONTAINER_NAME="$CONTAINER_NAME"
  SSH_PORT="$SSH_PORT"
  OLLAMA_PORT="$OLLAMA_PORT"
  LOCAL_MODEL="$LOCAL_MODEL"
  SSH_PASSWORD="$SSH_PASSWORD"
  AUTO_PULL_MODEL="$AUTO_PULL_MODEL"
  AUTO_INSTALL_QWEN_CODE="$AUTO_INSTALL_QWEN_CODE"
)

if [[ "$DO_BUILD" == true ]]; then
  env "${COMMON_ENV[@]}" "${COMPOSE[@]}" up -d --build
else
  env "${COMMON_ENV[@]}" "${COMPOSE[@]}" up -d
fi

echo ""
echo "Container is starting."
echo ""
echo "SSH:" 
echo "  ssh codex@localhost -p ${SSH_PORT}"
echo "  password: ${SSH_PASSWORD}"
echo ""
echo "Ollama endpoint:" 
echo "  http://localhost:${OLLAMA_PORT}"
echo ""
echo "Check logs:" 
echo "  ${COMPOSE[*]} logs -f"
