FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    openssh-server \
    ripgrep \
    sudo \
    tmux \
    tini \
    unzip \
    zstd \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN case "${TARGETARCH}" in \
      amd64) OLLAMA_URL="https://ollama.com/download/ollama-linux-amd64.tar.zst" ;; \
      arm64) OLLAMA_URL="https://ollama.com/download/ollama-linux-arm64.tar.zst" ;; \
      *) echo "Unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "${OLLAMA_URL}" | tar --zstd -x -C /usr

RUN useradd -m -s /bin/bash codex \
    && echo 'codex ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/codex \
    && chmod 0440 /etc/sudoers.d/codex \
    && mkdir -p /var/run/sshd /workspace /opt/agentarium

WORKDIR /opt/agentarium

COPY orchestrator/ /opt/agentarium/orchestrator/
COPY container/startup.sh /usr/local/bin/startup.sh

RUN chmod +x /usr/local/bin/startup.sh \
    && chmod +x /opt/agentarium/orchestrator/main.mjs \
    && printf '#!/usr/bin/env bash\nset -euo pipefail\nexec node /opt/agentarium/orchestrator/main.mjs "$@"\n' > /usr/local/bin/agentarium \
    && chmod +x /usr/local/bin/agentarium

ENV OPENAI_BASE_URL="http://127.0.0.1:11434/v1"
ENV OPENAI_API_KEY="ollama"
ENV LOCAL_MODEL="qwen3-coder:30b"
ENV AUTO_PULL_MODEL="true"
ENV AUTO_INSTALL_QWEN_CODE="false"

EXPOSE 22 11434

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/startup.sh"]
