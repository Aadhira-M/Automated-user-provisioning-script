#!/usr/bin/env bash
# =============================================================
# provision_users.sh — Bulk user provisioning from a CSV file
# Usage: sudo ./provision_users.sh users.csv
# =============================================================

set -euo pipefail

CSV_FILE="${1:-}"
LOG_FILE="/var/log/user_provisioning.log"
DEFAULT_SHELL="/bin/bash"

# ── Preflight checks ─────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "Error: run this script as root or with sudo." >&2
  exit 1
fi

if [[ -z "$CSV_FILE" || ! -f "$CSV_FILE" ]]; then
  echo "Usage: sudo $0 <path-to-csv>" >&2
  exit 1
fi

# ── Logging helper ───────────────────────────────────────────
log() {
  local level="$1"; shift
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $*" | tee -a "$LOG_FILE"
}

log "INFO" "=== Provisioning run started. Source: $CSV_FILE ==="

# ── Main loop ────────────────────────────────────────────────
line_num=0

while IFS=',' read -r username group shell ssh_key; do
  line_num=$((line_num + 1))

  # Skip header row
  [[ $line_num -eq 1 ]] && continue

  # Strip whitespace
  username="${username// /}"
  group="${group// /}"
  shell="${shell// /}"
  ssh_key="${ssh_key%$'\r'}"   # strip Windows CR if present

  # ── Validation ─────────────────────────────────────────────
  if [[ -z "$username" || -z "$group" ]]; then
    log "WARN" "Line $line_num: missing username or group — skipping."
    continue
  fi

  if ! [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    log "WARN" "Line $line_num: invalid username format '$username' — skipping."
    continue
  fi

  # Default shell if blank or invalid
  if [[ -z "$shell" || ! -x "$shell" ]]; then
    log "INFO" "Line $line_num: shell '$shell' not found, using $DEFAULT_SHELL."
    shell="$DEFAULT_SHELL"
  fi

  # ── Skip if user already exists ────────────────────────────
  if id "$username" &>/dev/null; then
    log "SKIP" "User '$username' already exists — skipping."
    continue
  fi

  # ── Create group if it doesn't exist ───────────────────────
  if ! getent group "$group" &>/dev/null; then
    groupadd "$group"
    log "INFO" "Created group '$group'."
  fi

  # ── Create user ────────────────────────────────────────────
  useradd \
    --create-home \
    --shell "$shell" \
    --gid "$group" \
    "$username"

  log "INFO" "Created user '$username' (group=$group, shell=$shell)."

  # ── SSH key injection ──────────────────────────────────────
  if [[ -n "$ssh_key" ]]; then
    SSH_DIR="/home/$username/.ssh"
    AUTH_KEYS="$SSH_DIR/authorized_keys"

    mkdir -p "$SSH_DIR"
    echo "$ssh_key" > "$AUTH_KEYS"
    chmod 700 "$SSH_DIR"
    chmod 600 "$AUTH_KEYS"
    chown -R "$username:$group" "$SSH_DIR"

    log "INFO" "SSH key added for '$username'."
  else
    log "WARN" "No SSH key provided for '$username' — password auth only."
  fi

done < "$CSV_FILE"

log "INFO" "=== Provisioning run complete. ==="
