#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Debian 12 bootstrap script
# Installs:
#   zsh, zsh-autosuggestions, zsh-syntax-highlighting
#   eza, zoxide, neovim, btop
#   fzf, iperf3, wget
#   Docker (official repo)
# Configures:
#   ~/.zshrc with aliases, zoxide, fzf, completion menu
# -----------------------------------------------------------------------------

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
  TARGET_USER="${SUDO_USER:-root}"
else
  SUDO="sudo"
  TARGET_USER="${USER}"
fi

TARGET_HOME="$(eval echo ~"${TARGET_USER}")"
ZSHRC_PATH="${TARGET_HOME}/.zshrc"

echo "Target user: ${TARGET_USER}"
echo "Home:        ${TARGET_HOME}"
echo

# -----------------------------------------------------------------------------
# 1. FULL SYSTEM UPDATE (FIRST STEP)
# -----------------------------------------------------------------------------
echo "==> Full system upgrade"
${SUDO} apt-get update -y
${SUDO} apt-get full-upgrade -y
${SUDO} apt-get autoremove -y

# -----------------------------------------------------------------------------
# 2. Install base packages from Debian repo
# -----------------------------------------------------------------------------
echo "==> Installing base packages"

${SUDO} apt-get install -y \
  zsh \
  zsh-autosuggestions \
  zsh-syntax-highlighting \
  neovim \
  btop \
  zoxide \
  fzf \
  iperf3 \
  wget \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

# -----------------------------------------------------------------------------
# 3. Install eza (official repo)
# -----------------------------------------------------------------------------
echo "==> Installing eza"

${SUDO} mkdir -p /etc/apt/keyrings

if [ ! -f /etc/apt/keyrings/gierens.gpg ]; then
  curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
    | ${SUDO} gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
  ${SUDO} chmod 644 /etc/apt/keyrings/gierens.gpg
fi

if [ ! -f /etc/apt/sources.list.d/gierens.list ]; then
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    | ${SUDO} tee /etc/apt/sources.list.d/gierens.list >/dev/null
fi

${SUDO} apt-get update -y
${SUDO} apt-get install -y eza

# -----------------------------------------------------------------------------
# 4. Install Docker (official repository)
# -----------------------------------------------------------------------------
echo "==> Installing Docker"

${SUDO} apt-get remove -y docker.io docker-doc podman-docker containerd runc 2>/dev/null || true

${SUDO} install -m 0755 -d /etc/apt/keyrings

if [ ! -f /etc/apt/keyrings/docker.asc ]; then
  ${SUDO} curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  ${SUDO} chmod a+r /etc/apt/keyrings/docker.asc
fi

if [ ! -f /etc/apt/sources.list.d/docker.sources ]; then
  ${SUDO} tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
fi

${SUDO} apt-get update -y

${SUDO} apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

if getent group docker >/dev/null 2>&1; then
  ${SUDO} usermod -aG docker "${TARGET_USER}" || true
fi

# -----------------------------------------------------------------------------
# 5. Configure ~/.zshrc
# -----------------------------------------------------------------------------
echo "==> Configuring .zshrc"

if [ -f "${ZSHRC_PATH}" ]; then
  ${SUDO} cp -a "${ZSHRC_PATH}" "${ZSHRC_PATH}.bak"
fi

${SUDO} tee "${ZSHRC_PATH}" >/dev/null <<'EOF'
# Preferred editor
export EDITOR="nvim"
export VISUAL="nvim"

# ---------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------
alias ls="eza --tree -L 1 --icons=always"
alias la="eza --icons=always -la"
alias ldt="eza --icons=always --tree -L 3 --only-dirs"
alias rmd="rm -ri"

# ---------------------------------------------------------------------
# Zoxide (better cd)
# ---------------------------------------------------------------------
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
  alias cd="z"
fi

# ---------------------------------------------------------------------
# fzf key bindings and fuzzy completion
# ---------------------------------------------------------------------
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

# ---------------------------------------------------------------------
# zsh plugins
# ---------------------------------------------------------------------
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# ---------------------------------------------------------------------
# TAB completion menu
# ---------------------------------------------------------------------
autoload -Uz compinit
compinit
setopt AUTO_MENU
zstyle ':completion:*' menu select
EOF

${SUDO} chown "${TARGET_USER}:${TARGET_USER}" "${ZSHRC_PATH}"

# -----------------------------------------------------------------------------
# 6. Set default shell to zsh
# -----------------------------------------------------------------------------
if command -v zsh >/dev/null 2>&1; then
  ${SUDO} chsh -s "$(command -v zsh)" "${TARGET_USER}" || true
fi

echo
echo "Bootstrap completed."
echo "Re-login required for zsh and docker group to apply."