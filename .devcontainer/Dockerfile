# Synergy raw-data container — the Esper ingestion sandbox.
#
# Ported from clean_room/Containerfile (Apple Container) to the devcontainer
# spec so it can be launched from macOS, Linux, VS Code, or another container.
#
# Nothing host-specific is baked in: no HOST_UID/HOST_GID build args (the
# devcontainer runtime handles UID mapping), no copied .gitconfig.
#
# The build context is .devcontainer/ — NOT the repo root — so no repo content
# can end up inside the image.

FROM mcr.microsoft.com/devcontainers/base:debian

ARG DEBIAN_FRONTEND=noninteractive
ARG NODE_VERSION=24
ARG USERNAME=vscode

# --- Packages --------------------------------------------------------------
# dnsmasq / ipset / iptables : the egress allowlist (init-firewall.sh)
# iproute2 / iputils-ping    : firewall debugging
# jq / ripgrep / fd-find     : search + JSON tooling used during ingestion
# locales                    : source titles are full of non-ASCII
# The base image already provides git, zsh, sudo, curl, wget, and ca-certificates.
RUN apt-get update && apt-get install -y --no-install-recommends \
        dnsmasq \
        fd-find \
        iproute2 \
        ipset \
        iptables \
        iputils-ping \
        jq \
        locales \
        python3 \
        ripgrep \
        vim \
    && rm -rf /var/lib/apt/lists/*

# --- Locale ----------------------------------------------------------------
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# --- Node.js ---------------------------------------------------------------
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# --- Firewall --------------------------------------------------------------
# Root-owned, root-writable-only, in a root-owned directory: the agent running
# inside this container cannot rewrite the script it is allowed to sudo.
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chown root:root /usr/local/bin /usr/local/bin/init-firewall.sh \
    && chmod 0755 /usr/local/bin /usr/local/bin/init-firewall.sh

# --- sudo ------------------------------------------------------------------
# The base image ships `vscode ALL=(root) NOPASSWD:ALL`, which would let anything
# running in here tear the firewall down (`sudo iptables -F`). Replace it with a
# single entry: the firewall script and nothing else. The script is idempotent
# and fails closed, so re-running it can only restore the intended state.
RUN rm -f /etc/sudoers.d/${USERNAME} /etc/sudoers.d/vscode /etc/sudoers.d/node \
    && echo "${USERNAME} ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" \
        > /etc/sudoers.d/010-init-firewall \
    && chmod 0440 /etc/sudoers.d/010-init-firewall \
    && visudo -c > /dev/null

# --- Mount points ----------------------------------------------------------
# /workspaces/Synergy           : project root (container layer, ephemeral)
# /workspaces/Synergy/esper     : bind-mounted read-write from the host repo
# /workspaces/Synergy/.claude/commands : bind-mounted read-only from the host repo
# /sources                      : read-only source mounts (see devcontainer.json)
# There is deliberately no /workspaces/Synergy/memory. See ../docs/ and README.md.
# /workspaces/Synergy/CLAUDE.md is created empty so the single-file bind mount
# always has a target; some runtimes refuse to create one.
#
# Ownership: root, mode 0755 — readable and traversable by ${USERNAME}, writable
# by nobody. esper/ is a bind mount and carries the host's ownership, so it stays
# writable; everything else under the project root does not.
#
# This is what stops the agent from granting itself permissions. Only
# .claude/commands is a read-only mount — the .claude directory ITSELF is
# container layer, so a user-writable one would let an injection drop a
# .claude/settings.local.json (or a .claude/skills/) and hand itself the tools
# the settings deny list is meant to withhold.
RUN mkdir -p /workspaces/Synergy/esper /workspaces/Synergy/.claude/commands /sources \
    && touch /workspaces/Synergy/CLAUDE.md \
    && chown -R root:root /workspaces \
    && chmod -R 0755 /workspaces \
    && chmod 0755 /sources

# --- Isolated Claude + npm state -------------------------------------------
# CLAUDE_CONFIG_DIR is never the host's ~/.claude: no host credentials, skills,
# hooks, agents, MCP servers, or transcripts are reachable from inside.
# Both directories are backed by named volumes at runtime; Docker seeds a fresh
# named volume from the image, so claude-config/settings.json below becomes the
# initial user-level settings file and then persists across rebuilds.
ENV CLAUDE_CONFIG_DIR=/home/${USERNAME}/.claude-raw
ENV NPM_CONFIG_PREFIX=/home/${USERNAME}/.npm-global
ENV NPM_CONFIG_CACHE=/home/${USERNAME}/.npm
ENV PATH=/home/${USERNAME}/.npm-global/bin:${PATH}

RUN mkdir -p /home/${USERNAME}/.claude-raw \
             /home/${USERNAME}/.npm-global \
             /home/${USERNAME}/.npm \
    && chown -R ${USERNAME}:${USERNAME} \
        /home/${USERNAME}/.claude-raw \
        /home/${USERNAME}/.npm-global \
        /home/${USERNAME}/.npm

COPY --chown=${USERNAME}:${USERNAME} claude-config/settings.json /home/${USERNAME}/.claude-raw/settings.json

# --- Claude Code -----------------------------------------------------------
# Installed as the unprivileged user into a user-owned npm prefix, so
# `claude update` / `npm i -g @anthropic-ai/claude-code@latest` work without root.
USER ${USERNAME}
RUN npm install -g @anthropic-ai/claude-code \
    && npm cache clean --force

# esper/.git is shadowed by a read-only tmpfs at runtime (see devcontainer.json),
# so git cannot operate on esper/ in here at all. That is intentional: the host
# owns git for esper/, and a writable .git is a path back out to the host.
# No safe.directory entry is needed or wanted.

USER root
# Matches workspaceFolder in devcontainer.json, so a bare `docker exec` lands in
# the same place the devcontainer CLI does.
WORKDIR /workspaces/Synergy
