#!/usr/bin/env bash
set -uo pipefail

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

LOG_FILE="/var/log/bootstrap-weekly-updates.log"
LOCK_FILE="/run/lock/bootstrap-weekly-updates.lock"

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

if [ ! -e "${LOG_FILE}" ]; then
  install -m 0640 /dev/null "${LOG_FILE}"
fi

exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  printf '[%s] status=SKIPPED reason=already-running\n' \
    "$(date --iso-8601=seconds)" >>"${LOG_FILE}"
  exit 0
fi

STARTED_AT="$(date --iso-8601=seconds)"
STARTED_SECONDS="$(date +%s)"
STATUS="SUCCESS"
FAILED_STEP="none"
UPDATE_RESULT="not-run"
UPGRADE_RESULT="not-run"
PACKAGE_COUNT=0
PACKAGE_LIST="none"

write_summary() {
  local exit_code="$1"
  local finished_at finished_seconds duration reboot_required

  trap - EXIT

  finished_at="$(date --iso-8601=seconds)"
  finished_seconds="$(date +%s)"
  duration=$((finished_seconds - STARTED_SECONDS))
  reboot_required="no"
  if [ -f /var/run/reboot-required ]; then
    reboot_required="yes"
  fi

  if [ "${exit_code}" -ne 0 ]; then
    STATUS="FAILED"
  fi

  {
    printf '[%s] status=%s exit_code=%s duration_seconds=%s\n' \
      "${finished_at}" "${STATUS}" "${exit_code}" "${duration}"
    printf '  started_at=%s apt_update=%s package_upgrade=%s failed_step=%s\n' \
      "${STARTED_AT}" "${UPDATE_RESULT}" "${UPGRADE_RESULT}" "${FAILED_STEP}"
    printf '  planned_package_count=%s reboot_required=%s planned_packages=%s\n' \
      "${PACKAGE_COUNT}" "${reboot_required}" "${PACKAGE_LIST}"
  } >>"${LOG_FILE}"

  exit "${exit_code}"
}

trap 'write_summary $?' EXIT

echo "==> Refreshing APT package indexes"
if apt-get update; then
  UPDATE_RESULT="ok"
else
  exit_code=$?
  UPDATE_RESULT="failed"
  FAILED_STEP="apt-get-update"
  exit "${exit_code}"
fi

if ! PACKAGE_LIST="$(apt-get --simulate upgrade --with-new-pkgs \
  | awk '/^Inst / { print $2 }' \
  | sort -u \
  | paste -sd, -)"; then
  FAILED_STEP="calculate-upgrades"
  exit 1
fi

if [ -n "${PACKAGE_LIST}" ]; then
  PACKAGE_COUNT="$(awk -F, '{ print NF }' <<<"${PACKAGE_LIST}")"
else
  PACKAGE_LIST="none"
fi

echo "==> Installing ${PACKAGE_COUNT} available package update(s)"
if apt-get -o Dpkg::Options::="--force-confold" upgrade --with-new-pkgs -y; then
  UPGRADE_RESULT="ok"
else
  exit_code=$?
  UPGRADE_RESULT="failed"
  FAILED_STEP="apt-get-upgrade"
  exit "${exit_code}"
fi
