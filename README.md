# agentarium-local

Local, self-hosted coding-agent container with:
- SSH access (`codex` user)
- Ollama local model server
- Node-based `agentarium` orchestrator CLI (`planner/coder/reviewer/tester` delegation)

## Requirements

- Docker
- Docker Compose (`docker compose` plugin or `docker-compose`)

## Quick Start

From this directory:

```bash
./script/bootstrap.sh
```

Then connect:

```bash
./script/ssh.sh
# or: ssh codex@localhost -p 2222
```

Default SSH password: `codex` (override via `--password`).

## Bootstrap Options

```bash
./script/bootstrap.sh --help
```

Common examples:

```bash
# Pull a smaller model on startup
./script/bootstrap.sh --model qwen3-coder:14b

# Use a custom SSH port and password
./script/bootstrap.sh --ssh-port 2233 --password 'change-me'

# Skip model pull during first boot
./script/bootstrap.sh --no-model-pull

# Install qwen-code CLI inside container during startup
./script/bootstrap.sh --install-qwen-code
```

## Local Endpoints

- Ollama API: `http://localhost:11434` (default)
- SSH: `localhost:2222` (default)

## Inside the Container

### Check health

```bash
agentarium health
```

### Run delegated planning/execution

```bash
agentarium plan "Add CI and test jobs"
agentarium run "Refactor auth middleware with tests"
```

### Direct worker call

```bash
agentarium worker reviewer "Review this design for hidden risks"
```

## Notes

- Model pull runs in the background on startup when enabled.
- Persistent volumes:
  - `./data/ollama` for model weights
  - `./data/home-codex` for container user home
  - `./workspace` as your working directory inside container
- GPU support can be enabled in `compose.yaml` (`gpus: all`) if your host has NVIDIA Container Toolkit configured.
