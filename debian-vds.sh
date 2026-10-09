#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# Debian bootstrap script
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
P10K_PATH="${TARGET_HOME}/.p10k.zsh"
NVIM_CONFIG_DIR="${TARGET_HOME}/.config/nvim"
NVIM_INIT_PATH="${NVIM_CONFIG_DIR}/init.lua"
NVIM_TEMPLATE_PATH="${SCRIPT_DIR}/init.lua"
ZSHRC_TEMPLATE_PATH="${SCRIPT_DIR}/.zshrc"
P10K_TEMPLATE_PATH="${SCRIPT_DIR}/.p10k.zsh"
WEEKLY_UPDATES_TEMPLATE_PATH="${SCRIPT_DIR}/weekly-updates.sh"

for template in \
  "${NVIM_TEMPLATE_PATH}" \
  "${ZSHRC_TEMPLATE_PATH}" \
  "${P10K_TEMPLATE_PATH}" \
  "${WEEKLY_UPDATES_TEMPLATE_PATH}"; do
  if [ ! -f "${template}" ]; then
    echo "Configuration template not found: ${template}" >&2
    exit 1
  fi
done

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

echo "iperf3 iperf3/start_daemon boolean false" | ${SUDO} debconf-set-selections

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
  git \
  cron

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
# 4. Configure Neovim
# -----------------------------------------------------------------------------
echo "==> Configuring Neovim"

${SUDO} mkdir -p "${NVIM_CONFIG_DIR}"

${SUDO} install -m 0644 "${NVIM_TEMPLATE_PATH}" "${NVIM_INIT_PATH}"

${SUDO} chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.config"

# -----------------------------------------------------------------------------
# 5. Install eza
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
# 6. Install Docker
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
# 7. Install fzf (GitHub)
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
# 8. Install powerlevel10k
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
# 9. Install Zsh configuration
# -----------------------------------------------------------------------------
echo "==> Installing Zsh configuration"

if [ -f "${ZSHRC_PATH}" ]; then
  ${SUDO} cp -a "${ZSHRC_PATH}" "${ZSHRC_PATH}.bak"
fi

if [ -f "${P10K_PATH}" ]; then
  ${SUDO} cp -a "${P10K_PATH}" "${P10K_PATH}.bak"
fi

TARGET_GROUP="$(id -gn "${TARGET_USER}")"
${SUDO} install -o "${TARGET_USER}" -g "${TARGET_GROUP}" -m 0644 \
  "${ZSHRC_TEMPLATE_PATH}" "${ZSHRC_PATH}"
${SUDO} install -o "${TARGET_USER}" -g "${TARGET_GROUP}" -m 0644 \
  "${P10K_TEMPLATE_PATH}" "${P10K_PATH}"

# -----------------------------------------------------------------------------
# 10. Set default shell
# -----------------------------------------------------------------------------
if command -v zsh >/dev/null 2>&1; then
  ${SUDO} chsh -s "$(command -v zsh)" "${TARGET_USER}" || true
fi

# -----------------------------------------------------------------------------
# 11. Schedule weekly system updates
# -----------------------------------------------------------------------------
echo "==> Scheduling weekly system updates"

${SUDO} install -m 0750 \
  "${WEEKLY_UPDATES_TEMPLATE_PATH}" /usr/local/sbin/bootstrap-weekly-updates
${SUDO} touch /var/log/bootstrap-weekly-updates.log
${SUDO} chmod 0640 /var/log/bootstrap-weekly-updates.log

printf '%s\n' \
  'SHELL=/bin/bash' \
  'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' \
  '0 5 * * 3 root /usr/local/sbin/bootstrap-weekly-updates' \
  | ${SUDO} tee /etc/cron.d/bootstrap-weekly-updates >/dev/null
${SUDO} chmod 0644 /etc/cron.d/bootstrap-weekly-updates

${SUDO} systemctl enable --now cron

echo
echo "Bootstrap completed."
echo "Re-login required."
