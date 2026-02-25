#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Debian 12 bootstrap script
# -----------------------------------------------------------------------------

if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
  TARGET_USER="${SUDO_USER:-root}"
else
  SUDO="sudo"
  TARGET_USER="${USER}"
fi

if [ -z "${TARGET_USER}" ]; then
  echo "Cannot determine target user" >&2
  exit 1
fi

TARGET_HOME="$(eval echo "~${TARGET_USER}")"
ZSHRC_PATH="${TARGET_HOME}/.zshrc"

echo "Target user: ${TARGET_USER}"
echo "Home:        ${TARGET_HOME}"
echo

# -----------------------------------------------------------------------------
# 1. FULL SYSTEM UPDATE
# -----------------------------------------------------------------------------
echo "==> Full system upgrade"
${SUDO} apt-get update -y
${SUDO} apt-get full-upgrade -y
${SUDO} apt-get autoremove -y

# -----------------------------------------------------------------------------
# 1.1 Configure sudo timeout (60 minutes)
# -----------------------------------------------------------------------------
echo "==> Setting sudo timestamp_timeout=60"

echo 'Defaults timestamp_timeout=60' | ${SUDO} tee /etc/sudoers.d/timeout >/dev/null
${SUDO} chmod 0440 /etc/sudoers.d/timeout

# -----------------------------------------------------------------------------
# Remove repo neovim & fzf if installed
# -----------------------------------------------------------------------------
${SUDO} apt-get remove -y neovim neovim-runtime fzf 2>/dev/null || true

# -----------------------------------------------------------------------------
# 2. Install base packages
# -----------------------------------------------------------------------------
echo "==> Installing base packages"

${SUDO} apt-get install -y \
  zsh \
  zsh-autosuggestions \
  zsh-syntax-highlighting \
  btop \
  zoxide \
  iperf3 \
  wget \
  curl \
  ca-certificates \
  gnupg \
  lsb-release \
  tar \
  git

# -----------------------------------------------------------------------------
# 3. Install Neovim (GitHub latest)
# -----------------------------------------------------------------------------
echo "==> Installing Neovim (latest release from GitHub)"

NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
TMP_DIR="$(mktemp -d)"

curl -L "${NVIM_URL}" -o "${TMP_DIR}/nvim.tar.gz"

${SUDO} rm -rf /opt/nvim
${SUDO} mkdir -p /opt

${SUDO} tar -C /opt -xzf "${TMP_DIR}/nvim.tar.gz"
${SUDO} mv /opt/nvim-linux-x86_64 /opt/nvim
${SUDO} ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim

rm -rf "${TMP_DIR}"

# -----------------------------------------------------------------------------
# 4. Install eza
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
# 5. Install Docker
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
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

if getent group docker >/dev/null 2>&1; then
  ${SUDO} usermod -aG docker "${TARGET_USER}" || true
fi

# -----------------------------------------------------------------------------
# 6. Install fzf (GitHub)
# -----------------------------------------------------------------------------
echo "==> Installing fzf"

install_fzf_for_user() {
  if [ ! -d "$HOME/.fzf" ]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  else
    cd "$HOME/.fzf" && git pull --ff-only || true
  fi
  "$HOME/.fzf/install" --key-bindings --completion --no-bash --no-fish --no-update-rc
}

if [ "$(id -u)" -eq 0 ]; then
  su - "${TARGET_USER}" -c "$(declare -f install_fzf_for_user); install_fzf_for_user"
else
  install_fzf_for_user
fi

# -----------------------------------------------------------------------------
# 7. Install powerlevel10k
# -----------------------------------------------------------------------------
echo "==> Installing powerlevel10k"

install_p10k_for_user() {
  if [ ! -d "$HOME/.powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.powerlevel10k"
  else
    cd "$HOME/.powerlevel10k" && git pull --ff-only || true
  fi
}

if [ "$(id -u)" -eq 0 ]; then
  su - "${TARGET_USER}" -c "$(declare -f install_p10k_for_user); install_p10k_for_user"
else
  install_p10k_for_user
fi

# -----------------------------------------------------------------------------
# 8. Configure .zshrc
# -----------------------------------------------------------------------------
echo "==> Configuring .zshrc"

if [ -f "${ZSHRC_PATH}" ]; then
  ${SUDO} cp -a "${ZSHRC_PATH}" "${ZSHRC_PATH}.bak"
fi

${SUDO} tee "${ZSHRC_PATH}" >/dev/null <<'EOF'
if [ -d "$HOME/.powerlevel10k" ]; then
  source "$HOME/.powerlevel10k/powerlevel10k.zsh-theme"
fi
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export EDITOR="nvim"
export VISUAL="nvim"

alias ls="eza --tree -L 1 --icons=always"
alias la="eza --icons=always -la"
alias ldt="eza --icons=always --tree -L 3 --only-dirs"
alias rmd="rm -ri"

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
  alias cd="z"
fi

if [ -f "$HOME/.fzf.zsh" ]; then
  source "$HOME/.fzf.zsh"
fi

if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

autoload -Uz compinit
compinit
setopt AUTO_MENU
zstyle ':completion:*' menu select
EOF

${SUDO} chown "${TARGET_USER}:${TARGET_USER}" "${ZSHRC_PATH}"

# -----------------------------------------------------------------------------
# 9. Set default shell
# -----------------------------------------------------------------------------
if command -v zsh >/dev/null 2>&1; then
  ${SUDO} chsh -s "$(command -v zsh)" "${TARGET_USER}" || true
fi

echo
echo "Bootstrap completed."
echo "Re-login required."